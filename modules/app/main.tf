resource "aws_security_group" "app" {
  name        = "${var.project_name}-${var.environment}-app-sg"
  description = "Security group for app tier"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Traffic from web tier"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [var.web_sg_id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-sg"
    Environment = var.environment
    Project     = var.project_name
    Tier        = "app"
  }
}

resource "aws_lb" "app" {
  name               = "${var.project_name}-${var.environment}-app-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app.id]
  subnets            = var.app_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-alb"
    Environment = var.environment
    Project     = var.project_name
    Tier        = "app"
  }
}

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-${var.environment}-app-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/health"
    port                = var.app_port
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-tg"
    Environment = var.environment
    Project     = var.project_name
    Tier        = "app"
  }
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = var.app_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-${var.environment}-app-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(templatefile("${path.module}/user_data/app.sh", {
    app_port    = var.app_port
    db_endpoint = var.db_endpoint
    db_name     = var.db_name
    db_username = var.db_username
    db_password = var.db_password
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-${var.environment}-app-instance"
      Environment = var.environment
      Project     = var.project_name
      Tier        = "app"
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-lt"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-${var.environment}-app-asg"
  vpc_zone_identifier = var.app_subnet_ids
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  force_delete        = true

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-app-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Tier"
    value               = "app"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "app_cpu_scale_up" {
  name                   = "${var.project_name}-${var.environment}-app-cpu-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}

resource "aws_autoscaling_policy" "app_cpu_scale_down" {
  name                   = "${var.project_name}-${var.environment}-app-cpu-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}

resource "aws_cloudwatch_metric_alarm" "app_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-app-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "Scale up if CPU > 70% for 2 consecutive periods"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  alarm_actions = [aws_autoscaling_policy.app_cpu_scale_up.arn]
}

resource "aws_cloudwatch_metric_alarm" "app_cpu_low" {
  alarm_name          = "${var.project_name}-${var.environment}-app-cpu-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"
  alarm_description   = "Scale down if CPU < 30% for 2 consecutive periods"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  alarm_actions = [aws_autoscaling_policy.app_cpu_scale_down.arn]
}

# Application Health Alarm
resource "aws_cloudwatch_metric_alarm" "app_unhealthy_hosts" {
  alarm_name          = "${var.project_name}-${var.environment}-app-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "Alarm if there are unhealthy hosts in the app target group"

  dimensions = {
    TargetGroup  = aws_lb_target_group.app.arn_suffix
    LoadBalancer = aws_lb.app.arn_suffix
  }
}

output "sg_id" {
  value = aws_security_group.app.id
}

output "internal_alb_dns_name" {
  value = aws_lb.app.dns_name
}
