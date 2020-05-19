locals {
  stage       = var.stage != "" ? var.stage : terraform.workspace
  data_center = "${var.provider_name}-${var.region}"
  /* got to add some default groups */
  groups = distinct([local.data_center, "${var.env}.${local.stage}", var.group])
  /* always add SSH, Tinc, Netdata, and Consul to allowed ports */
  open_tcp_ports  = concat(["22", "655", "8000", "8301"], var.open_tcp_ports)
  open_udp_ports  = concat(["655", "8301"], var.open_udp_ports)
  /* pre-generated list of hostnames */
  hostnames = [for i in range(1, var.host_count+1): 
    join(".", [
      "${var.name}-${format("%02d", i)}",
      "${var.provider_name}-${var.region}${element(var.zones, (i - 1) % length(var.zones))}",
      var.env,
      local.stage,
    ])
  ]
  /* pre-generated map of zones to subnets */
  subnets = {for s in var.subnets: s.availability_zone => s.id}
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
  name        = "${var.name}-${var.region}-${var.env}-${local.stage}"
  description = "Allow SSH and other ports. (Terraform)"

  /* needs to exist in VPC of the instance */
  vpc_id = var.vpc.id

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
  availability_zone = "${var.region}${var.zones[count.index % length(var.zones)]}"
  count             = var.host_count

  /* necessary for SSH access */
  associate_public_ip_address = true

  ami       = data.aws_ami.ubuntu.id
  key_name  = var.keypair_name
  subnet_id = local.subnets["${var.region}${var.zones[count.index % length(var.zones)]}"]

  /* Add provided Security Group if available */
  vpc_security_group_ids = concat(
    [ aws_security_group.host.id ],
    (var.secgroup.id != "" ? [var.secgroup.id] : [])
  )

  root_block_device {
    volume_size = var.root_vol_size
  }

  tags = {
    Name  = local.hostnames[count.index]
    Fqdn  = "${local.hostnames[count.index]}.${var.domain}"
    Fleet = "${var.env}.${local.stage}"
  }
  
  /* for snapshots through lifecycle policy */
  volume_tags = {
    Fleet = "${var.env}.${local.stage}"
    Name = local.hostnames[count.index]
  }

  /* bootstraping access for later Ansible use */
  provisioner "ansible" {
    plays {
      playbook {
        file_path = "${path.cwd}/ansible/bootstrap.yml"
      }

      hosts  = [self.public_ip]
      groups = local.groups

      extra_vars = {
        hostname         = self.tags.Name
        ansible_ssh_user = var.ssh_user
        data_center      = local.data_center
        stage            = local.stage
        env              = var.env
      }
    }
  }
}

resource "aws_ebs_volume" "host" {
  availability_zone = "${var.region}${var.zones[count.index % length(var.zones)]}"

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
resource "cloudflare_record" "host" {
  zone_id = var.cf_zone_id
  count   = var.host_count
  name    = aws_instance.host[count.index].tags.Name
  value   = aws_instance.host[count.index].public_ip
  type    = "A"
  ttl     = 300
}

/* this adds the host to the Terraform state for Ansible inventory */
resource "ansible_host" "host" {
  inventory_hostname = aws_instance.host[count.index].tags.Name

  groups = local.groups
  count  = length(aws_instance.host)

  vars = {
    ansible_host = aws_instance.host[count.index].public_ip
    hostname     = aws_instance.host[count.index].tags.Name
    region       = aws_instance.host[count.index].availability_zone
    dns_entry    = aws_instance.host[count.index].tags.Fqdn
    data_center  = local.data_center
    dns_domain   = var.domain
    env          = var.env
    stage        = local.stage
  }
}
