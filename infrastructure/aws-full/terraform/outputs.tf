# AWS全体構成 - 出力値定義
# デプロイ後のアクセス情報と重要な設定値を出力

# ネットワーク情報
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = [aws_subnet.private.id, aws_subnet.private_secondary.id]
}

# EC2インスタンス情報
output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.main.id
}

output "ec2_public_ip" {
  description = "EC2 instance public IP"
  value       = aws_eip.main.public_ip
}

output "ec2_private_ip" {
  description = "EC2 instance private IP"
  value       = aws_instance.main.private_ip
}

# アプリケーションアクセス情報
output "web_app_url" {
  description = "Web application URL"
  value       = "http://${aws_eip.main.public_ip}"
}

output "strapi_admin_url" {
  description = "Strapi admin panel URL"
  value       = "http://${aws_eip.main.public_ip}/admin"
}

output "strapi_api_url" {
  description = "Strapi API URL"
  value       = "http://${aws_eip.main.public_ip}/api"
}

# データベース情報
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = false
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "database_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

# S3情報
output "s3_bucket_name" {
  description = "S3 bucket name for assets"
  value       = aws_s3_bucket.assets.bucket
}

output "s3_bucket_domain" {
  description = "S3 bucket domain name"
  value       = aws_s3_bucket.assets.bucket_domain_name
}

# セキュリティグループ情報
output "ec2_security_group_id" {
  description = "EC2 security group ID"
  value       = aws_security_group.ec2.id
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

# IAM情報
output "ec2_iam_role_arn" {
  description = "EC2 IAM role ARN"
  value       = aws_iam_role.ec2.arn
}

output "ec2_instance_profile_name" {
  description = "EC2 instance profile name"
  value       = aws_iam_instance_profile.ec2.name
}

# CloudWatch情報
output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.app_logs.name
}

# SSH接続情報
output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_eip.main.public_ip}"
}

# 無料枠使用量情報
output "free_tier_resources" {
  description = "Free tier resources being used"
  value = {
    ec2_instance_type    = var.ec2_instance_type
    rds_instance_class   = var.db_instance_class
    rds_storage_gb      = aws_db_instance.main.allocated_storage
    ebs_volume_size_gb  = aws_instance.main.root_block_device[0].volume_size
    cloudwatch_logs_retention_days = aws_cloudwatch_log_group.app_logs.retention_in_days
  }
}

# 重要な設定情報
output "important_notes" {
  description = "Important configuration notes"
  value = {
    strapi_port = var.strapi_port
    nextjs_port = var.nextjs_port
    nginx_port  = 80
    ssh_port    = 22
    postgres_port = 5432
    region      = var.aws_region
    environment = var.environment
  }
}

# コスト最適化情報
output "cost_optimization_notes" {
  description = "Cost optimization recommendations"
  value = [
    "EC2 instance: ${var.ec2_instance_type} (Free tier: 750 hours/month)",
    "RDS instance: ${var.db_instance_class} (Free tier: 750 hours/month)",
    "EBS storage: ${aws_instance.main.root_block_device[0].volume_size}GB (Free tier: 30GB/month)",
    "RDS storage: ${aws_db_instance.main.allocated_storage}GB (Free tier: 20GB)",
    "S3 storage: Monitor usage (Free tier: 5GB)",
    "CloudWatch logs: ${aws_cloudwatch_log_group.app_logs.retention_in_days} days retention (Free tier: 5GB/month)",
    "Elastic IP: No charge while attached to running instance",
    "Data transfer: Monitor outbound data (Free tier: 1GB/month)"
  ]
} 