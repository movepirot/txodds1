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

data "aws_caller_identity" "current" {}

resource "null_resource" "update_kubeconfig" {
  triggers = {
    cluster_name = aws_eks_cluster.txodds.name
  }

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${aws_eks_cluster.txodds.name} --region eu-west-2"
  }

  depends_on = [aws_eks_access_policy_association.root]
}

resource "null_resource" "cleanup_k8s" {
  triggers = {
    cluster_name = aws_eks_cluster.txodds.name
    region       = "eu-west-2"
    vpc_id       = var.vpc_id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      REGION=${self.triggers.region}
      VPC_ID=${self.triggers.vpc_id}

      # Delete all ALBs in the VPC
      for ALB_ARN in $(aws elbv2 describe-load-balancers --region $REGION \
        --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text); do
        echo "Deleting ALB: $ALB_ARN"
        aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN --region $REGION
      done

      # Wait for ALBs and their ENIs to be released
      sleep 30

      # Delete ALB-created security groups (not managed by terraform)
      for SG_ID in $(aws ec2 describe-security-groups --region $REGION \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query "SecurityGroups[?starts_with(GroupName,'k8s-')].GroupId" --output text); do
        echo "Deleting SG: $SG_ID"
        aws ec2 delete-security-group --group-id $SG_ID --region $REGION || true
      done
    EOT
  }

  depends_on = [aws_eks_cluster.txodds]
}
