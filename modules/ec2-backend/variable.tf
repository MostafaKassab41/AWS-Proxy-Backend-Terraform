variable "private_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "key_pair" {
  description = "Key pair name for EC2 SSH access"
  type        = string
}

variable "private_key_path" {
  description = "Path to private SSH key on local machine"
  type        = string
}

variable "instance_type" {
    default = "t2.micro"
}

variable "aws_security_group" {
  
}
