function Get-iBossAllowList {
    <#
    .SYNOPSIS
        Retrieves the 'Allow List' controls from the iBoss Gateway.

    .DESCRIPTION
        Retrieves the Allow List using the Gateway API.

    .PARAMETER PolicyId
        The ID of the policy being edited. Defaults to 1.

    .EXAMPLE
        Get-iBossAllowList
    #>
    [CmdletBinding()]
    param(
        [int]$PolicyId = 1
    )

    process {
        $Uri = "/json/controls/allowList?currentPolicyBeingEdited=$PolicyId"

        Write-Verbose "Retrieving Allow List for Policy ID: $PolicyId"

        $Response = Invoke-iBossRequest -Service Gateway -Uri $Uri -Method GET
        
        return $Response
    }
}