function Add-iBossAllowList {
    <#
    .SYNOPSIS
        Adds a URL to the iBoss Allow List with full security control options.

    .PARAMETER Url
        The domain or URL to allow (e.g., "example.com").
    .PARAMETER Note
        Optional comment for this entry.
    .PARAMETER Weight
        The priority weight. Default is 501.
    .PARAMETER PolicyId
        The policy ID to apply this to. Default is 1.
    .PARAMETER Global
        Default: 0
    .PARAMETER IsRegex
        Default: 0
    .PARAMETER AllowKeyword
        Default: 0
    .PARAMETER Direction
        Default: 2
    .PARAMETER Priority
        Default: 0
    .PARAMETER TimedUrl
        URL Expiration time in seconds. Default: 0 (No expiration).
    .PARAMETER StartPort
        Default: null (Rendered as literal JSON null)
    .PARAMETER EndPort
        Default: null (Rendered as literal JSON null)
    .PARAMETER DoMalwareScan
        Default: 1
    .PARAMETER DoDlpScan
        Default: 1
    .PARAMETER DoFileChecks
        Default: 1
    .PARAMETER OverrideZeroTrust
        Default: 0
    .PARAMETER SslBypass
        Default: 0
    .PARAMETER UrlFieldType
        Default: 0
    .PARAMETER ApplyKeywordAndSafeSearch
        Default: 0

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Url,
        [string]$Note = "",
        [int]$Weight,

        [int]$PolicyId = 1,
        [int]$Global = 0,
        [int]$IsRegex = 0,
        [int]$AllowKeyword = 0,
        [int]$Direction = 2,
        [int]$Priority = 0,
        [int]$TimedUrl = 0,
        [Nullable[int]]$StartPort = $null,
        [Nullable[int]]$EndPort = $null,
        [int]$DoMalwareScan = 1,
        [int]$DoDlpScan = 1,
        [int]$DoFileChecks = 1,
        [int]$OverrideZeroTrust = 0,
        [int]$SslBypass = 0,
        [int]$UrlFieldType = 0,
        [int]$ApplyKeywordAndSafeSearch = 0

    )

    process {
        if (-not $PSBoundParameters.ContainsKey('Weight')) {
            # Split on the first '/'
            $Parts = $Url.Split(@('/'), 2, [System.StringSplitOptions]::None)
            
            # Split the first value by '.'
            $DomainParts = $Parts[0].Split('.')
            
            # Split the second value by '/'
            $PathParts = @()
            if ($Parts.Count -gt 1) {
                $PathParts = $Parts[1].Split('/')
            }
            
            # Count the total number of elements
            $Count = $DomainParts.Count + $PathParts.Count
            
            # Add this to 499
            $Weight = 499 + $Count
            
            if ($PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') -ne 'SilentlyContinue') {
                Write-Verbose "Calculated Weight based on URL complexity: $Weight (Parts: $Count)"
            }
        }

        $Uri = "/json/controls/allowList?currentPolicyBeingEdited=$PolicyId"


        $Payload = @{
            global                    = $Global
            isRegex                   = $IsRegex
            allowKeyword              = $AllowKeyword
            direction                 = $Direction
            priority                  = $Priority
            timedUrl                  = $TimedUrl
            currentPolicyBeingEdited  = $PolicyId
            startPort                 = $StartPort
            endPort                   = $EndPort
            doMalwareScan             = $DoMalwareScan
            doDlpScan                 = $DoDlpScan
            doFileChecks              = $DoFileChecks
            overrideZeroTrust         = $OverrideZeroTrust
            sslBypass                 = $SslBypass
            urlFieldType              = $UrlFieldType
            applyKeywordAndSafeSearch = $ApplyKeywordAndSafeSearch

            url                       = $Url
            note                      = $Note
            weight                    = $Weight
        }

        if ($PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') -ne 'SilentlyContinue') {
            Write-Verbose "Adding Allow List Entry: $Url"
            Write-Verbose "Payload Preview: $($Payload | ConvertTo-Json -Compress)"
        }

        return Invoke-iBossRequest -Service Gateway -Uri $Uri -Method PUT -Body $Payload
    }
}