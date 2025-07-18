variable "key_pair" {
  default = "kassab"
}

variable "private_key_path" {
  default = "~/kassab.pem"
}

variable "aws_security_group" {
  default = ""
}

variable "load_balancer" {
  default = "192.168.1.2"
}