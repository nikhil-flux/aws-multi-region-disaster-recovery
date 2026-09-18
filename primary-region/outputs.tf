output "primary_alb_dns" {
  value       = aws_lb.primary_alb.dns_name
  description = "The DNS name of the Primary ALB"
}

output "primary_ec2_public_ip" {
  value       = aws_instance.primary_web_server.public_ip
  description = "The public IP of the Primary EC2 instance"
}

output "primary_s3_bucket_name" {
  value       = aws_s3_bucket.primary_backup_bucket.id
  description = "The name of the Primary S3 bucket"
}