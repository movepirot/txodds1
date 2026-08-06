module "vpc" {
    source = "./vpc"
}

module "eks" {
    source = "./eks"
    private_subnet_list = module.vpc.private_subnets
}

module "ecr" {
    source = "./ecr"
}

module "github-oidc" {
    source              = "./github-oidc"
    github_repo         = "movepirot/txodds1"
    ecr_repository_arn  = module.ecr.repository_arn
    eks_cluster_name    = module.eks.cluster_name
    eks_cluster_arn     = module.eks.cluster_arn
}

