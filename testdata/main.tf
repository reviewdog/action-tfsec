terraform {
  required_version = "~> 0.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

provider "azurerm" {
  features {}
}
