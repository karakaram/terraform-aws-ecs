region = "ap-northeast-1"

vpc_state_config = {
  bucket = "karakaram-tfstate"
  key    = "env:/development/my-vpc.tfstate"
  region = "ap-northeast-1"
}

lb_name = "my-ecs"

cluster_name = "my-ecs-clister"

task_family = "my-ecs-task"

container_name = "cashbook-rails"

container_image = "274682760725.dkr.ecr.ap-northeast-1.amazonaws.com/cashbook-rails:latest"

container_port = 3000

service_name = "my-ecs-service"

desired_count = 1

environment = "development"
