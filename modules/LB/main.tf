resource "aws_lb" "LB" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [var.security_groups]
  subnets            = var.subnets
  enable_deletion_protection = false

  tags = {
    name = var.name
  }
  provisioner "local-exec" {
    command = "echo ${var.name} LB DNS ${self.dns_name} >> all_ips.txt"
  }
}

resource "aws_lb_target_group" "Target_Group" {
  name     = var.name
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group_attachment" "TG_Attach" {
  depends_on = [ var.instance_ids ]
  count            = length(var.instance_ids)
  target_group_arn = aws_lb_target_group.Target_Group.arn
  target_id        = var.instance_ids[count.index]
  port             = 80
}


resource "aws_lb_listener" "BackEnd_l" {
  load_balancer_arn = aws_lb.LB.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.Target_Group.arn
  }
}