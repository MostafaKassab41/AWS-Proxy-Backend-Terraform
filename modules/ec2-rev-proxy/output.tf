output "proxy_public_ips" {
  value = aws_instance.proxy[*].public_ip
}

output "proxy_ID" {
  value = aws_instance.proxy[*].id
}