provider "aws" {
  region     = "us-east-1"
}


resource "aws_vpc" "eks-vpc" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name         = "eks-vpc"
    Cluster-Name = "eks-cluster"

  }
}

resource "aws_subnet" "eks-subnet" {
  vpc_id                  = aws_vpc.eks-vpc.id
  count                   = 2
  cidr_block              = cidrsubnet(aws_vpc.eks-vpc.cidr_block, 8, count.index)
  availability_zone       = element(["us-east-1a", "us-east-1b"], count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "eks-subnet-${count.index}"
    type = "public"
  }
}

resource "aws_internet_gateway" "eks-igw" {
  vpc_id = aws_vpc.eks-vpc.id
  tags = {
    Name = "eks-igw"
  }
}

resource "aws_route_table" "eks-route" {
  vpc_id = aws_vpc.eks-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks-igw.id
  }
  tags = {
    Name = "eks-public-rt"
  }
}

resource "aws_route_table_association" "rt-ass" {
  subnet_id      = aws_subnet.eks-subnet[count.index].id
  route_table_id = aws_route_table.eks-route.id
  count          = 2
}

