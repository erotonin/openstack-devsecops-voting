resource "aws_ecr_repository" "repo" {
  count                = length(var.repo_names)
  name                 = var.repo_names[count.index]
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.force_delete
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "repo" {
  count      = length(var.repo_names)
  repository = aws_ecr_repository.repo[count.index].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.max_image_count} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.max_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
