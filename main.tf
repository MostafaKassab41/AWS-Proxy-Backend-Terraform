
# -----------------  remote bucket for statefile ---------------------

#  S3 bucket
resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-terraform-state-backend-kassab"

  tags = {
    Name        = "My Backend"
  }
}

# Block public access to the bucket 
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Lock Table
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "terraform-state-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# ----------------------------------------------------------------------------
# ------------ Networking --------------------

# VPC ---------
module "VPC" {
  source = "./modules/VPC"
  cidr_block = "10.0.0.0/16"
}

# Public Subnets ---------
module "public_subnet_00" {
  source = "./modules/SB"
  Name = "Pub-sub-0.0"
  cidr_block = "10.0.0.0/24"
  vpc_id = module.VPC.project_vpc-id
  availability_zone = "us-east-1a"
}

module "public_subnet_20" {
  source = "./modules/SB"
  Name = "Pub-sub-2.0"
  cidr_block = "10.0.2.0/24"
  vpc_id = module.VPC.project_vpc-id
  availability_zone = "us-east-1b"
}

# Private Subnets ---------
module "private_subnet_10" {
  source = "./modules/SB"
  Name = "Priv-sub-1.0"
  cidr_block = "10.0.1.0/24"
  vpc_id = module.VPC.project_vpc-id
  availability_zone = "us-east-1a"
}

module "private_subnet_30" {
  source = "./modules/SB"
  Name = "Priv-sub-3.0"
  cidr_block = "10.0.3.0/24"
  vpc_id = module.VPC.project_vpc-id
  availability_zone = "us-east-1b"
}


# --- Networking for Public Subnet ---
# Internet Gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = module.VPC.project_vpc-id
  tags = {
    Name = "main-igw"
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = module.VPC.project_vpc-id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate Public Subnet with Route Table
resource "aws_route_table_association" "public_subnet00_association" {
  subnet_id      = module.public_subnet_00.subnet_id
  route_table_id = aws_route_table.public_route_table.id
}
resource "aws_route_table_association" "public_subnet20_association" {
  subnet_id      = module.public_subnet_20.subnet_id
  route_table_id = aws_route_table.public_route_table.id
}


# --- Networking for Private Subnet ---
# Elastic IP for the NAT Gateway (required for NAT Gateway)
resource "aws_eip" "nat_eip" {
  domain   = "vpc"
  depends_on = [aws_internet_gateway.main_igw]
  tags = {
    Name = "nat-eip"
  }
}

# NAT Gateway to allow instances in the private subnet to access the internet
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = module.public_subnet_20.subnet_id
  depends_on    = [aws_eip.nat_eip]
  tags = {
    Name = "nat-gw"
  }
}


# Route Table for the private subnet
resource "aws_route_table" "private_rt" {
  vpc_id = module.VPC.project_vpc-id

  # Route to the internet via the NAT Gateway
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-rt"
  }
}


# Associate the private route table with the private subnet
resource "aws_route_table_association" "private_assoc10" {
  subnet_id      = module.private_subnet_10.subnet_id
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_route_table_association" "private_assoc30" {
  subnet_id      = module.private_subnet_30.subnet_id
  route_table_id = aws_route_table.private_rt.id
}


# ----------------------------------------------------------------------------
# ------------ Security Group --------------------
resource "aws_security_group" "sg" {
  name        = "security-group"
  description = "Allow HTTP and SSH inbound traffic"
  vpc_id      = module.VPC.project_vpc-id
  // Inbound rules
  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Outbound rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "project-sg"
  }
}


# ----------------------------------------------------------------------------
# ------------ Enstance --------------------

# Rev Proxy
module "rev-proxy" {
  source = "./modules/ec2-rev-proxy"
  public_subnets = [ module.public_subnet_00.subnet_id , module.public_subnet_20.subnet_id ]
  key_pair = var.key_pair
  private_key_path  = var.private_key_path
  aws_security_group = [aws_security_group.sg.id]
  load_balancer = module.internal_load_balancer.LB_dns
}

# backend
module "ec2-backend" {
  source = "./modules/ec2-backend"
  private_subnets = [ module.private_subnet_10.subnet_id , module.private_subnet_30.subnet_id ]
  key_pair = var.key_pair
  private_key_path  = var.private_key_path
  aws_security_group = [aws_security_group.sg.id]
}

# ----------------------------------------------------------------------------
# ------------ Load Balancer --------------------
module "internal_load_balancer" {
  source = "./modules/LB"
  name = "internal"
  internal = true
  security_groups = aws_security_group.sg.id
  subnets = [ module.private_subnet_10.subnet_id , module.private_subnet_30.subnet_id ]
  vpc_id = module.VPC.project_vpc-id
  instance_ids = module.ec2-backend.backend_ID
}

module "public_load_balancer" {
  source = "./modules/LB"
  name = "public"
  internal = false
  security_groups = aws_security_group.sg.id
  subnets = [ module.public_subnet_00.subnet_id , module.public_subnet_20.subnet_id ]
  vpc_id = module.VPC.project_vpc-id
  instance_ids = module.rev-proxy.proxy_ID
}