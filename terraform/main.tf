############################################################
# MediOps – Phase 3: VPC + EKS + ALB Controller + S3 + SNS
# Region: us-east-1 | Cost-aware (1 NAT) | Prod-ready tags
############################################################

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }
}

########################
# Inputs (with defaults)
########################
variable "project"        { default = "mediops" }
variable "region"         { default = "us-east-1" }
variable "vpc_cidr"       { default = "10.0.0.0/16" }
variable "azs"            { default = ["us-east-1a", "us-east-1b"] }
variable "public_cidrs"   { default = ["10.0.0.0/24", "10.0.1.0/24"] }
variable "private_cidrs"  { default = ["10.0.10.0/24", "10.0.11.0/24"] }
variable "eks_version"    { default = "1.30" }
variable "node_type"      { default = "t3.medium" }
variable "desired_size"   { default = 2 }
variable "min_size"       { default = 1 }
variable "max_size"       { default = 3 }

locals {
  name = "${var.project}-eks"
  tags = {
    Project     = var.project
    Owner       = "VinCloudOps"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

provider "aws" {
  region = var.region
}

########################
# Networking (VPC + Subnets + NAT)
########################
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(local.tags, { Name = "${local.name}-vpc" })
}

# Public Subnets
resource "aws_subnet" "public" {
  for_each = toset(var.public_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = element(var.azs, index(var.public_cidrs, each.value))
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name                     = "${local.name}-public-${index(var.public_cidrs, each.value)}"
    "kubernetes.io/role/elb" = "1"
  })
}

# Private Subnets
resource "aws_subnet" "private" {
  for_each = toset(var.private_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = element(var.azs, index(var.private_cidrs, each.value))

  tags = merge(local.tags, {
    Name                              = "${local.name}-private-${index(var.private_cidrs, each.value)}"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = values(aws_subnet.public)[0].id
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
}
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}
resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
}
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ngw.id
}
resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

########################
# EKS Cluster + Nodes
########################
data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "${local.name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_security_group" "eks_cluster" {
  vpc_id = aws_vpc.this.id
  name   = "${local.name}-cluster-sg"
}

resource "aws_eks_cluster" "this" {
  name     = local.name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.eks_version

  vpc_config {
    subnet_ids         = concat([for s in aws_subnet.public : s.id], [for s in aws_subnet.private : s.id])
    security_group_ids = [aws_security_group.eks_cluster.id]
  }

  enabled_cluster_log_types = ["api", "audit"]
}

# Node Role
data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node" {
  name               = "${local.name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${local.name}-nodes"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = [for s in aws_subnet.private : s.id]
  instance_types  = [var.node_type]

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }
}

########################
# EKS OIDC Provider for IRSA
########################
data "aws_eks_cluster" "eks" {
  name = aws_eks_cluster.this.name
}

data "aws_eks_cluster_auth" "eks" {
  name = aws_eks_cluster.this.name
}

data "aws_iam_openid_connect_provider" "oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}


########################
# ALB Controller
########################
resource "aws_iam_role" "alb_sa_role" {
  name = "${local.name}-alb-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.oidc.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "alb_policy" {
  role       = aws_iam_role.alb_sa_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancerControllerPolicy"
}

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.7.2"

  values = [yamlencode({
    clusterName = aws_eks_cluster.this.name
    region      = var.region
    vpcId       = aws_vpc.this.id
    serviceAccount = {
      create      = true
      name        = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.alb_sa_role.arn
      }
    }
  })]
}

########################
# S3 Bucket for DR
########################
resource "random_id" "rand" { byte_length = 3 }

resource "aws_s3_bucket" "dr_bucket" {
  bucket = "${var.project}-dr-artifacts-${random_id.rand.hex}"
}

resource "aws_s3_bucket_versioning" "ver" {
  bucket = aws_s3_bucket.dr_bucket.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  bucket = aws_s3_bucket.dr_bucket.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

########################
# SNS Topic + Jenkins Permissions
########################
resource "aws_sns_topic" "alerts" {
  name = "mediops-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "vincloudops@gmail.com"
}

resource "aws_iam_policy" "sns_publish" {
  name        = "${local.name}-sns-publish"
  description = "Allow Jenkins to publish to MediOps SNS"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["sns:Publish"],
      Resource = aws_sns_topic.alerts.arn
    }]
  })
}

# ⚠️ Replace with Jenkins IAM role/user if different
resource "aws_iam_role_policy_attachment" "jenkins_sns" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = aws_iam_policy.sns_publish.arn
}

########################
# Outputs
########################
output "cluster_name"          { value = aws_eks_cluster.this.name }
output "region"                { value = var.region }
output "vpc_id"                { value = aws_vpc.this.id }
output "private_subnets"       { value = [for s in aws_subnet.private : s.id] }
output "public_subnets"        { value = [for s in aws_subnet.public : s.id] }
output "dr_bucket_name"        { value = aws_s3_bucket.dr_bucket.bucket }
output "sns_alerts_topic_arn"  { value = aws_sns_topic.alerts.arn }

