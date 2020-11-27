locals {
  stage            = var.stage != "" ? var.stage : terraform.workspace
  data_center      = "${var.provider_name}-${var.zone}"
  host_suffix      = "${local.data_center}.${var.env}.${local.stage}"
  host_full_suffix = "${local.host_suffix}.${var.domain}"
  /* got to add some default groups */
  groups = distinct([local.data_center, "${var.env}.${local.stage}", var.group])
  /* always add SSH, Tinc, Netdata, and Consul to allowed ports */
  open_tcp_ports  = concat(["22", "655", "8000", "8301"], var.open_tcp_ports)
  open_udp_ports  = concat(["655", "8301"], var.open_udp_ports)
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
  }
  
  /* always enable SSH */
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
      protocol  = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
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
      protocol  = "udp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

resource "aws_instance" "host" {
  instance_type     = var.instance_type
  availability_zone = var.zone
  count             = var.host_count
  ami               = data.aws_ami.ubuntu.id
  key_name          = var.keypair_name
  subnet_id         = var.subnet_id

  /* Add provided Security Group if available */
  vpc_security_group_ids = concat(
    [ aws_security_group.host.id ],
    (var.secgroup_id != "" ? [var.secgroup_id] : [])
  )

  root_block_device {
    volume_size = var.root_vol_size
  }

  tags = {
    Name  = "${var.name}-${format("%02d", count.index+1)}.${local.host_suffix}"
    Fqdn  = "${var.name}-${format("%02d", count.index+1)}.${local.host_full_suffix}"
    Fleet = "${var.env}.${local.stage}"
  }
  
  /* for snapshots through lifecycle policy */
  volume_tags = {
    Fleet = "${var.env}.${local.stage}"
    Name = "${var.name}-${format("%02d", count.index+1)}.${local.host_suffix}"
  }

  /* Ignore changes to disk image */
  lifecycle {
    ignore_changes = [ ami ]
  }
}

resource "aws_ebs_volume" "host" {
  availability_zone = var.zone

  size = var.data_vol_size
  type = var.data_vol_type

  count = (var.data_vol_size == 0 ? 0 : var.host_count)
}

resource "aws_volume_attachment" "host" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.host[count.index].id
  instance_id = aws_instance.host[count.index].id

  count = (var.data_vol_size == 0 ? 0 : var.host_count)
}

resource "aws_eip" "host" {
  instance = aws_instance.host[count.index].id
  count    = var.host_count

  tags = {
    Name = "${var.name}-${format("%02d", count.index+1)}.${local.host_suffix}"
  }

  /* Data volume needs to be available for bootstrapping */
  depends_on = [ aws_volume_attachment.host ]
}

/* Run Ansible here here to make use of the Elastic IP attached to the host. */
resource "null_resource" "host" {
  count = var.host_count

  /* Trigger bootstrapping on host or public IP change. */
  triggers = {
    instance_id = aws_instance.host[count.index].id
    eip_id = aws_eip.host[count.index].id
  }

  /* Make sure everything is in place before bootstrapping. */
  depends_on = [
    aws_instance.host[count.index]
    aws_ebs_volume.host[count.index]
    aws_volume_attachment.host[count.index]
    aws_eip.host[count.index]
  ]

  provisioner "ansible" {
    plays {
      playbook {
        file_path = "${path.cwd}/ansible/bootstrap.yml"
      }

      hosts  = [ aws_eip.host[count.index].public_ip ]
      groups = local.groups

      extra_vars = {
        hostname         = aws_instance.host[count.index].tags.Name
        ansible_ssh_user = var.ssh_user
        data_center      = local.data_center
        stage            = local.stage
        env              = var.env
      }
    }
  }
}

resource "cloudflare_record" "host" {
  zone_id = var.cf_zone_id
  count   = var.host_count
  name    = aws_instance.host[count.index].tags.Name
  value   = aws_eip.host[count.index].public_ip
  type    = "A"
  ttl     = 300
}

/* this adds the host to the Terraform state for Ansible inventory */
resource "ansible_host" "host" {
  inventory_hostname = aws_instance.host[count.index].tags.Name

  groups = local.groups
  count  = length(aws_instance.host)

  vars = {
    ansible_host = aws_eip.host[count.index].public_ip
    hostname     = aws_instance.host[count.index].tags.Name
    region       = aws_instance.host[count.index].availability_zone
    dns_entry    = aws_instance.host[count.index].tags.Fqdn
    data_center  = local.data_center
    dns_domain   = var.domain
    env          = var.env
    stage        = local.stage
  }
}
