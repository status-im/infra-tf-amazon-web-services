locals {
  public_ips = [for a in aws_eip.host : a.public_ip]
}

output "public_ips" {
  value = local.public_ips
}

output "public_ips_v6" {
  value = flatten([for a in aws_instance.host : a.ipv6_addresses])
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
