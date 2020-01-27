locals {
  public_ips = aws_instance.host[*].public_ip
  hostnames  = aws_instance.host[*].tags.Name
}

output "public_ips" {
  value = local.public_ips
}

output "hostnames" {
  value = local.hostnames
}

output "hosts" {
  value = zipmap(local.hostnames, local.public_ips)
}

output "instances" {
  value = aws_instance.host
}
