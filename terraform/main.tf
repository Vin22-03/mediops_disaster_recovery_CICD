############################################################
# MediOps – Phase 3: VPC + EKS + ALB Controller + S3 (single file)
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

  # Optional: uncomment and set your remote backend for team/state safety
  # backend "s3" {
  #   bucket = "mediops-tfstate-bucket"
  #   key    = "eks/main.tfstate"
  #   region = "us-east-1"
  #   dynamodb_table = "mediops-tf-locks"
  #   encrypt = true
  # }
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
# Networking (VPC)
########################
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(local.tags, { Name = "${local.name}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${local.name}-igw" })
}

# Public Subnets
resource "aws_subnet" "public" {
  for_each = toset(range(0, length(var.public_cidrs)))
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_cidrs[each.value]
  availability_zone       = var.azs[each.value]
  map_public_ip_on_launch = true
  tags = merge(local.tags, {
    Name                     = "${local.name}-public-${each.value}"
    "kubernetes.io/role/elb" = "1"
  })
}

# Private Subnets
resource "aws_subnet" "private" {
  for_each = toset(range(0, length(var.private_cidrs)))
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_cidrs[each.value]
  availability_zone = var.azs[each.value]
  tags = merge(local.tags, {
    Name                              = "${local.name}-private-${each.value}"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(local.tags, { Name = "${local.name}-nat-eip" })
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = values(aws_subnet.public)[0].id
  tags          = merge(local.tags, { Name = "${local.name}-nat" })
  depends_on    = [aws_internet_gateway.igw]
}

# Route tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${local.name}-public-rt" })
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
  tags   = merge(local.tags, { Name = "${local.name}-private-rt" })
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
# EKS – Cluster & Nodes
########################

# Cluster role
resource "aws_iam_role" "eks_cluster" {
  name = "${local.name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
  tags = local.tags
}
data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["eks.amazonaws.com"] }
  }
}
resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSVPCCNI" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_security_group" "eks_cluster" {
  name        = "${local.name}-cluster-sg"
  description = "Cluster security group"
  vpc_id      = aws_vpc.this.id
  tags        = merge(local.tags, { Name = "${local.name}-cluster-sg" })
}

resource "aws_eks_cluster" "this" {
  name     = local.name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.eks_version

  vpc_config {
    subnet_ids              = concat([for s in aws_subnet.public : s.id], [for s in aws_subnet.private : s.id])
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = local.tags

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy
  ]
}

# Node group role
resource "aws_iam_role" "eks_node" {
  name = "${local.name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
  tags = local.tags
}
data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["ec2.amazonaws.com"] }
  }
}
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${local.name}-nodes"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = [for s in aws_subnet.private : s.id] # nodes in private subnets
  instance_types  = [var.node_type]
  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }
  tags = local.tags

  depends_on = [
    aws_eks_cluster.this,
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy
  ]
}

########################
# EKS Auth & Providers
########################
data "aws_eks_cluster" "auth" {
  name = aws_eks_cluster.this.name
}
data "aws_eks_cluster_auth" "auth" {
  name = aws_eks_cluster.this.name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.auth.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.auth.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.auth.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.auth.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.auth.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.auth.token
  }
}

########################
# IRSA + ALB Controller
########################
data "aws_iam_openid_connect_provider" "oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# Role for AWS Load Balancer Controller (use AWS managed policy)
resource "aws_iam_role" "alb_sa_role" {
  name = "${local.name}-alb-controller-role"
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
  tags = local.tags
}
resource "aws_iam_role_policy_attachment" "alb_policy" {
  role       = aws_iam_role.alb_sa_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancerControllerPolicy"
}

# Install ALB Controller via Helm
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.7.2"

  values = [
    yamlencode({
      clusterName = aws_eks_cluster.this.name
      region      = var.region
      vpcId       = aws_vpc.this.id
      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.alb_sa_role.arn
        }
      }
    })
  ]

  depends_on = [aws_eks_node_group.default]
}

########################
# S3 – DR Artifacts / Backups
########################
resource "aws_s3_bucket" "dr_bucket" {
  bucket = "${var.project}-dr-artifacts-${random_id.rand.hex}"
  tags   = merge(local.tags, { Name = "${local.name}-dr-bucket" })
}
resource "random_id" "rand" { byte_length = 3 }

resource "aws_s3_bucket_versioning" "ver" {
  bucket = aws_s3_bucket.dr_bucket.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  bucket = aws_s3_bucket.dr_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
########################
# SNS Topic for MediOps alerts
########################
resource "aws_sns_topic" "alerts" {
  name = "mediops-alerts"
  tags = local.tags
}
########################
#Email subscription (replace with your email) 
########################
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "vinay.venvin@gmail.com"
}

########################
# Outputs
########################
output "cluster_name" {
  value = aws_eks_cluster.this.name
}
output "region" {
  value = var.region
}
output "vpc_id" {
  value = aws_vpc.this.id
}
output "private_subnets" {
  value = [for s in aws_subnet.private : s.id]
}
output "public_subnets" {
  value = [for s in aws_subnet.public : s.id]
}
output "dr_bucket_name" {
  value = aws_s3_bucket.dr_bucket.bucket
}
output "sns_alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
########################
# SNS Topic for Alerts
########################
resource "aws_sns_topic" "alerts" {
  name = "mediops-alerts"
  tags = local.tags
}

# Email subscription (you will need to confirm via AWS email link)
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "vincloudops@gmail.com"
}

output "sns_alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

########################
# Jenkins IAM Role for SNS Publish
########################
# (If you are already using an IAM user/role in Jenkins, attach this policy)

resource "aws_iam_policy" "sns_publish_policy" {
  name        = "${local.name}-sns-publish-policy"
  description = "Allow Jenkins to publish alerts to MediOps SNS topic"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "sns:Publish"
        ],
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# Attach policy to your Jenkins IAM role
resource "aws_iam_role_policy_attachment" "jenkins_sns" {
  role       = aws_iam_role.eks_cluster.name # replace if Jenkins uses a different IAM role/user
  policy_arn = aws_iam_policy.sns_publish_policy.arn
}
