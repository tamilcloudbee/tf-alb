/*

resource "aws_security_group" "alb_sg" {
  name        = "${var.resource_prefix}-alb-sg"
  description = "Security group for the ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow incoming HTTP traffic
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow incoming HTTPS traffic (if using HTTPS)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.resource_prefix}-alb-sg"
  }
}


resource "aws_lb" "alb" {
  name               = "${var.resource_prefix}${var.load_balancer_type}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]  # Attach ALB Security Group
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Environment = var.env_name
    Name        = "${var.resource_prefix}${var.load_balancer_type}-alb"
  }
}


==================
*/
resource "aws_security_group" "alb_sg" {
  name        = "${var.resource_prefix}-alb-sg"
  description = "Security group for the ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow incoming HTTP traffic
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow incoming HTTPS traffic
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.resource_prefix}-alb-sg"
  }
}

resource "aws_lb" "alb" {
  name               = "${var.resource_prefix}${var.load_balancer_type}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]  # Attach ALB Security Group
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Environment = var.env_name
    Name        = "${var.resource_prefix}${var.load_balancer_type}-alb"
  }
}

# Target group for "admin" path
resource "aws_lb_target_group" "admin" {
  name     = "${var.resource_prefix}-admin-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    interval            = 30
    path                = "/admin/health"  # Custom health check path for admin
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.resource_prefix}-admin-tg"
  }
}

# Target group for "register" path
resource "aws_lb_target_group" "register" {
  name     = "${var.resource_prefix}-register-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    interval            = 30
    path                = "/register/health"  # Custom health check path for register
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.resource_prefix}-register-tg"
  }
}

# Target group for root (main) path
resource "aws_lb_target_group" "main" {
  name     = "${var.resource_prefix}-main-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    interval            = 30
    path                = "/health"  # Custom health check path for main app
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.resource_prefix}-main-tg"
  }
}

# Create listener for HTTP (Port 80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.main.arn  # Default to main target group
      }
    }
  }
}
resource "aws_lb_listener_rule" "admin_rule" {
  listener_arn = aws_lb_listener.http.arn

  action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.admin.arn
      }
    }
  }

  condition {
    path_pattern {
      values = ["/admin*", "/admin/*"]
    }
  }
}

resource "aws_lb_listener_rule" "register_rule" {
  listener_arn = aws_lb_listener.http.arn

  action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.register.arn
      }
    }
  }

  condition {
    path_pattern {
      values = ["/register*", "/register/*"]
    }
  }
}

# Attach main instances to the main target group
resource "aws_lb_target_group_attachment" "main_attachment" {
  for_each = var.main_instance_ids
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = each.value
  port             = 80
}

# Attach admin instances to the admin target group
resource "aws_lb_target_group_attachment" "admin_attachment" {
  for_each = var.admin_instance_ids
  target_group_arn = aws_lb_target_group.admin.arn
  target_id        = each.value
  port             = 80
}

# Attach register instances to the register target group
resource "aws_lb_target_group_attachment" "register_attachment" {
  for_each = var.register_instance_ids
  target_group_arn = aws_lb_target_group.register.arn
  target_id        = each.value
  port             = 80
}