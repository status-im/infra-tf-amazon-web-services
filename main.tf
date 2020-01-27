locals {
  host_suffix      = "${var.zone}.${var.env}.${var.stage}"
  host_full_suffix = "${local.host_suffix}.${var.domain}"
  /* got to add some default groups */
  groups = distinct(concat([var.zone, "${var.env}.${var.stage}"], var.groups))
  /* always add SSH, Tinc, Netdata, and Consul to allowed ports */
  open_tcp_ports  = concat(["22", "655", "8000", "8301"], var.open_tcp_ports)
  open_udp_ports  = concat(["8301"], var.open_udp_ports)
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
  name        = "default-${var.zone}-${var.env}-${var.stage}"
  description = "Allow SSH and other ports. (Terraform)"

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

  dynamic "ingress" {
    iterator = port
    for_each = local.open_tcp_ports
    content {
      from_port = port.value
      to_port   = port.value
      protocol  = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

resource "aws_instance" "host" {
  instance_type     = var.instance_type
  availability_zone = var.zone
  count             = var.host_count

  /* necessary for SSH access */
  associate_public_ip_address = true

  ami                    = data.aws_ami.ubuntu.id
  key_name               = var.keypair_name
  vpc_security_group_ids = [aws_security_group.host.id]

  root_block_device {
    volume_size = var.root_vol_size
  }

  tags = {
    Name  = "node-${format("%02d", count.index+1)}.${local.host_suffix}"
    Fqdn  = "node-${format("%02d", count.index+1)}.${local.host_full_suffix}"
    Fleet = "${var.env}.${var.stage}"
  }
  
  /* for snapshots through lifecycle policy */
  volume_tags = {
    Fleet = "${var.env}.${var.stage}"
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
        data_center      = var.zone
        env              = var.env
        stage            = var.stage
      }
    }
  }
}

resource "aws_ebs_volume" "host" {
  availability_zone = var.zone

  size = var.data_vol_size
  type = var.data_vol_type

  count = (var.data_vol_size == 0 ? 0 : 1)
}

resource "aws_volume_attachment" "host" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.host.0.id
  instance_id = aws_instance.host.id

  count = (var.data_vol_size == 0 ? 0 : 1)
}
resource "cloudflare_record" "host" {
  zone_id = var.cf_zone_id
  count   = length(aws_instance.host)
  name    = aws_instance.host[count.index].tags.Name
  value   = aws_instance.host[count.index].public_ip
  type    = "A"
  ttl     = 3600
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
    dns_domain   = var.domain
    data_center  = var.zone
    env          = var.env
    stage        = var.stage
  }
}
