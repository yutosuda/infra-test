# AWS全体構成（Strapi + Next.js）- 無料枠最適化版
# 両方のアプリケーションをAWSで運用し、無料枠内に収める構成

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "aws-all-infra-test"
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

# 無料枠制約: db.t3.micro
variable "db_instance_class" {
  description = "RDS instance class (Free tier: db.t3.micro)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "app_db"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "app_user"
}

variable "db_password" {
  description = "Database password"
  type        = string
  default     = "ChangeThisPassword123!"
  sensitive   = true
}

# 無料枠制約: t3.micro
variable "ec2_instance_type" {
  description = "EC2 instance type (Free tier: t3.micro)"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
  default     = "aws-all-keypair"
}

# アプリケーション設定
variable "strapi_port" {
  description = "Strapi application port"
  type        = number
  default     = 1337
}

variable "nextjs_port" {
  description = "Next.js application port"
  type        = number
  default     = 3000
}

# ドメイン設定（オプション）
variable "domain_name" {
  description = "Domain name for the application (optional)"
  type        = string
  default     = ""
}

# 無料枠監視設定
variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring (may incur costs)"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "RDS backup retention period (Free tier: 7 days max)"
  type        = number
  default     = 7
}

# セキュリティ設定
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the application"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # 本番環境では制限すること
}

variable "ssh_allowed_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # 本番環境では制限すること
} 