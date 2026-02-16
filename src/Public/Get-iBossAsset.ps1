<#
.SYNOPSIS
    Retrieves a list of Zero Trust assets from iBoss.

.DESCRIPTION
    The Get-iBossAsset function retrieves a list of assets from the iBoss Zero Trust Cloud Connector Assets endpoint.
    It supports pagination, filtering by infected status and missing status, and sorting.

.PARAMETER Limit
    The maximum number of items to return. Default is 25.

.PARAMETER Ascending
    Sorts the results in ascending order. Default is false (Descending).

.PARAMETER Infected
    Filters assets by infected status. 
    Valid values: 'All', 'Yes', 'No'. Default is 'All' (-1).

.PARAMETER Missing
    Filters assets by missing status.
    Valid values: 'All', 'Yes', 'No'. Default is 'All' (-1).
    Maps to the 'assetMissing' query parameter.

.PARAMETER CurrentRowNumber
    The row number to start retrieving results from. Useful for pagination. Default is 1.

.EXAMPLE
    Get-iBossAsset
    Retrieves the first 25 assets.

.EXAMPLE
    Get-iBossAsset -Limit 50 -Infected Yes
    Retrieves up to 50 infected assets.

.EXAMPLE
    Get-iBossAsset -Missing No -Ascending
    Retrieves non-missing assets sorted in ascending order.
#>
function Get-iBossAsset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Limit = 25,

        [Parameter(Mandatory = $false)]
        [switch]$Ascending,

        [Parameter(Mandatory = $false)]
        [ValidateSet('All', 'Yes', 'No')]
        [string]$Infected = 'All',

        [Parameter(Mandatory = $false)]
        [ValidateSet('All', 'Yes', 'No')]
        [string]$Missing = 'All',

        [Parameter(Mandatory = $false)]
        [int]$CurrentRowNumber = 1
    )

    process {
        if (-not $Global:iBossSession) {
            throw "Not connected. Please run Connect-iBoss first."
        }

        # Map filters to API values
        # All -> -1, Yes -> 1, No -> 0
        $StatusMap = @{
            'All' = '-1';
            'Yes' = '1';
            'No'  = '0'
        }

        $AssetMissingVal = $StatusMap[$Missing]
        $InfectedVal = $StatusMap[$Infected]
        
        $OrderAscending = if ($Ascending) { "true" } else { "false" }

        # --- Pagination Setup ---
        $MaxBatchSize = 1000
        $TotalRetrieved = 0
        $CurrentRow = $CurrentRowNumber

        do {
            # Calculate batch size
            $CalculatedBatchSize = ($Limit - $TotalRetrieved)
            $BatchLimit = if ($CalculatedBatchSize -lt $MaxBatchSize) { $CalculatedBatchSize } else { $MaxBatchSize }
            
            if ($BatchLimit -le 0) { break }

            # Construct Query Parameters
            $QueryParams = @{
                assetMissing     = $AssetMissingVal
                currentRowNumber = $CurrentRow
                infected         = $InfectedVal
                maxItemsToReturn = $BatchLimit
                orderAscending   = $OrderAscending
            }

            # Construct Query String
            $QueryString = ($QueryParams.Keys | ForEach-Object { 
                    "$($_)=$([Uri]::EscapeDataString($QueryParams[$_]))" 
                }) -join "&"

            $Uri = "/ibreports/web/zerotrust/cloudConnectorAssets?$QueryString"

            Write-Verbose "Querying iBoss Assets (Batch Limit: $BatchLimit, Start: $CurrentRow): $Uri"

            try {
                # Use Reporting service
                $Result = Invoke-iBossRequest -Service Reporting -Uri $Uri -Verbose:$VerbosePreference
                
                # Check if results were returned
                if ($Result) {
                    $CountReturned = $Result.Count
                    
                    # Ensure $Result is an array even if single item
                    $ResultArray = @($Result)
                    
                    foreach ($Item in $ResultArray) {
                        # --- Decoding Logic ---
                        if (-not [string]::IsNullOrWhiteSpace($Item.registrationInfo)) {
                            try {
                                # Decode Base64
                                $Bytes = [System.Convert]::FromBase64String($Item.registrationInfo)
                                $Json = [System.Text.Encoding]::UTF8.GetString($Bytes)
                                # Parse JSON and replace the property
                                $Item.registrationInfo = $Json | ConvertFrom-Json

                                # Decode nested agentPostureString if present
                                if ($Item.registrationInfo.agentPostureString) {
                                    try {
                                        $BytesPosture = [System.Convert]::FromBase64String($Item.registrationInfo.agentPostureString)
                                        $JsonPosture = [System.Text.Encoding]::UTF8.GetString($BytesPosture)
                                        $RawPostureArray = $JsonPosture | ConvertFrom-Json
                                        
                                        # Refactor into a structured object for cleaner output
                                        $PostureObject = [Ordered]@{}
                                        
                                        foreach ($PItem in $RawPostureArray) {
                                            if ($PItem.Type) {
                                                $Key = $PItem.Type
                                                
                                                # Get properties excluding 'Type'
                                                $Props = $PItem.PSObject.Properties | Where-Object { $_.Name -ne 'Type' }
                                                
                                                if ($Props.Count -eq 1) {
                                                    # If only one data property, unwrap it (e.g. Checks, Domains)
                                                    $PostureObject[$Key] = $Props[0].Value
                                                }
                                                else {
                                                    # Otherwise keep as object (minus Type)
                                                    $PostureObject[$Key] = $PItem | Select-Object * -ExcludeProperty Type
                                                }
                                            }
                                        }

                                        # Replace the property with our cleaner object
                                        $Item.registrationInfo.agentPostureString = $PostureObject
                                    }
                                    catch {
                                        Write-Warning "Failed to decode/parse agentPostureString for asset $($Item.id): $_"
                                    }
                                }
                            }
                            catch {
                                Write-Warning "Failed to decode/parse registrationInfo for asset $($Item.id): $_"
                            }
                        }
                        
                        # --- Output Streaming ---
                        Write-Output $Item
                    }
                    
                    # Update counters
                    $TotalRetrieved += $CountReturned
                    $CurrentRow += $CountReturned
                    
                    # If we got 0 items, we truly reached the end
                    if ($CountReturned -eq 0) {
                        break
                    }
                }
                else {
                    # No results, break loop
                    break
                }
            }
            catch {
                Write-Error "Failed to retrieve assets: $_"
                break
            }
        } while ($TotalRetrieved -lt $Limit)
    }
}
