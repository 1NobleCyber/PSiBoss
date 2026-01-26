function Remove-iBossBlockList {
    <#
    .SYNOPSIS
        Removes a URL from the iBoss Block List.
    .PARAMETER Url
        The domain or URL to remove.
    .PARAMETER PolicyId
        The policy ID to target. Default is 1.
    .PARAMETER Direction
        Mandatory
    .PARAMETER StartPort
        Default: 0
    .PARAMETER EndPort
        Default: 0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Url,

        [Parameter(ValueFromPipelineByPropertyName)]
        [int]$PolicyId = 1,
        
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [int]$Direction,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Nullable[int]]$StartPort,
        [Parameter(ValueFromPipelineByPropertyName)]
        [Nullable[int]]$EndPort

    )


    process {
        # Logic for null ports
        if (-not $StartPort) { $StartPort = 0 }
        if (-not $EndPort) { $EndPort = 0 }

        $Uri = "/json/controls/blockList?currentPolicyBeingEdited=$PolicyId"

        $Payload = @{
            currentPolicyBeingEdited = $PolicyId
            startPort                = $StartPort
            endPort                  = $EndPort
            direction                = $Direction
            url                      = $Url
        }

        if ($PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') -ne 'SilentlyContinue') {
            Write-Verbose "Removing Block List Entry: $Url"
            Write-Verbose "Payload: $($Payload | ConvertTo-Json -Compress)"
        }

        $Response = Invoke-iBossRequest -Service Gateway -Uri $Uri -Method DELETE -Body $Payload
        
        if ($Response -and $Response -is [System.Management.Automation.PSCustomObject]) {
            $Response | Add-Member -MemberType NoteProperty -Name "url" -Value $Url -Force
        }

        return $Response

    }

}
