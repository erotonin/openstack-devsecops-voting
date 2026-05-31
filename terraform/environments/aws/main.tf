locals {
  common_tags = {
    Project     = "devsecops-voting"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "networking" {
  source           = "../../modules/networking"
  name_prefix      = var.name_prefix
  vpc_cidr         = var.vpc_cidr
  public_subnets   = var.public_subnets
  private_subnets  = var.private_subnets
  database_subnets = var.database_subnets
  cluster_name     = var.cluster_name
  azs              = ["${var.aws_region}a", "${var.aws_region}b"]
  tags             = local.common_tags
}

module "security_groups" {
  source         = "../../modules/security_groups"
  name_prefix    = var.name_prefix
  vpc_id         = module.networking.vpc_id
  vpc_cidr       = module.networking.vpc_cidr
  cluster_name   = var.cluster_name
  eks_pod_cidrs  = var.private_subnets
  peer_vpc_cidrs = ["10.1.0.0/16"]
  tags           = local.common_tags
}

module "eks" {
  source              = "../../modules/eks"
  cluster_name        = var.cluster_name
  kubernetes_version  = var.eks_kubernetes_version
  subnet_ids          = module.networking.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_max_size       = var.node_max_size
  node_min_size       = var.node_min_size
  tags                = local.common_tags
}

module "ecr" {
  source     = "../../modules/ecr"
  repo_names = var.ecr_repo_names
}

module "db_secret" {
  source = "../../modules/secrets"
  name   = "${var.name_prefix}/db"
  secret_data = {
    username = "postgres"
    database = "voting"
  }
  tags = local.common_tags
}

module "redis_secret" {
  source = "../../modules/secrets"
  name   = "${var.name_prefix}/redis"
  secret_data = {
    username = "default"
  }
  tags = local.common_tags
}

module "rds" {
  source                     = "../../modules/rds"
  identifier                 = "${var.name_prefix}-postgres"
  subnet_ids                 = module.networking.database_subnet_ids
  security_group_ids         = [module.security_groups.rds_sg_id]
  master_username            = "postgres"
  master_password            = module.db_secret.password
  db_name                    = "voting"
  deletion_protection        = false
  skip_final_snapshot        = true
  apply_immediately          = true
  enable_logical_replication = var.enable_postgres_logical_replication
  tags                       = local.common_tags
}

resource "aws_kms_key" "redis_logs" {
  description         = "KMS key for Redis CloudWatch log group encryption"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableIAMUserPermissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/elasticache/${var.name_prefix}-redis"
          }
        }
      },
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-redis-logs-kms"
  })
}

resource "aws_kms_alias" "redis_logs" {
  name          = "alias/${var.name_prefix}-redis-logs"
  target_key_id = aws_kms_key.redis_logs.key_id
}

resource "aws_cloudwatch_log_group" "redis" {
  name              = "/aws/elasticache/${var.name_prefix}-redis"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.redis_logs.arn
  tags              = local.common_tags
}

module "elasticache" {
  source             = "../../modules/elasticache"
  name               = "${var.name_prefix}-redis"
  subnet_ids         = module.networking.private_subnet_ids
  security_group_ids = [module.security_groups.elasticache_sg_id]
  auth_token         = module.redis_secret.password
  log_group_name     = aws_cloudwatch_log_group.redis.name
  tags               = local.common_tags
}

module "app_runtime_secret" {
  source            = "../../modules/secrets"
  name              = "${var.name_prefix}/app-runtime"
  generate_password = false
  secret_data = {
    REDIS_HOST                 = module.elasticache.primary_endpoint_address
    REDIS_PORT                 = tostring(module.elasticache.port)
    REDIS_PASSWORD             = module.redis_secret.password
    REDIS_SSL                  = "true"
    DB_HOST                    = module.rds.address
    DB_PORT                    = tostring(module.rds.port)
    DB_USER                    = "postgres"
    DB_PASSWORD                = module.db_secret.password
    DB_NAME                    = module.rds.db_name
    DB_SSL                     = "true"
    DB_SSL_MODE                = "Require"
    DB_SSL_REJECT_UNAUTHORIZED = "false"
    DATABASE_URL               = "postgres://postgres:${urlencode(module.db_secret.password)}@${module.rds.address}:${module.rds.port}/${module.rds.db_name}?sslmode=require"
    COOKIE_SECURE              = "false"
    COOKIE_SAMESITE            = "Lax"
  }
  tags = local.common_tags
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      module.app_runtime_secret.secret_arn,
      module.db_secret.secret_arn,
      module.redis_secret.secret_arn,
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = [
      module.app_runtime_secret.kms_key_arn,
      module.db_secret.kms_key_arn,
      module.redis_secret.kms_key_arn,
    ]
  }
}

module "external_secrets_irsa" {
  source               = "../../modules/irsa"
  role_name            = "${var.name_prefix}-external-secrets"
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.oidc_provider_url
  namespace            = "external-secrets"
  service_account      = "external-secrets"
  inline_policy_json   = data.aws_iam_policy_document.external_secrets.json
  create_inline_policy = true
  tags                 = local.common_tags
}

resource "aws_serverlessapplicationrepository_cloudformation_stack" "postgres_rotator" {
  name           = "postgres-rotator"
  application_id = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSPostgreSQLRotationSingleUser"
  capabilities   = ["CAPABILITY_IAM", "CAPABILITY_RESOURCE_POLICY"]
  parameters = {
    endpoint            = "https://secretsmanager.${var.aws_region}.amazonaws.com"
    functionName        = "rotate-postgres-db"
    vpcSecurityGroupIds = module.security_groups.rds_sg_id
    vpcSubnetIds        = join(",", module.networking.private_subnet_ids)
  }
}

resource "aws_secretsmanager_secret_rotation" "db_rotation" {
  secret_id           = module.db_secret.secret_arn
  rotation_lambda_arn = aws_serverlessapplicationrepository_cloudformation_stack.postgres_rotator.outputs.RotationLambdaARN

  rotation_rules {
    automatically_after_days = 30
  }
}
