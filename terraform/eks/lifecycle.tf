resource "null_resource" "update_kubeconfig" {
  triggers = {
    cluster_name = aws_eks_cluster.txodds.name
  }

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${aws_eks_cluster.txodds.name} --region ${var.region}"
  }

  depends_on = [aws_eks_access_policy_association.root]
}

resource "null_resource" "cleanup_k8s" {
  triggers = {
    cluster_name = aws_eks_cluster.txodds.name
    region       = var.region
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

      K8S_SGS=$(aws ec2 describe-security-groups --region $REGION \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query "SecurityGroups[?starts_with(GroupName,'k8s-')].GroupId" --output text)

      ALL_SGS=$(aws ec2 describe-security-groups --region $REGION \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query "SecurityGroups[*].GroupId" --output text)

      # For each k8s-* SG: revoke its own rules, then revoke references to it from all other SGs
      for SG_ID in $K8S_SGS; do
        echo "Revoking rules from SG: $SG_ID"
        INGRESS=$(aws ec2 describe-security-group-rules --region $REGION \
          --filters "Name=group-id,Values=$SG_ID" \
          --query "SecurityGroupRules[?!IsEgress].SecurityGroupRuleId" --output text)
        [ -n "$INGRESS" ] && aws ec2 revoke-security-group-ingress --group-id $SG_ID \
          --region $REGION --security-group-rule-ids $INGRESS || true
        EGRESS=$(aws ec2 describe-security-group-rules --region $REGION \
          --filters "Name=group-id,Values=$SG_ID" \
          --query "SecurityGroupRules[?IsEgress].SecurityGroupRuleId" --output text)
        [ -n "$EGRESS" ] && aws ec2 revoke-security-group-egress --group-id $SG_ID \
          --region $REGION --security-group-rule-ids $EGRESS || true

        for OTHER_SG in $ALL_SGS; do
          [ "$OTHER_SG" = "$SG_ID" ] && continue
          REFS=$(aws ec2 describe-security-group-rules --region $REGION \
            --filters "Name=group-id,Values=$OTHER_SG" \
            --query "SecurityGroupRules[?ReferencedGroupInfo.GroupId=='$SG_ID'].SecurityGroupRuleId" --output text)
          if [ -n "$REFS" ]; then
            echo "Revoking reference to $SG_ID in $OTHER_SG"
            aws ec2 revoke-security-group-ingress --group-id $OTHER_SG \
              --region $REGION --security-group-rule-ids $REFS 2>/dev/null || \
            aws ec2 revoke-security-group-egress  --group-id $OTHER_SG \
              --region $REGION --security-group-rule-ids $REFS 2>/dev/null || true
          fi
        done
      done

      # Delete ALB-created security groups (not managed by terraform)
      for SG_ID in $K8S_SGS; do
        echo "Deleting SG: $SG_ID"
        aws ec2 delete-security-group --group-id $SG_ID --region $REGION || true
      done
    EOT
  }

  depends_on = [aws_eks_cluster.txodds]
}
