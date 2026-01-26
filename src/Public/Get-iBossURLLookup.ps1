function Get-iBossURLLookup {
    <#
    .SYNOPSIS
        Checks the categorization and reputation of a URL.

    .description
        Retrieves detailed information about a URL including its assigned categories,
        malware status, and reputation.
        Note: The raw 'categories' bitmask is removed from the output for readability.

    .PARAMETER Url
        The URL to lookup (e.g. "google.com").

    .EXAMPLE
        Get-iBossURLLookup -Url "testing.com"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Url
    )

    process {
        $Uri = "/json/controls/urlLookup"
        
        $Payload = @{
            url = $Url
        }

        if ($PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') -ne 'SilentlyContinue') {
            Write-Verbose "Looking up URL: $Url"
        }

        $Response = Invoke-iBossRequest -Service Gateway -Uri $Uri -Method POST -Body $Payload
        
        return $Response
    }
}
