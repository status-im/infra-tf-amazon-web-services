/* DNS ------------------------------------------*/

variable "cf_zone_id" {
  description = "ID of CloudFlare zone for host record."
  type        = string
  default     = "fd48f427e99bbe1b52105351260690d1"
}

variable "domain" {
  description = "Public DNS Domain address"
  type        = string
  default     = "status.im"
}

/* SCALING --------------------------------------*/

variable "host_count" {
  description = "Number of instances to create."
  type        = number
  default     = 1
}

variable "type" {
  description = "Name of instance type to use"
  type        = string
  default     = "t2.micro"
}

variable "root_vol_size" {
  description = "Size in GiB of OS root volume."
  type        = number
  default     = 10
}

variable "data_vol_size" {
  description = "Size in GiB of OS root volume."
  type        = number
  default     = 0
  /* 0 in this case means no extra data volume */
}

variable "data_vol_type" {
  description = "Type of data volume"
  type        = string
  default     = "standard" /* standard, gp2, io1, sc1, st1 */
}

variable "data_vol_iops" {
  description = "Amount of IOPS to provision for the disk. Valid io1 or io2."
  type        = string
  default     = 1000 /* WARNING: IOPS to volume size ration maximum is 50. */
}

/* IMAGE ----------------------------------------*/

variable "image_name" {
  description = "Name of AMI image to use."
  type        = string
  default     = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20250516"
  /* Use: aws ec2 describe-images --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64*' | jq -r '.Images[].Name' */
}

variable "image_owner" {
  description = "ID of the owner of AMI image."
  type        = string
  default     = "099720109477"
}

variable "ssh_user" {
  description = "User used for SSH access."
  type        = string
  default     = "ubuntu"
}

/* PROTECTION -----------------------------------*/

// https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Stop_Start.html#Using_StopProtection
variable "disable_api_stop" {
  description = "Enables EC2 Instance Stop Protection."
  type        = bool
  default     = false
}

// https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/terminating-instances.html#Using_ChangingDisableAPITermination
variable "disable_api_termination" {
  description = "Enables EC2 Instance Termination Protection."
  type        = bool
  default     = false
}

// https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-recover.html
variable "auto_recovery" {
  description = "Automatic recovery behavior of the Instance."
  type        = string
  default     = "default" // or "disabled"
}

/* HOSTING --------------------------------------*/

variable "zone" {
  description = "Name of availability zone to deploy to."
  type        = string
  default     = "eu-central-1a"
}

/* SECURITY -------------------------------------*/

variable "keypair_name" {
  description = "Name of SSH key pair in AWS."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC for instances"
  type        = string
}

variable "subnet_id" {
  description = "ID of the Subnet for instances"
  type        = string
}

variable "ipv6_address_count" {
  description = "ID of the Subnet for instances"
  type        = number
  default     = 1
}

variable "secgroup_id" {
  description = "ID of the Security Group for instances"
  type        = string
}

/* FIREWQLL -------------------------------------*/

variable "open_tcp_ports" {
  description = "Which TCP ports should be opened on the firewal."
  type        = list(string)
  default     = []
}

variable "open_udp_ports" {
  description = "Which UDP ports should be opened on the firewal."
  type        = list(string)
  default     = []
}

/* SPECIFIC -------------------------------------*/

variable "provider_name" {
  description = "Short name of provider being used."
  type        = string
  default     = "aws" /* Amazon Web Services */
}

variable "name" {
  description = "Prefix of hostname before index."
  type        = string
  default     = "node"
}

variable "group" {
  description = "Name of Ansible group"
  type        = string
}

variable "env" {
  description = "Name of environment to create"
  type        = string
}

variable "stage" {
  description = "Name of stage, like prod, dev, or staging."
  type        = string
  default     = ""
}
