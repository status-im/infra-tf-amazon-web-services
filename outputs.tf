locals {
  public_ips = aws_instance.host[*].public_ip
  host_names = aws_instance.host[*].tags.Name
}

output "public_ips" {
  value = local.public_ips
}

output "hostnames" {
  value = local.host_names
}

output "hosts" {
  value = zipmap(local.host_names, local.public_ips)
}

output "instances" {
  value = aws_instance.host
}
