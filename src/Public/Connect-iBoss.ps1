function Connect-iBoss {
    <#
    .SYNOPSIS
        Connects to the iBoss Cloud Gateway and captures Session/XSRF tokens.
    #>
    [CmdletBinding(DefaultParameterSetName = 'BasicAuth')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'BasicAuth')]
        [PSCredential]$Credential,

        [Parameter(Mandatory = $true, ParameterSetName = 'ApiToken')]
        [string]$ApiToken,

        [Parameter(Mandatory = $false, ParameterSetName = 'ApiToken')]
        [string]$ApiUsername,

        [Parameter(Mandatory = $false, ParameterSetName = 'BasicAuth')]
        [string]$TOTP,

        [Parameter(Mandatory = $false, ParameterSetName = 'BasicAuth')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ApiToken')]
        [switch]$NoWelcome

    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ApiToken') {
            $FormattedToken = "Bearer $ApiToken"
            $CookieString = ""
            $XsrfToken = $null

            # Initialize Session
            $Global:iBossSession = @{
                AuthToken   = $FormattedToken
                Cookies     = $CookieString
                XsrfToken   = $XsrfToken
                Domains     = @{}
                Context     = @{}
                ApiUsername = $ApiUsername
            }

            if ($PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') -ne 'SilentlyContinue') {
                Write-Verbose "--- [STEP 1: LOGIN] ---"
                Write-Verbose "Skipped credential login. Using provided API Bearer token."
            }
        }
        else {
            # Get Token & Cookies
            $LoginUri = "/ibossauth/web/tokens?ignoreAuthModule=true"
            if (![string]::IsNullOrWhiteSpace($TOTP)) {
                $LoginUri += "&totpCode=$TOTP"
            }
            
            $FullLoginUrl = "https://accounts.iboss.com$LoginUri"

            # Basic Auth
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

            # MFA Check
            if ($WebResponse.StatusCode -ge 400) {
                Write-Warning "Login Failed with Status Code: $($WebResponse.StatusCode)"
                if ($WebResponse.Content -match "MULTIFACTOR_CREDENTIALS_REQUIRED") {
                    throw "Login Failed: Multi-Factor Authentication is required. Please run Connect-iBoss with -TOTP."
                }
                if ($WebResponse.Content) { throw "iBoss returned error: $($WebResponse.Content)" }
                throw "Login failed (Status $($WebResponse.StatusCode))"
            }

            # Parse Token
            $TokenObj = $WebResponse.Content | ConvertFrom-Json
            $RawToken = if ($TokenObj.token) { $TokenObj.token } else { $TokenObj }
            $FormattedToken = "Token $RawToken"

            # Parse Cookies
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
        }

        # Get Account info
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

        # Get Cloud Nodes
        Write-Verbose "Step 3: Discovering Primary Gateway via Cloud Nodes..."
        
        try {
            $CloudNodes = Invoke-iBossRequest -Service Core -Uri "/ibcloud/web/cloudNodes?accountSettingsId=$AccId" -Verbose:$VerbosePreference -ErrorAction Stop
        }
        catch {
            throw "Failed at Step 3 (Get Cloud Nodes). Error: $_"
        }

        # Save Cloud Nodes to Session
        $Global:iBossSession.CloudNodes = $CloudNodes

        # Filter: Find the object where "primaryNode" equals 1
        $NodesArray = @($CloudNodes) # Ensure it's an array even if 1 result
        $PrimaryNode = $NodesArray | Where-Object { $_.primaryNode -eq 1 } | Select-Object -First 1

        if (-not $PrimaryNode) {
            Write-Warning "No node marked as 'primaryNode=1' found. Using first available node with a DNS entry."
            $PrimaryNode = $NodesArray | Where-Object { $_.masterAdminInterfaceDns } | Select-Object -First 1
        }

        if ($PrimaryNode -and $PrimaryNode.masterAdminInterfaceDns) {
            $GatewayDns = $PrimaryNode.masterAdminInterfaceDns
            $GatewayVersion = $PrimaryNode.currentFirmwareVersion
            $SwgUrl = $PrimaryNode.publicUrl
        }

        else {
            throw "Could not identify a Primary Gateway DNS (looking for property 'masterAdminInterfaceDns')."
        }

        # Save to Session
        $Global:iBossSession.Domains['Gateway'] = "https://$GatewayDns"
        $Global:iBossSession.GatewayVersion = $GatewayVersion

        # Find Reporting Node
        $ReportingNodeObj = $null
        
        # Check for explicit Reporting Node in CloudNodes
        $ReportingNodeObj = $NodesArray | Where-Object { 
            ($_.productFamily -eq 'reports') -or ($_.description -eq 'Reporter') 
        } | Select-Object -First 1

        if ($ReportingNodeObj) {
            $ReportingDns = $ReportingNodeObj.masterAdminInterfaceDns
            Write-Verbose "Reporting Node Detected (via productFamily='reports'): $ReportingDns"
            $Global:iBossSession.Domains['Reporting'] = "https://$ReportingDns"
        }
        else {
            # Fallback - Should not happen
            Write-Verbose "No dedicated Reporting Node found. Using Primary Gateway for reporting."
            $Global:iBossSession.Domains['Reporting'] = "https://$GatewayDns"
        }


        # Get Web Categories
        if ($SwgUrl) {
            if ($PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') -ne 'SilentlyContinue') {
                Write-Verbose "Step 4: Fetching Web Categories from $SwgUrl..."
            }
            
            $CatUri = "${SwgUrl}common/lookup/mainWebCategories.json?tcm=$GatewayVersion"
            
            # Build headers for this request
            $CatHeaders = @{
                "Authorization" = $FormattedToken
                "User-Agent"    = "ibossAPI"
                "Content-Type"  = "application/json;charset=UTF-8"
            }
            if ($CookieString) { $CatHeaders['Cookie'] = $CookieString }
            if ($XsrfToken) { $CatHeaders['X-XSRF-TOKEN'] = $XsrfToken }

            try {
                $CatResponse = Invoke-RestMethod -Uri $CatUri -Method GET -Headers $CatHeaders -ErrorAction Stop
                
                # Store simple objects (id, defaultText)
                $Global:iBossSession.WebCategories = $CatResponse | Select-Object id, defaultText
                
                if ($PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') -ne 'SilentlyContinue') {
                    Write-Verbose "Retrieved $($Global:iBossSession.WebCategories.Count) Web Categories."
                }
            }
            catch {
                Write-Warning "Failed to fetch Web Categories: $_"
            }
        }

        if (-not $NoWelcome) {
            Write-Host "Connected to iBoss Cloud Gateway!" -ForegroundColor Green
        }

        Write-Verbose "Primary Node Detected: $GatewayDns"
    }
}
