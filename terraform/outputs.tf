output "private_subnets" {
    value = module.vpc
}

output "ecr_repository_url" {
    value = module.ecr.repository_url
}

output "eks_cluster_name" {
    value = module.eks.cluster_name
}

output "gha_role_arn" {
    value = module.github-oidc.role_arn
}