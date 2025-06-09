# AWS全体構成（Strapi + Next.js）- 無料枠最適化版
# 両方のアプリケーションを単一EC2インスタンスで運用し、無料枠内に収める

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# データソース
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# 最新のAmazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC（無料枠最適化: シングルAZ、パブリックサブネットのみ）
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    CostCenter  = "free-tier"
  }
}

# インターネットゲートウェイ
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
    CostCenter  = "free-tier"
  }
}

# パブリックサブネット（シングルAZ）
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet"
    Environment = var.environment
    CostCenter  = "free-tier"
  }
}

# プライベートサブネット（RDS用、シングルAZ）
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2)
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "${var.project_name}-private-subnet"
    Environment = var.environment
    CostCenter  = "free-tier"
  }
}

# 追加のプライベートサブネット（RDS要件: 最低2つのAZ）
resource "aws_subnet" "private_secondary" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 3)
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name        = "${var.project_name}-private-subnet-secondary"
    Environment = var.environment
    CostCenter  = "free-tier"
  }
}

# ルートテーブル（パブリック）
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
    CostCenter  = "free-tier"
  }
}

# ルートテーブルアソシエーション
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# セキュリティグループ（EC2用）
resource "aws_security_group" "ec2" {
  name_prefix = "${var.project_name}-ec2-"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidr_blocks
  }

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Strapi
  ingress {
    description = "Strapi"
    from_port   = var.strapi_port
    to_port     = var.strapi_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Next.js
  ingress {
    description = "Next.js"
    from_port   = var.nextjs_port
    to_port     = var.nextjs_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-ec2-sg"
    Environment = var.environment
    CostCenter  = "free-tier"
  }
}

# セキュリティグループ（RDS用）
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  tags = {
    Name        = "${var.project_name}-rds-sg"
    Environment = var.environment
    CostCenter  = "free-tier"
  }
}

# RDS サブネットグループ
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private.id, aws_subnet.private_secondary.id]

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
    CostCenter  = "free-tier"
  }
}

# RDS インスタンス（無料枠: db.t3.micro）
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-postgres"

  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.db_instance_class

  allocated_storage     = 20  # 無料枠: 20GB
  max_allocated_storage = 20  # 自動スケーリング無効

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = var.backup_retention_days
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = true
  deletion_protection = false

  # 無料枠最適化
  monitoring_interval = 0  # 詳細監視無効
  performance_insights_enabled = false

  tags = {
    Name        = "${var.project_name}-postgres"
    Environment = var.environment
    CostCenter  = "free-tier"
  }
}

# S3バケット（アセット用）
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "assets" {
  bucket = "${var.project_name}-assets-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "${var.project_name}-assets"
    Environment = var.environment
    CostCenter  = "free-tier"
  }
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration {
    status = "Disabled"  # 無料枠最適化
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "assets" {
  bucket = aws_s3_bucket.assets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.assets.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.assets]
}

# IAMロール（EC2用）
resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ec2-role"
    Environment = var.environment
    CostCenter  = "free-tier"
  }
}

# IAMポリシー（S3アクセス用）
resource "aws_iam_role_policy" "s3_access" {
  name = "${var.project_name}-s3-access"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.assets.arn,
          "${aws_s3_bucket.assets.arn}/*"
        ]
      }
    ]
  })
}

# IAMポリシー（CloudWatch Logs用）
resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "${var.project_name}-cloudwatch-logs"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

# IAMインスタンスプロファイル
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = {
    Name        = "${var.project_name}-ec2-profile"
    Environment = var.environment
    CostCenter  = "free-tier"
  }
}

# CloudWatch ログ グループ
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ec2/${var.project_name}"
  retention_in_days = 7  # 無料枠最適化

  tags = {
    Name        = "${var.project_name}-logs"
    Environment = var.environment
    CostCenter  = "free-tier"
  }
}

# ユーザーデータスクリプト
locals {
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    project_name    = var.project_name
    db_host        = aws_db_instance.main.endpoint
    db_name        = var.db_name
    db_username    = var.db_username
    db_password    = var.db_password
    s3_bucket      = aws_s3_bucket.assets.bucket
    aws_region     = var.aws_region
    strapi_port    = var.strapi_port
    nextjs_port    = var.nextjs_port
    log_group      = aws_cloudwatch_log_group.app_logs.name
  }))
}

# EC2インスタンス（無料枠: t3.micro）
resource "aws_instance" "main" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.ec2_instance_type
  key_name              = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.ec2.id]
  subnet_id             = aws_subnet.public.id
  iam_instance_profile  = aws_iam_instance_profile.ec2.name

  user_data = local.user_data

  # 無料枠最適化
  monitoring = var.enable_detailed_monitoring

  root_block_device {
    volume_type = "gp3"
    volume_size = 8  # 無料枠: 30GB利用可能だが最小構成
    encrypted   = true
  }

  tags = {
    Name        = "${var.project_name}-main"
    Environment = var.environment
    CostCenter  = "free-tier"
  }

  depends_on = [
    aws_db_instance.main,
    aws_s3_bucket.assets,
    aws_cloudwatch_log_group.app_logs
  ]
}

# Elastic IP（オプション）
resource "aws_eip" "main" {
  instance = aws_instance.main.id
  domain   = "vpc"

  tags = {
    Name        = "${var.project_name}-eip"
    Environment = var.environment
    CostCenter  = "free-tier"
  }

  depends_on = [aws_internet_gateway.main]
} 