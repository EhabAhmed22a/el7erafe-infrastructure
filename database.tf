data "azurerm_client_config" "current" {}
# SQL Server
#This fetches details about the Azure account currently running Terraform (you or your service principal).
#Later in the code, we need to know your Tenant ID and Object ID to set you up as the administrator of the SQL Server.

resource "azurerm_mssql_server" "main" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  azuread_administrator {
    login_username = "terraform-admin"
    object_id      = data.azurerm_client_config.current.object_id
    tenant_id      = data.azurerm_client_config.current.tenant_id
  }
  identity {
    type = "SystemAssigned"
  }
  tags              = local.default_tags
}


# SQL Database
resource "azurerm_mssql_database" "main" {
  name        = var.sql_database_name
  server_id   = azurerm_mssql_server.main.id
  collation   = "SQL_Latin1_General_CP1_CI_AS" #Sets the language/sorting rules (SQL_Latin1... is the standard default).
  max_size_gb    = 2
  sku_name    = "${var.sql_database_sku}"
  storage_account_type = "Local"
  tags        = local.default_tags
}
resource "null_resource" "create_sql_mi_user" { #This resource runs a local PowerShell script to create a user in the SQL Database for the App Service's Managed Identity.
  provisioner "local-exec" {
    command = <<EOT
      $LogFile = "user_creation.log"
      Start-Transcript -Path $LogFile -Append -Force             # Logs all output to a file for debugging
      
      $ErrorActionPreference = "Stop"

      Write-Host "Logging in with Service Principal..."
      az login --service-principal -u "${var.client_id}" -p "${var.client_secret}" --tenant "${var.tenant_id}" --allow-no-subscriptions | Out-Null
      Write-Host "Login successful."

      Write-Host "Getting access token for SQL Database..."
      $accessToken = az account get-access-token --resource "https://database.windows.net" --query accessToken -o tsv
      if (-not $accessToken) {
          Write-Error "Failed to get access token for SQL Database."
          exit 1
      }
      # Adding a check to see what the token looks like without exposing it.
      Write-Host "Successfully got access token. Token length: $($accessToken.Length)"

      $query = @"
      IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = '${azurerm_windows_web_app.backend.name}')
      BEGIN
          CREATE USER [${azurerm_windows_web_app.backend.name}] FROM EXTERNAL PROVIDER;
          ALTER ROLE db_datareader ADD MEMBER [${azurerm_windows_web_app.backend.name}];
          ALTER ROLE db_datawriter ADD MEMBER [${azurerm_windows_web_app.backend.name}];
          CREATE USER [github-actions-el7rafe] FROM EXTERNAL PROVIDER;
          ALTER ROLE db_ddladmin ADD MEMBER [github-actions-el7rafe];
          ALTER ROLE db_datareader ADD MEMBER [github-actions-el7rafe];
          ALTER ROLE db_datawriter ADD MEMBER [github-actions-el7rafe];
          PRINT 'SUCCESS: Managed Identity user created and added to roles.';
      END
      ELSE
      BEGIN
          PRINT 'INFO: Managed Identity user already exists.';
      END
"@


          try {
              # --- .NET APPROACH START ---
              
              # 1. Define Connection String using your Terraform variables
              $serverName = "${azurerm_mssql_server.main.name}.database.windows.net"
              $dbName = "${azurerm_mssql_database.main.name}"
              
              # Standard Azure SQL Connection string
              $connString = "Server=tcp:$serverName,1433;Initial Catalog=$dbName;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

              # 2. Create the SQL Connection Object
              $conn = New-Object System.Data.SqlClient.SqlConnection($connString)

              # 3. INJECT THE TOKEN DIRECTLY 
              # This bypasses the "Parameter 'AccessToken' not found" error because 
              # we are setting a property on the object, not passing a parameter to a cmdlet.
              $conn.AccessToken = $accessToken

              # 4. Open Connection
              $conn.Open()
              Write-Host "SQL Connection Opened successfully."

              # 5. Prepare the Command
              $cmd = $conn.CreateCommand()
              $cmd.CommandText = $query
              $cmd.CommandTimeout = 240  # Your requested timeout

              # 6. Execute 
              # ExecuteNonQuery is used for CREATE/ALTER/INSERT/UPDATE statements
              $rowsAffected = $cmd.ExecuteNonQuery()
              
              Write-Host "Query executed successfully. Internal Result: $rowsAffected"

              # 7. Close Connection
              $conn.Close()
              Write-Host "SQL configuration successful! Exiting the retry loop."
              break
              
              # --- .NET APPROACH END ---

          } catch {
              # --- YOUR ORIGINAL ERROR HANDLING (Preserved) ---
              
              Write-Warning "##[error]Caught an error during SQL user creation on attempt $i : $_ "
              
              if($_.Exception) {
                Write-Warning "Error details: $($_.Exception.Message)"
              }
              
              # Added extra check for InnerException which is common in .NET errors
              if($_.Exception.InnerException) {
                 Write-Warning "Inner Exception: $($_.Exception.InnerException.Message)"
              }

              if ($i -eq $maxRetries) {
                  Write-Error "Max retries reached. Failed to create SQL user."
                  exit 1
              }
              
              Write-Host "Waiting for $retryDelay seconds before retrying..."
              Start-Sleep -Seconds $retryDelay
          }
      
      Stop-Transcript
    EOT
    interpreter = ["PowerShell", "-Command"]
  }

  depends_on = [
    azurerm_mssql_database.main,
    azurerm_windows_web_app.backend,
    azuread_directory_role_assignment.sql_server_identity_dir_reader
  ]
}
# Firewall rule to allow Azure services
resource "azurerm_mssql_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
# Firewall rule for your public IP
resource "azurerm_mssql_firewall_rule" "allow_my_ip" {
  name             = "AllowMyPublicIP"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = var.my_public_ip
  end_ip_address   = var.my_public_ip
}
# Get the "Directory Readers" role definition
