function Invoke-iBossRequest {
    <#
    .SYNOPSIS
        Internal helper to execute iBoss API calls.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Authentication', 'Core', 'Gateway', 'Reporting')]
        [string]$Service,

        [ValidateSet('GET', 'POST', 'PUT', 'DELETE', 'PATCH')]
        [string]$Method = 'GET',

        [object]$Body,
        [hashtable]$Headers = @{}
    )

    # Base URL
    $BaseUrl = $null

    if ($Service -eq 'Authentication') {
        $BaseUrl = "https://accounts.iboss.com"
    }
    elseif ($Service -eq 'Core') {
        $BaseUrl = "https://api.ibosscloud.com"
    }
    else {
        if (-not $Global:iBossSession.Domains.$Service) {
            throw "Cannot find base URL for '$Service'. You must run Connect-iBoss first."
        }
        $BaseUrl = $Global:iBossSession.Domains.$Service
    }

    $CleanUri = $Uri.TrimStart('/')
    $FullUri = "$BaseUrl/$CleanUri"

    # Build Headers
    $ReqHeaders = @{
        "User-Agent"    = "ibossAPI"
        "Authorization" = $Global:iBossSession.AuthToken
        "Content-Type"  = "application/json;charset=UTF-8"
    }

    # Inject Cookies
    if ($Global:iBossSession.Cookies) {
        $ReqHeaders['Cookie'] = $Global:iBossSession.Cookies
    }
    # Inject XSRF Header
    if ($Global:iBossSession.XsrfToken) {
        $ReqHeaders['X-XSRF-TOKEN'] = $Global:iBossSession.XsrfToken
    }

    # Add any extra headers passed (overwriting defaults if necessary)
    foreach ($Key in $Headers.Keys) {
        $ReqHeaders[$Key] = $Headers[$Key]
    }

    # Verbose Logging
    if ($PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') -ne 'SilentlyContinue') {
        Write-Verbose "--- [REQUEST] $Method $FullUri ---"
        
        $LogHeaders = $ReqHeaders.Clone()
        if ($LogHeaders["Authorization"]) { $LogHeaders["Authorization"] = "Token ****(Masked)****" }
        Write-Verbose "Headers: $($LogHeaders | ConvertTo-Json -Compress)"
        
        if ($Body) { 
            Write-Verbose "Body: $( $Body | ConvertTo-Json -Depth 5 -Compress )" 
        }
    }

    # Execute
    $Params = @{
        Uri         = $FullUri
        Method      = $Method
        Headers     = $ReqHeaders
        ContentType = "application/json;charset=UTF-8"
    }

    if ($Body) {
        $Params.Body = ($Body | ConvertTo-Json -Depth 10 -Compress)
    }

    try {
        $Response = Invoke-RestMethod @Params
        
        if ($PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') -ne 'SilentlyContinue') {
            Write-Verbose "--- [RESPONSE] ---"
            Write-Verbose ($Response | ConvertTo-Json -Depth 5)
        }

        return $Response
    }
    catch {
        Write-Error "API Call Failed: $_"
        if ($PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') -ne 'SilentlyContinue') {
            try {
                if ($_.Exception.Response -and $_.Exception.Response.Content) {
                    $Reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                    Write-Verbose "--- [ERROR BODY] ---"
                    Write-Verbose $Reader.ReadToEnd()
                }
            } catch {}
        }
        throw $_
    }
}