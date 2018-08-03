provider "aws" {
  region = "${var.region}"
}

terraform {
  backend "s3" {}
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config  = "${var.vpc_state_config}"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid = ""

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    effect = "Allow"
  }
}

resource "aws_security_group" "alb" {
  name        = "${var.lb_name}"
  description = "Security group for ${var.lb_name}"
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = "${var.container_port}"
    to_port     = "${var.container_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "application" {
  name               = "${var.lb_name}"
  load_balancer_type = "application"
  internal           = false
  security_groups    = ["${aws_security_group.alb.id}"]
  subnets            = ["${data.terraform_remote_state.vpc.public_subnets}"]
  ip_address_type    = "ipv4"

  tags = {
    Name        = "${var.lb_name}"
    Environment = "${var.environment}"
  }
}

resource "aws_lb_target_group" "fargate" {
  name_prefix          = "${var.lb_name}"
  port                 = "${var.container_port}"
  protocol             = "HTTP"
  vpc_id               = "${data.terraform_remote_state.vpc.vpc_id}"
  deregistration_delay = 10
  target_type          = "ip"

  health_check = [{
    interval            = 10
    path                = "/dashboard/index"
    port                = "${var.container_port}"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = 200
  }]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = "${aws_lb.application.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.fargate.arn}"
    type             = "forward"
  }
}

resource "aws_iam_role" "ecs_task" {
  name               = "${var.task_family}-execution_role"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role.json}"
}

resource "aws_iam_role_policy_attachment" "ecs_task" {
  role       = "${aws_iam_role.ecs_task.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_cluster" "main" {
  name = "${var.cluster_name}"
}

resource "aws_cloudwatch_log_group" "main" {
  name = "/ecs/${var.cluster_name}"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "main" {
  family                   = "${var.task_family}"
  execution_role_arn       = "${aws_iam_role.ecs_task.arn}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512

  container_definitions = <<DEFINITION
[
  {
    "networkMode": "awsvpc",
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/${var.cluster_name}",
        "awslogs-region": "ap-northeast-1",
        "awslogs-stream-prefix": "ecs"
      }
    },
    "portMappings": [
      {
        "hostPort": ${var.container_port},
        "protocol": "tcp",
        "containerPort": ${var.container_port}
      }
    ],
    "command": [
      "bundle",
      "exec",
      "pumactl",
      "start"
    ],
    "cpu": 256,
    "environment": [
      {
        "name": "RAILS_ENV",
        "value": "production"
      },
      {
        "name": "RAILS_LOG_TO_STDOUT",
        "value": "1"
      },
      {
        "name": "RAILS_MASTER_KEY",
        "value": "${var.rails_master_key}"
      }
    ],
    "memoryReservation": 512,
    "workingDirectory": "/myapp",
    "image": "${var.container_image}",
    "name": "${var.container_name}"
  }
]
DEFINITION
}

resource "aws_security_group" "ecs_service" {
  name        = "${var.service_name}"
  description = "Security group for ${var.service_name}"
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"

  ingress {
    protocol        = "tcp"
    from_port       = "${var.container_port}"
    to_port         = "${var.container_port}"
    security_groups = ["${aws_security_group.alb.id}"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_service" "main" {
  name            = "${var.service_name}"
  cluster         = "${aws_ecs_cluster.main.id}"
  task_definition = "${aws_ecs_task_definition.main.arn}"
  desired_count   = "${var.desired_count}"
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = ["${aws_security_group.ecs_service.id}"]
    subnets         = ["${data.terraform_remote_state.vpc.private_subnets}"]
  }

  load_balancer {
    target_group_arn = "${aws_lb_target_group.fargate.id}"
    container_name   = "${var.container_name}"
    container_port   = "${var.container_port}"
  }

  depends_on = [
    "aws_lb_listener.http",
  ]
}
