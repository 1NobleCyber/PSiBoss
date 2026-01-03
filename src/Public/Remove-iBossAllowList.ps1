function Remove-iBossAllowList {
    <#
    .SYNOPSIS
        Removes a URL from the iBoss Allow List.
    .PARAMETER Url
        The domain or URL to remove.
    .PARAMETER PolicyId
        The policy ID to target. Default is 1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Url,

        [int]$PolicyId = 1
    )

    process {
        # Escape the URL parameter
        $EncodedUrl = [uri]::EscapeDataString($Url)
        
        $Uri = "/json/controls/allowList?currentPolicyBeingEdited=$PolicyId&url=$EncodedUrl"

        if ($PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') -ne 'SilentlyContinue') {
            Write-Verbose "Removing Allow List Entry: $Url"
        }

        return Invoke-iBossRequest -Service Gateway -Uri $Uri -Method DELETE
    }
}