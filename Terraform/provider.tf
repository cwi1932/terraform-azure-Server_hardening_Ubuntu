terraform {
  backend "azurerm" {
    resource_group_name  = "MyResourceGroup"
    storage_account_name = "azststest1983"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"

    # THIS IS THE CRITICAL FIX FOR THE BACKEND STAGE
    use_azure_cli = True
  }

  required_version = ">=1.1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }

    # FIX: These are now properly placed inside required_providers
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Keep your resource declaration here
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

provider "azurerm" {
  features {}

}
