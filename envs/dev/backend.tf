# envs/dev/backend.tf

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Будь-яка версія 5.x.x
    }
  }

  backend "s3" {
    bucket  = "tf-state-lab4-nechyporuk-ira-13" # Ваша унікальна назва бакету
    key     = "envs/dev/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true

    # Нативне блокування S3 (замінює DynamoDB table, Terraform >= 1.10.0)
    use_lockfile = true
  }
}