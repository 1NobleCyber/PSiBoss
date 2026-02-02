function Get-iBossLogIcon {
    <#
    .SYNOPSIS
        Retrieves the icon (favicon/logo) for a domain from iBoss.

    .DESCRIPTION
        Downloads the domain logo from the iBoss Reporting Service.
        The service typically converts icons to PNG format.
        Calculates SHA256 hash and extracts image dimensions.

    .PARAMETER Domain
        The domain name to lookup (e.g., google.com).

    .PARAMETER OutFile
        Optional path to save the downloaded image file.

    .EXAMPLE
        $Icon = Get-iBossLogIcon -Domain "google.com"
        $Icon | Format-List
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Domain,

        [Parameter(Mandatory = $false)]
        [string]$OutFile
    )

    process {
        if (-not $Global:iBossSession) {
            throw "Not connected. Please run Connect-iBoss first."
        }

        # 1. Construct Request
        $Url = "$($Global:iBossSession.Domains['Reporting'])/ibreports/web/lookup/domain/logo?domain=$Domain"
        
        $Headers = @{
            "Authorization" = $Global:iBossSession.AuthToken
            "User-Agent"    = "ibossAPI"
        }
        if ($Global:iBossSession.Cookies) {
            $Headers['Cookie'] = $Global:iBossSession.Cookies
        }

        Write-Verbose "Downloading icon from: $Url"

        try {
            $Response = Invoke-WebRequest -Uri $Url -Headers $Headers -Method GET -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to download icon for $Domain : $_"
            return
        }

        if ($Response.StatusCode -ne 200) {
            Write-Error "Failed to Retrieve Icon. Status: $($Response.StatusCode)"
            return
        }

        $Bytes = $Response.Content
        if (-not $Bytes -or $Bytes.Length -eq 0) {
            Write-Warning "Icon retrieved but content is empty."
            return
        }

        # 2. Determine File Type (Magic Bytes)
        $HexHead = ($Bytes[0..7] | ForEach-Object { $_.ToString("X2") }) -join ""
        $FileType = "Unknown"
        
        if ($HexHead -match "^89504E47") { $FileType = "PNG" }
        elseif ($HexHead -match "^00000100") { $FileType = "ICO" }
        elseif ($HexHead -match "^3C3F786D") { $FileType = "SVG" } 
        elseif ($HexHead -match "^3C737667") { $FileType = "SVG" } 

        # 3. Hash Calculation
        # SHA256
        $SHA256 = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($Bytes)) -replace "-"

        # 4. Dimensions Parsing (Lightweight)
        $Dimensions = "Unknown"
        try {
            if ($FileType -eq "PNG") {
                # IHDR chunk starts at byte 12. Width at 16, Height at 20 (4 bytes each, Big Endian)
                if ($Bytes.Length -ge 24) {
                    $WBytes = [byte[]]$Bytes[16..19]
                    $W = [BitConverter]::ToUInt32($WBytes, 0)
                    $W = [System.Net.IPAddress]::NetworkToHostOrder([int]$W)
                    
                    $HBytes = [byte[]]$Bytes[20..23]
                    $H = [BitConverter]::ToUInt32($HBytes, 0)
                    $H = [System.Net.IPAddress]::NetworkToHostOrder([int]$H)
                    
                    $Dimensions = "$W x $H"
                }
            }
            elseif ($FileType -eq "ICO") {
                # Directory Entry starts at byte 6. Width at 6, Height at 7 (1 byte each). 0 means 256.
                if ($Bytes.Length -ge 8) {
                    $W = $Bytes[6]; if ($W -eq 0) { $W = 256 }
                    $H = $Bytes[7]; if ($H -eq 0) { $H = 256 }
                    $Dimensions = "$W x $H"
                }
            }
        }
        catch {
            Write-Verbose "Failed to parse dimensions: $_"
        }

        # 5. Output Object
        $Result = [PSCustomObject]@{
            Domain     = $Domain
            Size       = $Bytes.Length
            FileType   = $FileType
            Dimensions = $Dimensions
            SHA256     = $SHA256
            Bytes      = $Bytes
        }

        # Save to file if requested
        if ($OutFile) {
            try {
                if (-not [System.IO.Path]::IsPathRooted($OutFile)) {
                    $OutFile = Join-Path (Get-Location) $OutFile
                }
                [System.IO.File]::WriteAllBytes($OutFile, $Bytes)
                Write-Verbose "Saved icon to $OutFile"
            }
            catch {
                Write-Error "Failed to save file: $_"
            }
        }

        return $Result
    }
}
