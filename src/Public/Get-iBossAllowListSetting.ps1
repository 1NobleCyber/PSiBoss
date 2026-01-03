function Get-iBossAllowListSetting {
    <#
    .SYNOPSIS
        Retrieves the global settings for the Allow List (e.g., enabled status).
    .PARAMETER PolicyId
        The ID of the policy being edited. Defaults to 1.
    #>
    [CmdletBinding()]
    param(
        [int]$PolicyId = 1
    )

    process {
        $Uri = "/json/controls/allowList/settings?currentPolicyBeingEdited=$PolicyId"
        return Invoke-iBossRequest -Service Gateway -Uri $Uri -Method GET
    }
}