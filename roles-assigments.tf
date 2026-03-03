data "azuread_service_principal" "github_actions" {
  display_name = "github-actions-el7rafe" 
  # This searches Azure AD for an SP with this exact name
}
resource "azurerm_role_assignment" "github_ci_access" {
  # Scope: Give access ONLY to the specific container (e.g., dashboard-uploads)
  scope                = "${azurerm_storage_account.dashboard.id}/blobServices/default/containers/$web"
  # The Role: Read/Write/Delete blobs
  role_definition_name = "Storage Blob Data Contributor"
  # The Who: The Object ID of the SP we found above
  principal_id         = data.azuread_service_principal.github_actions.object_id
}
resource "azuread_directory_role" "directory_readers" {
  display_name = "Directory Readers"
}
resource "azurerm_role_assignment" "user_delegated_storage_access" {
  scope                = azurerm_storage_account.clients.id
  role_definition_name = "Storage Blob Delegator"
  principal_id         = azurerm_windows_web_app.backend.identity[0].principal_id
}

# Assign the SQL Server's Managed Identity to the "Directory Readers" role
resource "azuread_directory_role_assignment" "sql_server_identity_dir_reader" {
  role_id             = azuread_directory_role.directory_readers.template_id
  principal_object_id = azurerm_mssql_server.main.identity[0].principal_id
}
resource "azurerm_role_assignment" "app_access_tech_docs" {
  # The Scope: ONLY the "technician-documents" container
  scope                = azurerm_storage_container.tech_docs.resource_manager_id
  
  # The Permission: Read, Write, and Delete blobs
  role_definition_name = "Storage Blob Data Contributor"
  
  # The Who: Your App Service's Managed Identity
  principal_id         = azurerm_windows_web_app.backend.identity[0].principal_id
}
resource "azurerm_role_assignment" "app_access_client-profilepics" {
  scope                = azurerm_storage_container.client-profilepics.resource_manager_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_windows_web_app.backend.identity[0].principal_id
}
resource "azurerm_role_assignment" "app_access_services-documents" {
  scope                = azurerm_storage_container.services_docs.resource_manager_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_windows_web_app.backend.identity[0].principal_id
}
resource "azurerm_role_assignment" "github_app_contributor" {
  scope                = azurerm_windows_web_app.backend.id
  role_definition_name = "Contributor"
  principal_id         = data.azuread_service_principal.github_actions.object_id
}
resource "azurerm_role_assignment" "github_sql_contributor" {
  scope                = azurerm_mssql_server.main.id
  role_definition_name = "Contributor"
  principal_id         = data.azuread_service_principal.github_actions.object_id
}
resource "azurerm_role_assignment" "app_access_service_requests_images" {
  # The Scope: ONLY the "technician-documents" container
  scope                = azurerm_storage_container.service_requests_images.resource_manager_id
  
  # The Permission: Read, Write, and Delete blobs
  role_definition_name = "Storage Blob Data Contributor"
  
  # The Who: Your App Service's Managed Identity
  principal_id         = azurerm_windows_web_app.backend.identity[0].principal_id
}