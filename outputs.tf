locals {
  public_ips = aws_eip.host[*].public_ip
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
