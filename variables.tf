/* DNS ------------------------------------------*/

variable cf_zone_id {
  description = "ID of CloudFlare zone for host record."
  type        = string
  /* We default to: statusim.net */
  default     = "14660d10344c9898521c4ba49789f563"
}

/* SCALING --------------------------------------*/

variable host_count {
  description = "Number of instances to create."
  type        = number
  default     = 1
}

variable instance_type {
  description = "Name of instance type to use"
  type        = string
  default     = "t2.micro"
}

variable root_vol_size {
  description = "Size in GiB of OS root volume."
  type        = number
  default     = 10
}

variable data_vol_size {
  description = "Size in GiB of OS root volume."
  type        = number
  /* 0 in this case means no extra data volume */
  default     = 0
}

variable data_vol_type {
  description = "Type of data volume"
  type        = string
  default     = "standard" # standard, gp2, io1, sc1, st1"
}

/* IMAGE ----------------------------------------*/

variable image_name {
  description = "Name of AMI image to use."
  type        = string
  /* Use: aws ec2 describe-images --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-focal-20.04*' */
  default     = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20200701"
}

variable image_owner {
  description = "ID of the owner of AMI image."
  type        = string
  default     = "099720109477"
}

variable ssh_user {
  description = "User used for SSH access."
  type        = string
  default     = "ubuntu"
}

/* HOSTING --------------------------------------*/

variable zone {
  description = "Name of availability zone to deploy to."
  type        = string
  default     = "eu-central-1a"
}

variable domain {
  description = "Public DNS Domain address"
  type        = string
}

/* SECURITY -------------------------------------*/

variable keypair_name {
  description = "Name of SSH key pair in AWS."
  type        = string
}

variable vpc_id {
  description = "ID of the VPC for instances"
  type        = string
}

variable subnet_id {
  description = "ID of the Subnet for instances"
  type        = string
}

variable secgroup_id {
  description = "ID of the Security Group for instances"
  type        = string
}

/* FIREWQLL -------------------------------------*/

variable open_tcp_ports {
  description = "Which TCP ports should be opened on the firewal."
  type        = list(string)
  default     = []
}

variable open_udp_ports {
  description = "Which UDP ports should be opened on the firewal."
  type        = list(string)
  default     = []
}

/* SPECIFIC -------------------------------------*/

variable provider_name {
  description = "Short name of provider being used."
  type        = string
  # Amazon Web Services
  default     = "aws"
}

variable name {
  description = "Prefix of hostname before index."
  type        = string
  default     = "node"
}

variable group {
  description = "Name of Ansible group"
  type        = string
}

variable env {
  description = "Name of environment to create"
  type        = string
}

variable stage {
  description = "Name of stage, like prod, dev, or staging."
  type        = string
  default     = ""
}
