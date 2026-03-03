# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.default_tags
}
# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = "${local.naming_prefix}-asp"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Windows"
  sku_name            = var.app_service_plan_sku
  tags                = local.default_tags
}

# App Service for .NET Backend
resource "azurerm_windows_web_app" "backend" {
  name                = var.app_service_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id
  tags                = local.default_tags
  lifecycle {
    ignore_changes = [
      site_config[0].cors # Tells Terraform not to panic if this block changes after planning
    ]
  }
  site_config {
    
    always_on = false
    
    application_stack {
      current_stack  = "dotnet"
      dotnet_version = var.dotnet_version
    }
  #   cors {
  #     allowed_origins = [
  #       trimsuffix(azurerm_storage_account.dashboard.primary_web_endpoint, "/"), # Your Static Website # Your Static Website
  #       "https://localhost:4200",                               # Local Angular Dev (HTTPS)
  #       "http://localhost:4200"                                 # Local Angular Dev (HTTP)
  #     ]
  # }
  }
  
  app_settings = {

    "ConnectionStrings__DefaultConnection" = "Server=tcp:${azurerm_mssql_server.main.name}.database.windows.net;Database=${var.sql_database_name};Authentication=Active Directory Default;Encrypt=true;"
    "JWTOptions:Audience" = "https://el7rafe-gma4hrg0e9epfsc0.uaenorth-01.azurewebsites.net/"
    "JWTOptions:Issuer" = "https://el7rafe-gma4hrg0e9epfsc0.uaenorth-01.azurewebsites.net/"
   "JWTOptions:SecretKey" = "0c07c768d8a042c3d2b8e9476851661c4bfc6463b8dc9fd9e944b74a1fef914e"
    "ASPNETCORE_ENVIRONMENT" = var.environment == "prod" ? "Production" : "Development"
  }

  identity {
    type = "SystemAssigned"
  }
  depends_on = [ azurerm_storage_account_static_website.dashboard ]
}
resource "null_resource" "set_backend_cors" {
  # This guarantees Terraform won't run this until the URL actually exists
  depends_on = [
    azurerm_windows_web_app.backend,
    azurerm_storage_account.dashboard
  ]

  # If the dashboard URL ever changes, this forces the script to run again
  triggers = {
    storage_endpoint = azurerm_storage_account.dashboard.primary_web_endpoint
  }

  provisioner "local-exec" {
    command = <<EOT
      $ErrorActionPreference = "Stop"
      
      $webAppName = "${azurerm_windows_web_app.backend.name}"
      $resourceGroup = "${azurerm_resource_group.main.name}" 
      $allowedOrigin = "${trimsuffix(azurerm_storage_account.dashboard.primary_web_endpoint, "/")}"

      Write-Host "Injecting CORS rule for $allowedOrigin into $webAppName..."
      
      # The Azure CLI command to add the CORS origin directly
      az webapp cors add --resource-group $resourceGroup --name $webAppName --allowed-origins $allowedOrigin
      
      Write-Host "CORS injection successful!"
    EOT
    interpreter = ["PowerShell", "-Command"]
  }
}