module "vpc" {
    source       = "./vpc"
    cluster_name = var.cluster_name
}

module "eks" {
    source              = "./eks"
    private_subnet_list = module.vpc.private_subnets
    vpc_id              = module.vpc.vpc_id
    cluster_name        = var.cluster_name
    region              = var.region
}

module "ecr" {
    source   = "./ecr"
    app_name = var.app_name
}

module "github-oidc" {
    source             = "./github-oidc"
    github_repo        = var.github_repo
    ecr_repository_arn = module.ecr.repository_arn
    eks_cluster_name   = module.eks.cluster_name
    eks_cluster_arn    = module.eks.cluster_arn
}

