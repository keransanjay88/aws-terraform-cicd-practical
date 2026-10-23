# Latest Amazon Linux 2023 AMI, looked up from the public AWS parameter
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------------- Launch template ----------------
resource "aws_launch_template" "this" {
  name_prefix   = "${var.project}-lt-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.instance_profile_name
  }

  # Private instances: no public IP, security group attached here
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.ec2_sg_id]
    delete_on_termination       = true
  }

  # IMDSv2 required (blocks the older, weaker metadata method)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Encrypted root disk (free AWS-managed key)
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = false # detailed monitoring costs extra
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    region      = var.region
    secret_name = var.secret_name
    app_bucket  = var.app_bucket_name
    app_s3_key  = var.app_s3_key
    app_port    = var.app_port
    app_version = var.app_version
  }))

  update_default_version = true

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project}-app" }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "${var.project}-app-volume" }
  }

  tags = { Name = "${var.project}-lt" }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------- Auto Scaling Group ----------------
resource "aws_autoscaling_group" "this" {
  name                = "${var.project}-asg"
  vpc_zone_identifier = var.app_subnet_ids

  min_size         = var.min_size
  desired_capacity = var.desired_capacity
  max_size         = var.max_size

  target_group_arns         = [var.target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = var.health_check_grace_period

  # Terraform waits until the ALB sees healthy servers, so a finished
  # apply means the app is actually up.
  wait_for_elb_capacity     = var.desired_capacity
  wait_for_capacity_timeout = "15m"

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  # Rolling replacement when the launch template (or app version) changes
  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 120
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project}-app"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------- Scale out when average CPU > 50% ----------------
resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.project}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50
  }
}