# ─────────────────────────────────────────────────────────────────
# Secrets Manager Module
#
# Tạo:
#   - KMS key riêng cho secret encryption
#   - Random password (>=20 char, có ký tự đặc biệt)
#   - Secret + initial version
#   - Resource policy cho phép IRSA role read
# ─────────────────────────────────────────────────────────────────

locals {
  common_tags = merge(var.tags, {
    Module    = "secrets"
    ManagedBy = "terraform"
  })
}

# ─── KMS key ─────────────────────────────────────────────────────
resource "aws_kms_key" "secret" {
  description             = "KMS key cho secret ${var.name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${var.name}-secret-kms"
  })
}

resource "aws_kms_alias" "secret" {
  name          = "alias/${var.name}-secret"
  target_key_id = aws_kms_key.secret.key_id
}

# ─── Random password ─────────────────────────────────────────────
resource "random_password" "this" {
  count   = var.generate_password ? 1 : 0
  length  = 24
  special = true
  # RDS password không cho phép `/` `@` `"` ` ` (space)
  override_special = "!#-_=+"
}

# ─── Secret ──────────────────────────────────────────────────────
resource "aws_secretsmanager_secret" "this" {
  name                    = var.name
  description             = var.description
  kms_key_id              = aws_kms_key.secret.arn
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(local.common_tags, {
    Name = var.name
  })
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id = aws_secretsmanager_secret.this.id

  secret_string = var.generate_password ? jsonencode(merge(
    var.secret_data,
    { password = random_password.this[0].result }
  )) : jsonencode(var.secret_data)

  lifecycle {
    ignore_changes = [secret_string] # rotate sẽ đổi giá trị, đừng overwrite
  }
}

# ─── Resource policy: cho phép principal đọc secret ───────────────
data "aws_iam_policy_document" "secret_access" {
  count = length(var.allowed_principals) > 0 ? 1 : 0

  statement {
    sid    = "AllowReadByPrincipals"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.allowed_principals
    }

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]

    resources = ["*"]
  }
}

resource "aws_secretsmanager_secret_policy" "this" {
  count      = length(var.allowed_principals) > 0 ? 1 : 0
  secret_arn = aws_secretsmanager_secret.this.arn
  policy     = data.aws_iam_policy_document.secret_access[0].json
}
