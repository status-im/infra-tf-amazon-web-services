/* DNS ------------------------------------------*/

variable cf_zone_id {
  description = "ID of CloudFlare zone for host record."
  /* We default to: statusim.net */
  default     = "14660d10344c9898521c4ba49789f563"
}

/* SCALING --------------------------------------*/

variable host_count {
  description = "Number of instances to create."
  type        = number
}

variable instance_type {
  description = "Name of instance type to use"
  type        = string
  default     = "t2.micro"
}

variable root_vol_size {
  description = "Size in GiB of OS root volume."
  default     = 10
}

variable data_vol_size {
  description = "Size in GiB of OS root volume."
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
  default     = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-20190212.1"
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

variable keypair_name {
  description = "Name of SSH key pair in AWS."
  type        = string
}

/* FIREWQLL -------------------------------------*/

variable open_tcp_ports {
  description = "Which TCP ports should be opened on the firewal."
  type        = list(number)
  default     = []
}

variable open_udp_ports {
  description = "Which UDP ports should be opened on the firewal."
  type        = list(number)
  default     = []
}

/* SPECIFIC -------------------------------------*/

variable name {
  description = "Prefix of hostname before index."
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
