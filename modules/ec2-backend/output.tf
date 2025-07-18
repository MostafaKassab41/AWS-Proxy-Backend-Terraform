output "backend_private_ips" {
  value = aws_instance.backend[*].private_ip
}

output "backend_ID" {
  value = aws_instance.backend[*].id
}