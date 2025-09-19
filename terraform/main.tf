############################################################
# main.tf – MediOps Disaster Recovery Infra (Clean Setup)
# Author: VinCloudOps | Date: 19 Sept 2025
# Region: us-east-1 | One NAT | With DR-S3 + EKS + ALB
############################################################

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
}
}
########################
# 🔧 Input Variables
########################
variable "project"        { default = "mediops" }
variable "region"         { default = "us-east-1" }
variable "vpc_cidr"       { default = "10.0.0.0/16" }
variable "azs"            { default = ["us-east-1a", "us-east-1b"] }
variable "public_subnets" { default = ["10.0.0.0/24", "10.0.1.0/24"] }
variable "private_subnets" { default = ["10.0.10.0/24", "10.0.11.0/24"] }
variable "eks_version"    { default = "1.30" }
variable "node_type"      { default = "t3.medium" }
variable "desired_size"   { default = 2 }
variable "min_size"       { default = 1 }
variable "max_size"       { default = 3 }
variable "kubeconfig_path" { default = "/var/jenkins_home/workspace/MediOps-Infra_main/kubeconfig" }

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
# ✅ Fix: Tell Terraform where kubeconfig is
provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

########################
# 🌐 VPC + Subnets + NAT + Routing
########################
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.tags, { Name = "${local.name}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = local.tags
}

resource "aws_subnet" "public" {
  for_each = { for idx, cidr in var.public_subnets : cidr => idx }
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.key
  availability_zone       = var.azs[each.value]
  map_public_ip_on_launch = true
  tags = merge(local.tags, {
    Name = "${local.name}-public-${each.value}"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private" {
  for_each = { for idx, cidr in var.private_subnets : cidr => idx }
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.key
  availability_zone = var.azs[each.value]
  tags = merge(local.tags, {
    Name = "${local.name}-private-${each.value}"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = local.tags
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = values(aws_subnet.public)[0].id
  depends_on    = [aws_internet_gateway.igw]
  tags          = local.tags
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = local.tags
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
  vpc_id = aws_vpc.main.id
  tags   = local.tags
}
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}
resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

########################
# ☸️ EKS Cluster + Node Group
########################
resource "aws_iam_role" "eks_cluster_role" {
  name               = "${local.name}-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_security_group" "eks_sg" {
  vpc_id = aws_vpc.main.id
  tags   = local.tags
}

resource "aws_eks_cluster" "main" {
  name     = local.name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.eks_version

  vpc_config {
    subnet_ids         = concat([for s in aws_subnet.public : s.id], [for s in aws_subnet.private : s.id])
    security_group_ids = [aws_security_group.eks_sg.id]
  }

  enabled_cluster_log_types = ["api", "audit"]
  tags = local.tags
}

resource "aws_iam_role" "eks_node_role" {
  name               = "${local.name}-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "ecr_read_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.name}-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [for s in aws_subnet.private : s.id]
  instance_types  = [var.node_type]

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  tags = local.tags
}

########################
# 🔐 OIDC + ALB Controller via Helm
########################
data "tls_certificate" "eks_oidc_thumb" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc" {
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc_thumb.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "alb_sa_role" {
  name = "${local.name}-alb-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = aws_iam_openid_connect_provider.oidc.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "alb_controller_policy" {
  name        = "${local.name}-alb-policy"
  description = "Policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/alb-policy.json")  # ⛳ Add this file in same folder
}

resource "aws_iam_role_policy_attachment" "alb_policy" {
  role       = aws_iam_role.alb_sa_role.name
  policy_arn = aws_iam_policy.alb_controller_policy.arn
}
provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.main.name
}

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.2"
  depends_on = [aws_eks_node_group.node_group]

  values = [yamlencode({
    clusterName = aws_eks_cluster.main.name
    region      = var.region
    vpcId       = aws_vpc.main.id
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
# 💾 S3 Bucket for DR
########################
resource "random_id" "rand" {
  byte_length = 3
}

resource "aws_s3_bucket" "dr_bucket" {
  bucket = "${var.project}-dr-artifacts-${random_id.rand.hex}"
  tags   = local.tags
}

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
# 🔔 SNS Topic + Email Subscription
########################
resource "aws_sns_topic" "alerts" {
  name = "${var.project}-alerts"
  tags = local.tags
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "vinay.venvin@gmail.com" # ⛳ Replace this with your real email
}

########################
# 🧾 Outputs
########################
output "eks_cluster_name"     { value = aws_eks_cluster.main.name }
output "region"               { value = var.region }
output "vpc_id"               { value = aws_vpc.main.id }
output "public_subnets"       { value = [for s in aws_subnet.public : s.id] }
output "private_subnets"      { value = [for s in aws_subnet.private : s.id] }
output "alb_role_arn"         { value = aws_iam_role.alb_sa_role.arn }
output "sns_topic_arn"        { value = aws_sns_topic.alerts.arn }
output "dr_bucket_name"       { value = aws_s3_bucket.dr_bucket.id }
