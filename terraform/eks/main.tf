resource "aws_eks_cluster" "txodds" {
    name = "txodds-cluster"

    access_config {
      authentication_mode = "API"
    }

    role_arn = aws_iam_role.cluster.arn
    version  = "1.35"

    vpc_config {
      subnet_ids = tolist(var.private_subnet_list[*].id)
    }

    depends_on = [
      aws_iam_role_policy_attachment.cluster-policy,
    ]
}

resource "aws_iam_role" "cluster" {
  name = "eks-cluster-example"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "sts:AssumeRole",
            "sts:TagSession"
          ]
          Effect = "Allow"
          Principal = {
            Service = "eks.amazonaws.com"
          }
        },
      ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_eks_node_group" "txodds-workers" {
  cluster_name    = aws_eks_cluster.txodds.name
  node_group_name = "txodds-workers"
  node_role_arn   = aws_iam_role.eks-workers.arn
  subnet_ids      = tolist(var.private_subnet_list[*].id)
  instance_types = ["t3.small"]
  ami_type = "AL2023_x86_64_STANDARD"
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 2
  }
  tags = {
    name = "eks-workers"
  }
  update_config {
    max_unavailable = 1
  }
  depends_on = [
    aws_iam_role_policy_attachment.worker-policy,
    aws_iam_role_policy_attachment.cni-policy,
    aws_iam_role_policy_attachment.ecr-read-policy,
  ]
}

resource "aws_iam_role" "eks-workers" {
  name = "eks-node-group-example"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "worker-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks-workers.name
}

resource "aws_iam_role_policy_attachment" "cni-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks-workers.name
}

resource "aws_iam_role_policy_attachment" "ecr-read-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks-workers.name
}

resource "null_resource" "cleanup_k8s" {
  triggers = {
    cluster_name = aws_eks_cluster.txodds.name
    region       = "eu-west-2"
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ${self.triggers.region} || true
      helm uninstall txodds -n txodds --ignore-not-found 2>/dev/null || true
      helm uninstall aws-load-balancer-controller -n kube-system --ignore-not-found 2>/dev/null || true
      kubectl delete ingress --all -n txodds 2>/dev/null || true
      sleep 30
    EOT
  }

  depends_on = [aws_eks_cluster.txodds]
}
