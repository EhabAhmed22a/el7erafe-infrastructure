terraform {
  required_providers {
    azurerm = {
        source = "hashicorp/azurerm"
        version = "4.49.0"
    }
    null = {
      source = "hashicorp/null"
      version = "3.2.4"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
  
    required_version = ">= 1.3.0"
}