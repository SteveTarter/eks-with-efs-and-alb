resource "aws_security_group" "efs" {
  name        = "efs-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "efs-sg"
  }
}

resource "kubectl_manifest" "efs_service_account" {
  yaml_body = <<-EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: efs-app-service-account
  namespace: default
EOF
}

resource "aws_efs_access_point" "gis_tarterware_efs" {
  file_system_id = var.gis_tarterware_efs_id

  root_directory {
    path = "/gis-tarterware-files-efs"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name = "gis-tarterware-files-efs"
  }
}

resource "aws_efs_mount_target" "gis_tarterware_efs" {
  for_each = toset(module.vpc.private_subnets)

  file_system_id = var.gis_tarterware_efs_arn
  subnet_id      = each.value

  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_access_point" "mile_weaver_files_efs" {
  file_system_id = var.mile_weaver_files_efs_id

  root_directory {
    path = "/mile-weaver-files-efs"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name = "mile-weaver-files-efs"
  }
}

resource "aws_efs_mount_target" "mile_weaver_files_efs" {
  for_each = toset(module.vpc.private_subnets)

  file_system_id = var.mile_weaver_files_efs_arn
  subnet_id      = each.value

  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_access_point" "mile_weaver_mongodb_efs" {
  file_system_id = var.mile_weaver_mongodb_efs_id

  root_directory {
    path = "/mile-weaver-mongodb-efs"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name = "mile-weaver-mongodb-efs"
  }
}

resource "aws_efs_mount_target" "mile_weaver_mongodb_efs" {
  for_each = toset(module.vpc.private_subnets)

  file_system_id = var.mile_weaver_mongodb_efs_arn
  subnet_id      = each.value

  security_groups = [aws_security_group.efs.id]
}

data "aws_iam_policy_document" "efs_access" {
  statement {
    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
      "elasticfilesystem:DescribeMountTargets"
    ]

    resources = [
      var.gis_tarterware_efs_arn,
      aws_efs_access_point.gis_tarterware_efs.arn,
      var.mile_weaver_files_efs_arn,
      aws_efs_access_point.mile_weaver_files_efs.arn,
      var.mile_weaver_mongodb_efs_arn,
      aws_efs_access_point.mile_weaver_mongodb_efs.arn
    ]
  }
}

resource "aws_iam_policy" "efs_access_policy" {
  name   = "efs-access-policy"
  policy = data.aws_iam_policy_document.efs_access.json
}

module "efs_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.3.1"

  role_name = "efs-access-role"

  oidc_providers = {
    eks_provider = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:efs-app-service-account"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "efs_policy_attachment" {
  role       = module.efs_irsa_role.iam_role_name
  policy_arn = aws_iam_policy.efs_access_policy.arn
}
