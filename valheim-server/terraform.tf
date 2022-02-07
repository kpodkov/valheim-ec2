terraform {
  required_version = "~> 1.1.0"

  backend "s3" {
    bucket = "tfstate-731310336214"
    key    = "valheim-server/prod/terraform.tfstate"
    region = "eu-central-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
