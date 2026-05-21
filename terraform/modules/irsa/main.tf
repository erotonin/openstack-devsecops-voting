# ─────────────────────────────────────────────────────────────────
# IRSA Module — IAM Role for Service Account
#
# Tạo IAM Role với:
#   - Trust policy gắn EKS OIDC provider
#   - Sub condition scope tới service-account cụ thể (least privilege)
#   - Attach inline policy hoặc managed policy ARN từ caller
#
# Caller pattern:
#   module "vote_irsa" {
#     source = "../../modules/irsa"
#     role_name           = "voting-vote-irsa"
#     oidc_provider_arn   = module.eks.oidc_provider_arn
#     oidc_provider_url   = module.eks.oidc_provider_url
#     service_account     = "vote-sa"
#     namespace           = "voting"
#     inline_policy_json  = data.aws_iam_policy_document.vote.json
#   }
# ─────────────────────────────────────────────────────────────────

locals {
  common_tags = merge(var.tags, {
    Module    = "irsa"
    ManagedBy = "terraform"
  })
}

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    # Scope tới (namespace, service-account) cụ thể — Least Privilege
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json
  description        = "IRSA cho ${var.namespace}/${var.service_account}"

  tags = merge(local.common_tags, {
    Name      = var.role_name
    Namespace = var.namespace
    SA        = var.service_account
  })
}

# ─── Inline policy (custom permissions) ────────────────────────────
resource "aws_iam_role_policy" "inline" {
  count  = var.create_inline_policy ? 1 : 0
  name   = "${var.role_name}-inline"
  role   = aws_iam_role.this.id
  policy = var.inline_policy_json
}

# ─── Attach managed policy ARNs ───────────────────────────────────
resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}
