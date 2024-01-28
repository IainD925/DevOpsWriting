[CmdletBinding()]
param (
    [string]$databaseName      = '',
    [string]$Environment       = '',
    [string]$resourceGroupName = '',
    [string]$serverName        = '',
    [string]$db_Owner_List     = '',
    [string]$db_Readers_List   = ''
)

$ErrorActionPreference = "Stop"

# List of users passed in as comma separated string.  Split to array so we can iterate over.
function Split-String {
    param([string]$InputString)
    $result = $InputString.Split(',')
    return $result
}

Write-Host "$Environment $databaseName On $serverName ]"

# Check DB exists, create Users if so | Exit if not
$db = Get-AzSqlDatabase -ResourceGroupName $resourceGroupName -ServerName $serverName -DatabaseName $databaseName -ErrorAction SilentlyContinue

if ($db -ne $null) {
    Write-Host "Database: $databaseName found"

    $accessToken = (Get-AzAccessToken -ResourceUrl "https://database.windows.net/").Token

    if ($accessToken -eq $null){
        Write-Host "Unable to get access token"
        exit 0
    } else {
        Write-Host "Access token obtained"
    }

    # Create SQL connection
    Write-Host "Building SQL connection"
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $sqlConnection.ConnectionString = "Server=tcp:$serverName.database.windows.net,1433;Initial Catalog=$databaseName;TrustServerCertificate=False;Encrypt=True;"
    $sqlConnection.AccessToken = $accessToken

    Write-Host "Opening SQL connection"
    $sqlConnection.Open()

        # Add database Users
        $ownerArray = Split-String -InputString $db_Owner_List
        if($ownerArray -and $ownerArray.Count -gt 0){
            Write-Host "-------------------------------------------------"
            Write-Host "Attempting to add db_owner to the following users: $db_Owner_List"
                foreach($owner in $ownerArray){
                    try {
                        $sqlCommand = $sqlConnection.CreateCommand()
                        $sqlStringCreate = "CREATE USER [$owner] FROM EXTERNAL PROVIDER;"
                        Write-Host "Executing command: $sqlStringCreate"
                        $sqlCommand.CommandText = $sqlStringCreate
                        $sqlCommand.ExecuteNonQuery()
                
                        $sqlStringAlter = "ALTER ROLE [db_owner] ADD MEMBER [$owner];"
                        Write-Host "Executing command: $sqlStringAlter"
                        $sqlCommand.CommandText = $sqlStringAlter
                        $sqlCommand.ExecuteNonQuery()
                        Write-Host "db_owner role granted to $owner"
                        } catch {
                            Write-Host "Error processing user ${owner}: $_"
                                }
                }
        }
       
        $readerArray = Split-String -InputString $db_Readers_List
        if($readerArray -and $readerArray.Count -gt 0){
            Write-Host "-------------------------------------------------"
            Write-Host "Attempting to add db_reader to the following users: $db_Readers_List"
                foreach($reader in $readerArray){
                    try {
                        $sqlCommand = $sqlConnection.CreateCommand()
                        $sqlStringCreate = "CREATE USER [$reader] FROM EXTERNAL PROVIDER;"
                        Write-Host "Executing command: $sqlStringCreate"
                        $sqlCommand.CommandText = $sqlStringCreate
                        $sqlCommand.ExecuteNonQuery()
                
                        $sqlStringAlter = "ALTER ROLE [dbo_reader] ADD MEMBER [$reader];"
                        Write-Host "Executing command: $sqlStringAlter"
                        $sqlCommand.CommandText = $sqlStringAlter
                        $sqlCommand.ExecuteNonQuery()
                        Write-Host "dbo_reader role granted to $reader"
                        } catch {
                        Write-Host "Error processing user ${reader}: $_"
                                }
                        }
        }

    # Close connection
    $sqlConnection.Close()

} else {
    Write-Host "Database $databaseName not found: exiting script!"
    exit 0
}
