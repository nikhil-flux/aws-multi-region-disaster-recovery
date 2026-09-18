output "secondary_alb_dns" {
  value       = aws_lb.secondary_alb.dns_name
  description = "The DNS name of the Secondary ALB"
}

output "secondary_ec2_public_ip" {
  value       = aws_instance.secondary_web_server.public_ip
  description = "The public IP of the Secondary EC2 instance"
}

output "secondary_s3_bucket_name" {
  value       = aws_s3_bucket.secondary_backup_bucket.id
  description = "The name of the Secondary S3 bucket"
}