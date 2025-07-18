resource "aws_subnet" "project_sub" {
  vpc_id     = var.vpc_id
  cidr_block = var.cidr_block
  availability_zone = var.availability_zone
  
  tags = {
    Name = var.Name
  }
}