function Add-iBossBlockList {
    <#
    .SYNOPSIS
        Adds a URL to the iBoss Block List.

    .PARAMETER Url
        The domain or URL to block (e.g., "example.com").
    .PARAMETER Note
        Optional comment for this entry.
    .PARAMETER PolicyId
        The policy ID to apply this to. Default is 1.
    .PARAMETER Global
        Default: 0
    .PARAMETER IsRegex
        Default: 0
    .PARAMETER Direction
        Default: 2
    .PARAMETER Priority
        Default: 0
    .PARAMETER StartPort
        Default: null (Rendered as literal JSON null)
    .PARAMETER EndPort
        Default: null (Rendered as literal JSON null)
    .PARAMETER UrlFieldType
        Default: 0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Url,
        [string]$Note = "",

        [int]$PolicyId = 1,
        [int]$Global = 0,
        [int]$IsRegex = 0,
        [int]$Direction = 2,
        [int]$Priority = 0,
        [Nullable[int]]$StartPort = $null,
        [Nullable[int]]$EndPort = $null,
        [int]$UrlFieldType = 0
    )

    process {
        $Uri = "/json/controls/blockList?currentPolicyBeingEdited=$PolicyId"

        $Payload = @{
            global                   = $Global
            isRegex                  = $IsRegex
            direction                = $Direction
            priority                 = $Priority
            currentPolicyBeingEdited = $PolicyId
            startPort                = $StartPort
            endPort                  = $EndPort
            urlFieldType             = $UrlFieldType
            url                      = $Url
            note                     = $Note
        }

        if ($PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') -ne 'SilentlyContinue') {
            Write-Verbose "Adding Block List Entry: $Url"
            Write-Verbose "Payload Preview: $($Payload | ConvertTo-Json -Compress)"
        }

        return Invoke-iBossRequest -Service Gateway -Uri $Uri -Method PUT -Body $Payload
    }
}
