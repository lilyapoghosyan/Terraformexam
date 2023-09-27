resource "aws_launch_configuration" "web" {
  name_prefix     = "WEBServer-LC-"
  image_id        = "ami-0ab1a82de7ca5889c"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.public_sg.id]


  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_autoscaling_group" "web" {
  name                 = "ASG-${aws_launch_configuration.web.name}"
  launch_configuration = aws_launch_configuration.web.name
  min_size             = 2
  max_size             = 2
  desired_capacity     = 2
  vpc_zone_identifier  = aws_subnet.public[*].id
  health_check_type    = "ELB"
  load_balancers       = [aws_elb.web.id]

  dynamic "tag" {
    for_each = {
      Name   = "Webserver_ASG"
      owner  = "Lilia"
      TAGKEY = "TAGVALUE"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true

    }
  }


}

resource "aws_elb" "web" {
  name            = "WebServer-HA-ELB"
  security_groups = [aws_security_group.public_sg.id]
  subnets         = [aws_subnet.public[0].id]
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {

    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 10
  }

  tags = {
    Name = "WebServer_Highly_Available_ELB"
  }

}





