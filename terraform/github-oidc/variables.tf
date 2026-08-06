variable "github_repo" {
  description = "GitHub org/repo allowed to assume this role, e.g. \"movepirot/txodds\""
  type        = string
}

variable "ecr_repository_arn" {
  type = string
}

variable "eks_cluster_name" {
  type = string
}

variable "eks_cluster_arn" {
  type = string
}
