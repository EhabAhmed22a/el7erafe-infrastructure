resource "azurerm_storage_account" "clients"{
  name                     = var.storage_client_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS" 
}
//clinets here i mean the services and the images of clients
# Container 1: Public Read Access (Blob)
resource "azurerm_storage_container" "services_docs" {
  name                  = "services-documents"
  storage_account_id    = azurerm_storage_account.clients.id
  container_access_type = "blob" # This sets the "Blob" access level seen in your image
}

# Container 2: Private Access
resource "azurerm_storage_container" "tech_docs" {
  name                  = "technician-documents"
  storage_account_id    = azurerm_storage_account.clients.id
  container_access_type = "private" # This sets the "Private" access level seen in your image
}
resource "azurerm_storage_container" "service_requests_images" {
  name                  = "service-requests-images"
  storage_account_id    = azurerm_storage_account.clients.id
  container_access_type = "private" # This sets the "Private" access level seen in your image
}
resource "azurerm_storage_container" "client-profilepics" {
  name                  = "client-profilepics"
  storage_account_id    = azurerm_storage_account.clients.id
  container_access_type = "private" # This sets the "Private" access level seen in your image
}
# 2. Assign the "Storage Blob Data Contributor" role


resource "azurerm_storage_account" "dashboard" {
  name                     = var.storage_dashboard_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags = {
    environment = "environment"
  }

}
resource "azurerm_storage_account_static_website" "dashboard" {
  storage_account_id = azurerm_storage_account.dashboard.id
  
  error_404_document = "index.html"
  index_document     = "index.html"
}
