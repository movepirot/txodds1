data "aws_caller_identity" "current" {}

resource "aws_eks_access_entry" "root" {
  cluster_name  = aws_eks_cluster.txodds.name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
}

resource "aws_eks_access_policy_association" "root" {
  cluster_name  = aws_eks_cluster.txodds.name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
  depends_on = [aws_eks_access_entry.root]
}
