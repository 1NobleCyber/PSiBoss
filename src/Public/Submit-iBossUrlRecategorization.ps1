function Submit-iBossUrlRecategorization {
    <#
    .SYNOPSIS
        Submits a URL for recategorization.

    .DESCRIPTION
        This function first retrieves the current categorization of the URL to get the 
        bitmask, converts it to an array, and submits it along with a user note.

    .PARAMETER Url
        The URL to recategorize.

    .PARAMETER Note
        The reason or suggested category for recategorization.

    .EXAMPLE
        Submit-iBossUrlRecategorization -Url "testing.com" -Note "Should be Tech"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$Note
    )

    process {
        # 1. Lookup Current Categories
        
        if ($PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') -ne 'SilentlyContinue') {
            Write-Verbose "Step 1: Looking up current categories for $Url..."
        }

        if ($PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') -ne 'SilentlyContinue') {
            Write-Verbose "Step 1: Looking up current categories for $Url..."
        }

        $Lookup = Get-iBossURLLookup -Url $Url

        
        $CatString = $Lookup.categories
        if (-not $CatString) { 
            throw "Could not retrieve 'categories' bitmask for $Url. Recategorization requires this data." 
        }

        # 2. Convert Bitmask String to Integer Array
        $CatArray = $CatString.ToCharArray() | ForEach-Object { [int][string]$_ }
        
        if ($PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') -ne 'SilentlyContinue') {
            Write-Verbose "Step 2: Converted bitmask (Length: $($CatArray.Count)) to array."
        }

        # 3. Submit Recategorization
        $SubmitPayload = @{
            url        = $Url
            categories = $CatArray
            note       = $Note
        }
        
        if ($PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') -ne 'SilentlyContinue') {
            Write-Verbose "Step 3: Submitting recategorization request..."
        }

        $Response = Invoke-iBossRequest -Service Gateway -Uri "/json/controls/urlLookup/recatSite" -Method POST -Body $SubmitPayload
        
        return $Response
    }
}
