function Connect-iBoss {
    <#
    .SYNOPSIS
        Connects to the iBoss Cloud Gateway and captures Session/XSRF tokens.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [PSCredential]$Credential,

        [Parameter(Mandatory = $false)]
        [string]$TOTP
    )

    process {
        # LOGIN - Get Token & Cookies
        $LoginUri = "/ibossauth/web/tokens?ignoreAuthModule=true"
        if (![string]::IsNullOrWhiteSpace($TOTP)) {
            $LoginUri += "&totpCode=$TOTP"
        }
        
        $FullLoginUrl = "https://accounts.iboss.com$LoginUri"

        # Generate Basic Auth
        $PlainAuth = "$($Credential.UserName):$($Credential.GetNetworkCredential().Password)"
        $Bytes = [System.Text.Encoding]::GetEncoding("ISO-8859-1").GetBytes($PlainAuth)
        $BasicAuth = [Convert]::ToBase64String($Bytes)

        if ($PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') -ne 'SilentlyContinue') {
            Write-Verbose "--- [STEP 1: LOGIN] ---"
            Write-Verbose "GET $FullLoginUrl"
        }

        try {
            $WebResponse = Invoke-WebRequest -Uri $FullLoginUrl `
                -Method GET `
                -Headers @{ 
                    "Authorization" = "Basic $BasicAuth"
                    "User-Agent"    = "ibossAPI"
                    "Accept"        = "application/json"
                } `
                -SkipHttpErrorCheck `
                -ErrorAction Stop
        }
        catch {
             throw "Network Connection Failed: $($_.Exception.Message)"
        }

        # ERROR HANDLING & MFA CHECK
        if ($WebResponse.StatusCode -ge 400) {
            Write-Warning "Login Failed with Status Code: $($WebResponse.StatusCode)"
            
            # Check for specific MFA requirement logic
            if ($WebResponse.Content -match "MULTIFACTOR_CREDENTIALS_REQUIRED") {
                throw "Login Failed: Multi-Factor Authentication is required for this account. Please run Connect-iBoss again using the -TOTP parameter."
            }

            if ($WebResponse.Content) { throw "iBoss returned error: $($WebResponse.Content)" }
            throw "Login failed (Status $($WebResponse.StatusCode))"
        }

        # PARSE TOKEN
        $TokenObj = $WebResponse.Content | ConvertFrom-Json
        $RawToken = if ($TokenObj.token) { $TokenObj.token } else { $TokenObj }
        $FormattedToken = "Token $RawToken"

        # PARSE COOKIES - Capture XSRF-TOKEN and JSESSIONID
        $CookieString = ""
        $XsrfToken = $null
        
        if ($WebResponse.Headers['Set-Cookie']) {
            $CookieArray = $WebResponse.Headers['Set-Cookie']
            if ($CookieArray -is [string]) { $CookieArray = @($CookieArray) }
            
            $CookieString = ($CookieArray -join ';')
            
            foreach ($Cookie in $CookieArray) {
                if ($Cookie -match 'XSRF-TOKEN=([^;]+)') {
                    $XsrfToken = $matches[1]
                }
            }
        }

        # Initialize Session
        $Global:iBossSession = @{
            AuthToken = $FormattedToken
            Cookies   = $CookieString
            XsrfToken = $XsrfToken
            Domains   = @{}
            Context   = @{}
        }

        Write-Verbose "Auth Token and Cookies acquired."
        if ($XsrfToken) { Write-Verbose "XSRF Token detected." }

        # GET CONTEXT & DOMAINS
        Write-Verbose "Step 2: Retrieving Account Context and Nodes..."
        
        try {
            $MySettings = Invoke-iBossRequest -Service Core -Uri "/ibcloud/web/users/mySettings" -Verbose:$VerbosePreference -ErrorAction Stop
        }
        catch {
            throw "Failed at Step 2 (Get Account Context). Error: $_"
        }
        
        $Global:iBossSession.Context = $MySettings
        
        if ($MySettings.defaultNodeCluster -and $MySettings.defaultNodeCluster.clusterFullDns) {
            $ClusterDns = $MySettings.defaultNodeCluster.clusterFullDns
            $Global:iBossSession.Domains['Gateway']   = "https://$ClusterDns"
            $Global:iBossSession.Domains['Reporting'] = "https://$ClusterDns"
        }
        else {
            throw "Could not find 'defaultNodeCluster.clusterFullDns' in the Account Context."
        }

        Write-Host "Connected to iBoss Cloud Gateway!" -ForegroundColor Green
        Write-Verbose "Gateway Node:   $($Global:iBossSession.Domains.Gateway)"
    }
}