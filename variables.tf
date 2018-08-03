variable "region" {
  description = "A region for the VPC"
}

variable "vpc_state_config" {
  description = "A config for accessing the vpc state file"
  type        = "map"
}

variable "lb_name" {
  description = "The resource name and Name tag of the load balancer"
}

variable "cluster_name" {
  description = "The resource name of the ECS Cluster"
}

variable "task_family" {
  description = "A unique name for your task definition"
}

variable "container_name" {
  description = "Contanier name to run in the ECS cluster"
}

variable "container_image" {
  description = "Docker image to run in the ECS cluster"
}

variable "container_port" {
  description = "Port exposed by the docker image to redirect traffic to"
}

variable "service_name" {
  description = "A unique name for your task definition"
}

variable "desired_count" {
  description = "Number of docker containers to run"
}

variable "rails_master_key" {
  description = "A master_key for rails"
}

variable "environment" {
  description = "The environment to use for the instance"
}
