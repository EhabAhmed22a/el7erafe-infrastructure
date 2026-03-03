# 2. Azure Container Registry (Cheapest: Basic SKU)
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

}
resource "azurerm_container_registry" "acr" {
  name                = var.ACR-Name # Must be globally unique and lowercase
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true # Required for the Container App to pull images easily
}

# 3. Log Analytics Workspace (Required for Container Apps to run)
resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.container-app-name}-law"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30 # Absolute minimum retention to save costs
}

# 4. Container Apps Environment
resource "azurerm_container_app_environment" "env" {
  name                       = "${var.container-app-name}-env"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
}

# 5. The Container App (Cheapest specs)
resource "azurerm_container_app" "app" {
  name                         = var.container-app-name
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  # Link the app to your new ACR securely
  registry {
    server               = azurerm_container_registry.acr.login_server
    username             = azurerm_container_registry.acr.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.acr.admin_password
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 8000 # Your FastAPI port

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "safe-guard-api"
      # NOTE: For the very first Terraform run, your ACR will be empty. 
      # We use a Microsoft dummy image here so it doesn't crash. 
      # After your first CI/CD pipeline runs and pushes your Python code, 
      # update this to: "${azurerm_container_registry.acr.login_server}/moderation-api:v2"
      image  = "regexenginedevelopmentacr.azurecr.io/safety-guard-api:v2"
      
      # THE CHEAPEST SPECS POSSIBLE:
      cpu    = 0.5
      memory = "1.0Gi"
    }

    # SCALE CAPABILITIES
    min_replicas = 0 # Scale to zero when not in use
    max_replicas = 2
  }
}