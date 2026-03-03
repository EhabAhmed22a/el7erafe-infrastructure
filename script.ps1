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