resource "aws_security_group" "web" {
  name        = "${var.project_name}-${var.environment}-web-sg"
  description = "Security group for web tier"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-web-sg"
    Environment = var.environment
    Project     = var.project_name
    Tier        = "web"
  }
}

resource "aws_lb" "web" {
  name               = "${var.project_name}-${var.environment}-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name        = "${var.project_name}-${var.environment}-web-alb"
    Environment = var.environment
    Project     = var.project_name
    Tier        = "web"
  }
}

resource "aws_lb_target_group" "web" {
  name        = "${var.project_name}-${var.environment}-web-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    interval            = var.health_check_interval
    path                = var.health_check_path
    port                = var.app_port
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-web-tg"
    Environment = var.environment
    Project     = var.project_name
    Tier        = "web"
  }
}

resource "aws_lb_listener" "web_http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb_listener" "web_https" {
  count             = var.certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.web.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb_listener" "web_http_redirect" {
  count             = var.certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-${var.environment}-web-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = base64encode(templatefile("${path.module}/user_data/web.sh", {
    app_alb_dns = var.app_alb_dns
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-${var.environment}-web-instance"
      Environment = var.environment
      Project     = var.project_name
      Tier        = "web"
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-web-lt"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_autoscaling_group" "web" {
  name                = "${var.project_name}-${var.environment}-web-asg"
  vpc_zone_identifier = var.public_subnet_ids
  target_group_arns   = [aws_lb_target_group.web.arn]
  health_check_type   = "ELB"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  force_delete        = true

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-web-instance"
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
    value               = "web"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "web_cpu_scale_up" {
  name                   = "${var.project_name}-${var.environment}-web-cpu-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}

resource "aws_autoscaling_policy" "web_cpu_scale_down" {
  name                   = "${var.project_name}-${var.environment}-web-cpu-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-web-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "Scale up if CPU > 70% for 2 consecutive periods"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  alarm_actions = [aws_autoscaling_policy.web_cpu_scale_up.arn]
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_low" {
  alarm_name          = "${var.project_name}-${var.environment}-web-cpu-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"
  alarm_description   = "Scale down if CPU < 30% for 2 consecutive periods"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  alarm_actions = [aws_autoscaling_policy.web_cpu_scale_down.arn]
}

resource "aws_wafv2_web_acl" "web" {
  name        = "${var.project_name}-${var.environment}-web-acl"
  description = "WAF ACL for web tier"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "rate-limit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-sqli"
    priority = 2

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-sqli"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-xss"
    priority = 3

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-xss"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-web-acl"
    Environment = var.environment
    Project     = var.project_name
    Tier        = "web"
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-web-acl"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "web" {
  resource_arn = aws_lb.web.arn
  web_acl_arn  = aws_wafv2_web_acl.web.arn
}

output "sg_id" {
  value = aws_security_group.web.id
}

output "alb_dns_name" {
  value = aws_lb.web.dns_name
}

output "alb_zone_id" {
  value = aws_lb.web.zone_id
}

output "target_group_arn" {
  value = aws_lb_target_group.web.arn
}

output "waf_acl_arn" {
  value = aws_wafv2_web_acl.web.arn
}
