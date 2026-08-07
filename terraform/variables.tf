variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "cluster_name" {
  type    = string
  default = "txodds-cluster"
}

variable "app_name" {
  type    = string
  default = "txodds"
}

variable "github_repo" {
  type    = string
  default = "movepirot/txodds1"
}
