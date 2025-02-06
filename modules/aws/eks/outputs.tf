output "cluster_endpoint" {
  description = "The API endpoint for the EKS cluster."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "The base64-encoded certificate authority data for the EKS cluster."
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "A list of public subnet IDs."
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "A list of private subnet IDs."
  value       = module.vpc.private_subnets
}

output "intra_subnets" {
  description = "A list of intra subnet IDs (for control plane or internal use)."
  value       = module.vpc.intra_subnets
}