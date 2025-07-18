# --------- Latest Amazon Linux AMI ---------------
data "aws_ami" "amz-ami" {
  most_recent = true
  owners      = ["amazon"]
   filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
   filter {
    name   = "architecture"
    values = ["x86_64"]
}

}

resource "aws_instance" "proxy" {
  count                     = length(var.public_subnets)
  ami                       = data.aws_ami.amz-ami.id
  instance_type             = var.instance_type
  subnet_id                 = var.public_subnets[count.index]
  vpc_security_group_ids     = var.aws_security_group
  associate_public_ip_address = true
  key_name                  = var.key_pair

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install nginx -y
              sudo systemctl start nginx
              sudo systemctl enable nginx
              sudo cat <<EOC > /etc/nginx/conf.d/reverse-proxy.conf
              server {
                  listen 80;
                  server_name _;

                  location / {
                      proxy_pass http://${var.load_balancer}:80;
                      proxy_http_version 1.1;
                      proxy_set_header Host \$host;
                      proxy_set_header X-Real-IP \$remote_addr;
                      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                  }
              }
              EOC
              sudo systemctl restart nginx
              EOF

  tags = {
    Name = "nginx-reverse-proxy-${count.index}"
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.private_key_path)
    host        = self.public_ip
  }


    provisioner "local-exec" {
    command = "echo Proxy-${count.index}: ${self.public_ip} >> proxy_ips.txt"
  }


}

