terraform {
  backend "azurerm" {
    resource_group_name  = "MyResourceGroup"
    storage_account_name = "azststest1983"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"

    # THIS IS THE CRITICAL FIX FOR THE BACKEND STAGE
    use_azure_cli    = false
    use_azuread_auth = false
  }

  required_version = ">=1.1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }
    random = { source = "hashicorp/random" }
    tls    = { source = "hashicorp/tls" }
  }
}

provider "azurerm" {
  features {}
  # Also keep this set here for the provider stage
  use_oidc = false 
}
