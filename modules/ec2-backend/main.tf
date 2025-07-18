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

resource "aws_instance" "backend" {
  count                     = length(var.private_subnets)
  ami                       = data.aws_ami.amz-ami.id
  instance_type             = var.instance_type
  subnet_id                 = var.private_subnets[count.index]
  vpc_security_group_ids     = var.aws_security_group
  key_name                  = var.key_pair

  // User data to install Apache
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd
              sudo systemctl start httpd
              sudo systemctl enable httpd
              echo "<h1>Hello from Terraform Apache backend-${count.index}!</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "backend-${count.index}"
  }

}