output "master_public_ip" {
  value       = aws_instance.k8s_master.public_ip
  description = "Public IP of Control Plane Master Node"
}

output "master_private_ip" {
  value       = aws_instance.k8s_master.private_ip
  description = "Private IP of Control Plane Master Node"
}

output "worker_1_private_ip" {
  value       = aws_instance.k8s_worker_1.private_ip
  description = "Private IP of Worker Node 1"
}

output "worker_2_private_ip" {
  value       = aws_instance.k8s_worker_2.private_ip
  description = "Private IP of Worker Node 2"
}