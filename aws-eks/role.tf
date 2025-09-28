################### Role ##########################

resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_policy_attachment" "eks_cluster_policy" {
  roles      = [aws_iam_role.eks_cluster_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  name       = "eks-cluster-policy-attachment"

}

######### Role for node pool #######

resource "aws_iam_role" "eks-node-role" {
  name = "eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy_attachment" "eks-worker-node-policy" {
  name       = "eks-worker-node-attachment"
  roles      = [aws_iam_role.eks-node-role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_policy_attachment" "eks-cni-policy" {
  name       = "eks-cni-policy-attachment"
  roles      = [aws_iam_role.eks-node-role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_policy_attachment" "ec2-container-registory" {
  name       = "ec2-container-registory-attachment"
  roles      = [aws_iam_role.eks-node-role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

