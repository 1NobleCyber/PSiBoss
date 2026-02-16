function Get-iBossLogTable {
    <#
    .SYNOPSIS
        Retrieves the list of available log tables (archives) from the iBoss Reporting Service.

    .DESCRIPTION
        Sends a request to the iBoss Reporting Node to fetch all available log archives, 
        including log reports if specified. 
        Endpoint: /ibreports/web/log/ips/archives

    .EXAMPLE
        Get-iBossLogTable
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('url', 'ips')]
        [string]$LogFamily = 'url'
    )

    process {
        if (-not $Global:iBossSession) {
            throw "Not connected. Please run Connect-iBoss first."
        }

        $Uri = "/ibreports/web/log/$LogFamily/archives?includeAllRecord=true&includeLogReports=true"
        
        $Result = Invoke-iBossRequest -Service Reporting -Uri $Uri -Verbose:$VerbosePreference

        return $Result
    }
}
