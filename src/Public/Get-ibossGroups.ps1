function Get-ibossGroups {
    <#
    .SYNOPSIS
        Retrieves a list of iBoss Groups.

    .DESCRIPTION
        Queries the iBoss Reporting Service for a list of groups.
        Supports filtering by group name keywords.

    .PARAMETER SearchFilter
        Optional string to filter groups by name. 
        This is appended to the URL path.

    .PARAMETER MaximumItemsToReturn
        The maximum number of items to return. Default is 1000.

    .PARAMETER CurrentRowNumber
        The starting row number for pagination. Default is 1.

    .PARAMETER DefaultGroupId
        Default Group ID parameter. Default is -1.

    .EXAMPLE
        Get-ibossGroups
        
    .EXAMPLE
        Get-ibossGroups -SearchFilter "CIPA"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$SearchFilter,

        [Parameter(Mandatory = $false)]
        [int]$MaximumItemsToReturn = 1000,

        [Parameter(Mandatory = $false)]
        [int]$CurrentRowNumber = 1,

        [Parameter(Mandatory = $false)]
        [int]$DefaultGroupId = -1
    )

    process {
        if (-not $Global:iBossSession) {
            throw "Not connected. Please run Connect-iBoss first."
        }

        # 1. Construct URL
        $Uri = "/ibreports/web/log/group"
        if (-not [string]::IsNullOrWhiteSpace($SearchFilter)) {
            $Uri += "/$([Uri]::EscapeDataString($SearchFilter))"
        }

        # 2. Construct Query Parameters
        $QueryParams = @{
            maximumItemsToReturn = $MaximumItemsToReturn
            currentRowNumber     = $CurrentRowNumber
            defaultGroupId       = $DefaultGroupId
        }

        $QueryString = ($QueryParams.Keys | ForEach-Object { "$($_)=$($QueryParams[$_])" }) -join "&"
        $Uri += "?$QueryString"

        # 3. Invoke Request
        try {
            $Result = Invoke-iBossRequest -Service Reporting -Uri $Uri -Verbose:$VerbosePreference
            
            if ($Result) {
                $Result | ForEach-Object {
                    [PSCustomObject]@{
                        GroupName          = $_.filteringGroupName
                        GroupId            = $_.reportingGroup
                        DecryptedGroupName = $_.decryptedGroupName
                    }
                }
            }
        }
        catch {
            Write-Error "Failed to retrieve groups: $_"
        }
    }
}
