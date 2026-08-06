resource "aws_ecr_repository" "app" {
  name                 = "txodds"
  image_tag_mutability = "IMMUTABLE"
}
