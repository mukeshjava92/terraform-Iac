data "aws_eks_cluster" "eksname" {
  name = aws_eks_cluster.eks-cluster.name
}

data "aws_eks_cluster_auth" "eks-auth" {
  name = aws_eks_cluster.eks-cluster.name

}

resource "aws_iam_openid_connect_provider" "eks-oid" {
  url            = data.aws_eks_cluster.eksname.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "irsa_role" {
  name = "irsa-s3-access-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks-oid.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(data.aws_eks_cluster.eksname.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:default:s3-reader"
        }
      }
    }]
  })
}
resource "aws_iam_policy_attachment" "oidc-policy" {
  roles  = [aws_iam_role.irsa_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  name       = "oidc-s3-polic-attachment"

}
