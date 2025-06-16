terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  assume_role {
    role_arn     = var.assume_role_arn
    session_name = "terraform-deploy-cluster"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = [
    "subnet-0133f68aba21bd5bd",
    "subnet-0d75b867bb6a2f273"
  ]

  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      instance_types = ["m5.xlarge"]
      min_size       = 1
      max_size       = 2
      desired_size   = 1
      cluster_enabled_log_types = []
      iam_role_additional_policies = {
        ecr_access = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      }
    }
    # gpu = {
    #   instance_types = ["p3.2xlarge"]
    #   min_size       = 0
    #   max_size       = 2
    #   desired_size   = 1
    #   labels = {
    #     "node-type" = "gpu"
    #   }
    # }
  }
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
  
}

resource "aws_eks_access_entry" "ec2_access" {
  cluster_name  = module.eks.cluster_name
  principal_arn = var.assume_role_arn
  type          = "STANDARD"
}

# Associate that access entry with an access policy (e.g., ClusterAdmin)
resource "aws_eks_access_policy_association" "ec2_access_policy" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_eks_access_entry.ec2_access.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
}

resource "aws_security_group_rule" "allow_ec2_sg_1_to_eks_api" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = "sg-00e33cc1496839814"  # EC2 SG 1
  description              = "Allow EC2 instance SG 1 to access EKS API"
}

resource "aws_security_group_rule" "allow_ec2_sg_2_to_eks_api" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = "sg-0520c86bd14146cfc"  # EC2 SG 2
  description              = "Allow EC2 instance SG 2 to access EKS API"
}
