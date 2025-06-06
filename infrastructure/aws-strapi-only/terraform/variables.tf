variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "strapi-infra-test"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "strapi_db"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "strapi_user"
}

variable "db_password" {
  description = "Database password"
  type        = string
  default     = "ChangeThisPassword123!"
  sensitive   = true
}

variable "ecs_cpu" {
  description = "ECS task CPU"
  type        = string
  default     = "256"
}

variable "ecs_memory" {
  description = "ECS task memory"
  type        = string
  default     = "512"
}

variable "ecs_desired_count" {
  description = "ECS service desired count"
  type        = number
  default     = 1
} 