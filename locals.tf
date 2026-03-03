locals {
  # Resource naming conventions
  naming_prefix = "${var.project_name}${var.environment}"
  resource_suffix = "${var.project_name}-${var.environment}"
  
  # Resource Group
  resource_group_name = var.resource_group_name
  
  # Storage Account names (must be unique globally, lowercase, no hyphens)
  client_data_storage_name = "${lower(replace(local.naming_prefix, "-", ""))}clientdata"
  web_dashboard_storage_name = "${lower(replace(local.naming_prefix, "-", ""))}webdash"

  
  # SQL Server name (must be unique globally)
  sql_server_name = "${lower(replace(local.naming_prefix, "-", ""))}-sql"
  
  # App Service names
  app_service_plan_name = "${local.naming_prefix}-asp"
  app_service_name = "${local.naming_prefix}-backend"
  
  
  
  
  # Standard tags
  default_tags = {
    Environment   = var.environment
    Project       = var.project_name
    ManagedBy     = "Terraform"
    Repository    = "https://github.com/EhabAhmed22a/el7erafe-backend-api"
  }
  
#   merged_tags = merge(local.default_tags, var.additional_tags)
  
  # Environment-specific configurations
  environment_config = {
    dev = {
      app_service_plan_sku        = "B2"
      sql_database_sku            = "Basic"
      sql_database_max_size_gb    = 10
      storage_replication_type    = "LRS"
      log_retention_days          = 30
      enable_diagnostic_settings  = false
    }
    staging = {
      app_service_plan_sku        = "S1"
      sql_database_sku            = "S1"
      sql_database_max_size_gb    = 50
      storage_replication_type    = "GRS"
      log_retention_days          = 90
      enable_diagnostic_settings  = true
    }
    prod = {
      app_service_plan_sku        = "P1v2"
      sql_database_sku            = "P1"
      sql_database_max_size_gb    = 100
      storage_replication_type    = "GRS"
      log_retention_days          = 365
      enable_diagnostic_settings  = true
    }
  }
  
  config = local.environment_config[var.environment]
}