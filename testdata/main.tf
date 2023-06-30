terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.6.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.61.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

provider "azurerm" {
  features {}
}
