function Add-iBossAllowList {
    <#
    .SYNOPSIS
        Adds a URL to the iBoss Allow List.
    .PARAMETER Url
        The domain or URL to allow (e.g., "example.com").
    .PARAMETER Note
        Optional comment for this entry.
    .PARAMETER Weight
        The priority weight. Default is 501.
    .PARAMETER PolicyId
        The policy ID to apply this to. Default is 1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Url,

        [string]$Note = "",

        [int]$Weight = 501,

        [int]$PolicyId = 1
    )

    process {
        $Uri = "/json/controls/allowList?currentPolicyBeingEdited=$PolicyId"

        # Construct body
        $Payload = @{
            applyKeywordAndSafeSearch = 0
            direction                 = 2
            endPort                   = 0
            global                    = 0
            isRegex                   = 0
            isTimedUrl                = 0
            note                      = $Note
            priority                  = 0
            startPort                 = 0
            timedUrl                  = 0
            url                       = $Url
            weight                    = $Weight
        }

        if ($PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') -ne 'SilentlyContinue') {
            Write-Verbose "Adding Allow List Entry: $Url (Weight: $Weight)"
        }

        return Invoke-iBossRequest -Service Gateway -Uri $Uri -Method PUT -Body $Payload
    }
}