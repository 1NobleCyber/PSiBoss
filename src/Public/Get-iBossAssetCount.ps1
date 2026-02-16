<#
.SYNOPSIS
    Retrieves a count of Zero Trust assets from iBoss.

.DESCRIPTION
    The Get-iBossAssetCount function retrieves aggregated statistics and counts of assets from the iBoss Zero Trust endpoint.
    This includes total counts, infected counts, missing counts, component scores, and location data.

.EXAMPLE
    Get-iBossAssetCount
    Retrieves the asset count statistics.
#>
function Get-iBossAssetCount {
    [CmdletBinding()]
    param()

    process {
        if (-not $Global:iBossSession) {
            throw "Not connected. Please run Connect-iBoss first."
        }

        $Uri = "/ibreports/web/zerotrust/assets/counts"

        Write-Verbose "Querying iBoss Asset Counts: $Uri"

        try {
            # Use Reporting service
            $Result = Invoke-iBossRequest -Service Reporting -Uri $Uri -Verbose:$VerbosePreference
            
            return $Result
        }
        catch {
            Write-Error "Failed to retrieve asset counts: $_"
        }
    }
}
