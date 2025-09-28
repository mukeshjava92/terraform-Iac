resource "aws_eks_cluster" "eks-cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  vpc_config {
    subnet_ids              = aws_subnet.eks-subnet[*].id
    endpoint_private_access = false
    endpoint_public_access  = true
  }
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }
  version = "1.29"
  tags = {
    Name        = var.cluster_name
    Environment = "Dev"
  }
}
resource "aws_iam_instance_profile" "eks-node-profile" {
  role = aws_iam_role.eks-node-role.name
  name = "eks-node-profile"
}

data "aws_ssm_parameter" "eks_ami" {
  name = "/aws/service/eks/optimized-ami/1.29/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "eks-node-launch" {
  image_id      = data.aws_ssm_parameter.eks_ami.value
  instance_type = "t3.medium"
  name_prefix   = "eks-node-"
  user_data = base64encode(<<-EOF
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="
--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
#!/bin/bash
/etc/eks/bootstrap.sh eks-cluster
--==MYBOUNDARY==--\
  EOF
  )
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                                        = "eks-nodepool"
      type                                        = "Dev"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  }
}


resource "aws_eks_node_group" "node-pool1" {
  node_group_name = "nodegroup"
  cluster_name    = aws_eks_cluster.eks-cluster.name
  subnet_ids      = aws_subnet.eks-subnet[*].id
  node_role_arn   = aws_iam_role.eks-node-role.arn
  launch_template {
    id      = aws_launch_template.eks-node-launch.id
    version = "$Latest"
  }
  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 0
  }
  update_config {
    max_unavailable = 1
  }
  tags = {
    Name = "nodegroup"
  }

}

locals {
  eks_addons = {
    "vpc-cni" = {
      resolve_conflicts = "OVERWRITE"
    }
    "kube-proxy" = {
      resolve_conflicts = "OVERWRITE"
    }
  }
}

resource "aws_eks_addon" "eksadd" {
  for_each                    = local.eks_addons
  cluster_name                = aws_eks_cluster.eks-cluster.name
  addon_name                  = each.key
  resolve_conflicts_on_update = each.value.resolve_conflicts

}

