# ------------------------------------------------------------------------------ 
# LOCALS
# ------------------------------------------------------------------------------

locals {
  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    cluster-name    = var.cluster_name
    GithubRepo = "eks-infra-live"
  }
}

# ------------------------------------------------------------------------------ 
# EKS
# ------------------------------------------------------------------------------

module "eks" {
  source = "terraform-aws-modules/eks/aws"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Grants Terraform's identity administrative permissions for deploying additional resources (e.g. Karpenter)
  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = true

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  # Use the variable for instance types
  eks_managed_node_groups = {
    karpenter = {
      ami_type       = "BOTTLEROCKET_x86_64"
      instance_types = var.instance_types

      min_size     = 2
      max_size     = 3
      desired_size = 2

      labels = {
        "karpenter.sh/controller" = "true"
      }
    }
  }

  node_security_group_tags = merge(local.tags, {
    "karpenter.sh/discovery" = var.cluster_name
  })

  tags = local.tags
}

# ------------------------------------------------------------------------------ 
# HELM PROVIDER
# ------------------------------------------------------------------------------

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# ------------------------------------------------------------------------------ 
# KARPENTER MODULE
# ------------------------------------------------------------------------------

module "karpenter" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git//modules/karpenter?ref=v20.33.1"

  cluster_name          = module.eks.cluster_name
  enable_v1_permissions = true

  # The name must match the role name passed to the EC2NodeClass
  node_iam_role_use_name_prefix   = false
  node_iam_role_name              = var.cluster_name
  create_pod_identity_association = true

  # Attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

module "karpenter_disabled" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git//modules/karpenter?ref=v20.33.1"
  create = false
}

resource "helm_release" "karpenter" {
  namespace           = "kube-system"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.1.1"
  wait                = false

  values = [
    <<-EOT
    nodeSelector:
      karpenter.sh/controller: 'true'
    dnsPolicy: Default
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    webhook:
      enabled: false
    EOT
  ]
}

# ------------------------------------------------------------------------------
# EIP (NAT Gateway)
# ------------------------------------------------------------------------------

resource "aws_eip" "nat" {
  count = 1
  vpc   = true
}

# ------------------------------------------------------------------------------
# VPC
# ------------------------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.cluster_name
  cidr = "10.0.0.0/16"

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]

  enable_nat_gateway    = true
  single_nat_gateway    = true
  reuse_nat_ips         = true
  external_nat_ip_ids   = aws_eip.nat[*].id
  map_public_ip_on_launch = true

  create_private_nat_gateway_route = true
  create_igw                       = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    format("kubernetes.io/cluster/%s", var.cluster_name) = "owned"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    format("kubernetes.io/cluster/%s", var.cluster_name) = "owned"
    "karpenter.sh/discovery"          = var.cluster_name
  }

  tags = {
    cluster-name = var.cluster_name
    GithubRepo   = "eks-infra-live"
  }
}
