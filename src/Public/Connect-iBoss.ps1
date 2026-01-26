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
        [string]$TOTP,

        [Parameter(Mandatory = $false)]
        [switch]$NoWelcome

    )

    process {
        # --- STEP 1: LOGIN (Get Token & Cookies) ---
        $LoginUri = "/ibossauth/web/tokens?ignoreAuthModule=true"
        if (![string]::IsNullOrWhiteSpace($TOTP)) {
            $LoginUri += "&totpCode=$TOTP"
        }
        
        $FullLoginUrl = "https://accounts.iboss.com$LoginUri"

        # Generate Basic Auth (ISO-8859-1)
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

        # --- ERROR HANDLING & MFA CHECK ---
        if ($WebResponse.StatusCode -ge 400) {
            Write-Warning "Login Failed with Status Code: $($WebResponse.StatusCode)"
            if ($WebResponse.Content -match "MULTIFACTOR_CREDENTIALS_REQUIRED") {
                throw "Login Failed: Multi-Factor Authentication is required. Please run Connect-iBoss with -TOTP."
            }
            if ($WebResponse.Content) { throw "iBoss returned error: $($WebResponse.Content)" }
            throw "Login failed (Status $($WebResponse.StatusCode))"
        }

        # --- PARSE TOKEN ---
        $TokenObj = $WebResponse.Content | ConvertFrom-Json
        $RawToken = if ($TokenObj.token) { $TokenObj.token } else { $TokenObj }
        $FormattedToken = "Token $RawToken"

        # --- PARSE COOKIES ---
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

        # --- STEP 2: GET ACCOUNT CONTEXT ---
        Write-Verbose "Step 2: Retrieving Account Context..."
        try {
            $MySettings = Invoke-iBossRequest -Service Core -Uri "/ibcloud/web/users/mySettings" -Verbose:$VerbosePreference -ErrorAction Stop
        }
        catch {
            throw "Failed at Step 2 (Get Account Context). Error: $_"
        }
        $Global:iBossSession.Context = $MySettings
        
        # Get Account ID
        $AccId = $MySettings.accountSettingsId
        if (-not $AccId) { $AccId = $MySettings.id }

        # --- STEP 3: GET CLOUD NODES (Updated Logic) ---
        Write-Verbose "Step 3: Discovering Primary Gateway via Cloud Nodes..."
        
        try {
            # We use the Core service to hit api.ibosscloud.com/ibcloud/web/cloudNodes
            $CloudNodes = Invoke-iBossRequest -Service Core -Uri "/ibcloud/web/cloudNodes?accountSettingsId=$AccId" -Verbose:$VerbosePreference -ErrorAction Stop
        }
        catch {
            throw "Failed at Step 3 (Get Cloud Nodes). Error: $_"
        }

        # Filter: Find the object where "primaryNode" equals 1
        $NodesArray = @($CloudNodes) # Ensure it's an array even if 1 result
        $PrimaryNode = $NodesArray | Where-Object { $_.primaryNode -eq 1 } | Select-Object -First 1

        if (-not $PrimaryNode) {
            # Fallback safety: If no explicit primary is marked, grab the first one that has a DNS name
            Write-Warning "No node marked as 'primaryNode=1' found. Using first available node with a DNS entry."
            $PrimaryNode = $NodesArray | Where-Object { $_.masterAdminInterfaceDns } | Select-Object -First 1
        }

        if ($PrimaryNode -and $PrimaryNode.masterAdminInterfaceDns) {
            $GatewayDns = $PrimaryNode.masterAdminInterfaceDns
            $GatewayVersion = $PrimaryNode.currentFirmwareVersion
        }

        else {
            throw "Could not identify a Primary Gateway DNS (looking for property 'masterAdminInterfaceDns')."
        }

        # Save to Session
        $Global:iBossSession.Domains['Gateway'] = "https://$GatewayDns"
        $Global:iBossSession.Domains['Reporting'] = "https://$GatewayDns"
        $Global:iBossSession.GatewayVersion = $GatewayVersion

        if (-not $NoWelcome) {
            Write-Host "Connected to iBoss Cloud Gateway!" -ForegroundColor Green
        }

        Write-Verbose "Primary Node Detected: $GatewayDns"
    }
}