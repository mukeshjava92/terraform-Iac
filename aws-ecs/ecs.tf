provider "aws" {
  region = "ap-south-1"
  # access_key = "var.access_key"
  #secret_key = "var.secret_key"
}

# Lookup VPC by tag
data "aws_vpc" "ecsvpc" {
  filter {
    name   = "tag:Name"
    values = ["Cloud-VPC"]
  }
}

# Lookup subnets by VPC ID and tag
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.ecsvpc.id]
  }

  filter {
    name   = "tag:Type"
    values = ["Private"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.ecsvpc.id]
  }

  filter {
    name   = "tag:Type"
    values = ["Public"]
  }
}

# Output VPC ID
output "vpc_id" {
  value = data.aws_vpc.ecsvpc.id
}

# Output subnet IDs
output "private_subnet_ids" {
  value = data.aws_subnets.private.ids[*]
}

variable "sg_port" {
  default = [80, 443, 22]
}

## Load Balancer SG ##
resource "aws_security_group" "ecs-sg" {
    name = "allow-tls"
    vpc_id = data.aws_vpc.ecsvpc.id
    tags = {
      Name = "Load Balancer SG"
    }
}

resource "aws_vpc_security_group_ingress_rule" "ecs-ingress"{
    security_group_id = aws_security_group.ecs-sg.id
    count = length(var.sg_port)
    cidr_ipv4 = "0.0.0.0/0"
    ip_protocol = "tcp"
    from_port = var.sg_port[count.index]
    to_port = var.sg_port[count.index]
}


resource "aws_vpc_security_group_egress_rule" "ecs-egress" {
  security_group_id = aws_security_group.ecs-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

## ECS role

resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole1"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Effect = "Allow"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_profile" {
  name = "ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}

#### Fetching AMI ########
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}
data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "image-id"
    values = [jsondecode(data.aws_ssm_parameter.ecs_ami.value)["image_id"]]
  }
}

####################### EC2 Launch Templete####################################

resource "aws_launch_template" "ecs-launch" {
  name = "ecs-launch"
  instance_type = "t3.small"
  image_id = data.aws_ami.ecs_optimized.id
  key_name = "ecs"
  network_interfaces {
    subnet_id = data.aws_subnets.private.ids[0]
    security_groups = [aws_security_group.ecs-sg.id]
    associate_public_ip_address = false
    delete_on_termination       = true
  }
  block_device_mappings {
    device_name = "/dev/sdf"
    ebs {
      volume_size = 20
    }
  }
  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_profile.name
  }
  user_data = base64encode(<<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
EOF
)
}


### ECS Cluster creation#####

resource "aws_ecs_cluster" "main" {
  name = "ecs-ec2-cluster"
}
#####


/*resource "aws_ecs_capacity_provider" "asg_provider" {
  name = "asg-ecs-provider"
  auto_scaling_group_provider {
    auto_scaling_group_arn      = aws_autoscaling_group.ecs_asg.arn
    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 80
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 100
    }
    managed_termination_protection = "ENABLED"
  }
#}

resource "aws_ecs_cluster_capacity_providers" "ecs_cp_attach" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.asg_provider.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.asg_provider.name
    weight            = 1
    base              = 1
  }
}

*/


resource "aws_ecs_task_definition" "web" {
  family                   = "web-task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  container_definitions    = jsonencode([
    {
      name      = "web",
      image     = "nginx",
      cpu       = 256,
      memory    = 512,
      essential = true,
      portMappings = [{
        containerPort = 80,
        hostPort      = 80
      }]
    }
  ])
}

resource "aws_ecs_service" "web" {
  name            = "web-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = 2
  launch_type     = "EC2"
}

## Load Balancer SG #####################
resource "aws_security_group" "lb-sg" {
    name = "allow-lb"
    vpc_id = data.aws_vpc.ecsvpc.id
    tags = {
      Name = "Load Balancer SG"
    }
}

resource "aws_vpc_security_group_ingress_rule" "lb-ingress"{
    security_group_id = aws_security_group.lb-sg.id
    cidr_ipv4 = "0.0.0.0/0"
    ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "lb-egress" {
  security_group_id = aws_security_group.lb-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

############################ Load Balancer #######################################
resource "aws_lb" "ecslb" {
  name               = "ecs-lb-projet"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb-sg.id]
  subnets            = [data.aws_subnets.public.ids[0],data.aws_subnets.public.ids[1]]
  tags = {
    Environment = "Dev"
  }
}

resource "aws_lb_target_group" "test" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.ecsvpc.id
  target_type = "instance"
  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.ecslb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test.arn
  }
}

resource "aws_autoscaling_group" "ecs_asg" {
  desired_capacity     = 1
  max_size             = 4
  min_size             = 1
  vpc_zone_identifier  = data.aws_subnets.private.ids

  launch_template {
    id      = aws_launch_template.ecs-launch.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.test.arn]
  tag {
    key                 = "Name"
    value               = "ecs-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

