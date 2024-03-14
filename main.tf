locals {
  stage = var.stage != "" ? var.stage : terraform.workspace
  dc    = "${var.provider_name}-${var.zone}"
  /* Got to add some default groups. */
  groups = distinct([local.dc, "${var.env}.${local.stage}", var.group])
  /* always add SSH, WireGuard, and Consul to allowed ports */
  open_tcp_ports = concat(["22", "8301"], var.open_tcp_ports)
  open_udp_ports = concat(["51820", "8301"], var.open_udp_ports)
  /* pre-generated list of hostnames */
  hostnames = [for i in range(1, var.host_count + 1) :
    "${var.name}-${format("%02d", i)}.${local.dc}.${var.env}.${local.stage}"
  ]
}

/* the image needs to be queried */
data "aws_ami" "ubuntu" {
  owners = [var.image_owner]

  filter {
    name   = "name"
    values = [var.image_name]
  }
}

resource "aws_security_group" "host" {
  name        = "${var.name}-${var.zone}-${var.env}-${local.stage}"
  description = "Allow SSH and other ports. (Terraform)"

  /* needs to exist in VPC of the instance */
  vpc_id = var.vpc_id

  /* unrestricted outging traffic */
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  /* always enable SSH */
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  /* TCP */
  dynamic "ingress" {
    iterator = port
    for_each = local.open_tcp_ports
    content {
      /* Hacky way to handle ranges as strings */
      from_port = tonumber(
        length(split("-", port.value)) > 1 ? split("-", port.value)[0] : port.value
      )
      to_port = tonumber(
        length(split("-", port.value)) > 1 ? split("-", port.value)[1] : port.value
      )
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  /* UDP */
  dynamic "ingress" {
    iterator = port
    for_each = local.open_udp_ports
    content {
      /* Hacky way to handle ranges as strings */
      from_port = tonumber(
        length(split("-", port.value)) > 1 ? split("-", port.value)[0] : port.value
      )
      to_port = tonumber(
        length(split("-", port.value)) > 1 ? split("-", port.value)[1] : port.value
      )
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }
}

resource "aws_instance" "host" {
  for_each = toset(local.hostnames)

  availability_zone = var.zone

  instance_type = var.type
  ami           = data.aws_ami.ubuntu.id
  key_name      = var.keypair_name
  subnet_id     = var.subnet_id

  /* Add provided Security Group if available */
  vpc_security_group_ids = concat(
    [aws_security_group.host.id],
    (var.secgroup_id != "" ? [var.secgroup_id] : [])
  )

  root_block_device {
    volume_size = var.root_vol_size
  }

  tags = {
    Name  = each.key
    Fqdn  = "${each.key}.${var.domain}"
    Fleet = "${var.env}.${local.stage}"
  }

  /* for snapshots through lifecycle policy */
  volume_tags = {
    Name  = each.key
    Fleet = "${var.env}.${local.stage}"
  }

  /* IPv6 support */
  ipv6_address_count = var.ipv6_address_count
  /* Instance protection and recovery. */
  disable_api_stop = var.disable_api_stop
  disable_api_termination = var.disable_api_termination
  maintenance_options {
    auto_recovery = var.auto_recovery
  }

  /* Ignore changes to disk image */
  lifecycle {
    ignore_changes = [ami, key_name]
  }
}

resource "aws_ebs_volume" "host" {
  for_each = toset([ for h in local.hostnames : h if var.data_vol_size > 0 ])

  availability_zone = var.zone

  size = var.data_vol_size
  type = var.data_vol_type
  iops = (
    var.data_vol_type == "io1" || var.data_vol_type == "io2" ?
    var.data_vol_iops : 0
  )
}

resource "aws_volume_attachment" "host" {
  for_each = { for k,v in aws_instance.host : k => v if var.data_vol_size > 0 }

  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.host[each.key].id
  instance_id = each.value.id
}

resource "aws_eip" "host" {
  for_each = aws_instance.host

  instance = each.value.id

  tags = {
    Name = each.key
  }

  /* In case we care about the elastic IP. */
  lifecycle {
    prevent_destroy = true
  }
}

/* Run Ansible here here to make use of the Elastic IP attached to the host. */
resource "null_resource" "host" {
  for_each = aws_instance.host

  /* Trigger bootstrapping on host or public IP change. */
  triggers = {
    instance_id = each.value.id
    eip_id      = aws_eip.host[each.key].id
  }

  /* Make sure everything is in place before bootstrapping. */
  depends_on = [
    aws_instance.host,
    aws_ebs_volume.host,
    aws_volume_attachment.host,
    aws_eip.host,
  ]

  provisioner "ansible" {
    plays {
      playbook {
        file_path = "${path.cwd}/ansible/bootstrap.yml"
      }

      hosts  = [aws_eip.host[each.key].public_ip]
      groups = local.groups

      extra_vars = {
        hostname     = each.value.tags.Name
        ansible_user = var.ssh_user
        data_center  = local.dc
        stage        = local.stage
        env          = var.env
      }
    }
  }
}

resource "cloudflare_record" "host" {
  for_each = aws_eip.host

  zone_id = var.cf_zone_id
  name    = each.key
  value   = each.value.public_ip
  type    = "A"
  ttl     = 300
}

/* this adds the host to the Terraform state for Ansible inventory */
resource "ansible_host" "host" {
  for_each = aws_instance.host

  inventory_hostname = each.value.tags.Name

  groups = local.groups

  vars = {
    ansible_host = aws_eip.host[each.key].public_ip
    hostname     = each.value.tags.Name
    region       = each.value.availability_zone
    dns_entry    = each.value.tags.Fqdn
    data_center  = local.dc
    dns_domain   = var.domain
    env          = var.env
    stage        = local.stage
  }
}
