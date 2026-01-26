function Get-iBossBlockList {
    <#
    .SYNOPSIS
        Retrieves the 'Block List' controls from the iBoss Gateway with pagination support.

    .DESCRIPTION
        Retrieves the Block List entries.
        By default, this returns the first 20 entries.
        Use the -All switch to automatically retrieve the full list.

    .PARAMETER PolicyId
        The ID of the policy being edited. Defaults to 1 (Global/Default).

    .PARAMETER All
        If specified, performs an initial query to find the total count, 
        then performs a second query to retrieve all items at once.
        Overrides CurrentRow and MaxItems.

    .PARAMETER CurrentRow
        The starting offset (0-based index) for pagination. Default is 0.

    .PARAMETER MaxItems
        The number of items to retrieve per page. Default is 20.

    .PARAMETER DomainFilter
        A search string to filter the results by domain name server-side.

    .EXAMPLE
        Get-iBossBlockList -All
        # Returns every entry in the list.

    .EXAMPLE
        Get-iBossBlockList -MaxItems 50 -CurrentRow 100
        # Returns entries 101 to 150.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [int]$PolicyId = 1,

        [Parameter(ParameterSetName = 'All')]
        [switch]$All,

        [Parameter(ParameterSetName = 'Default')]
        [int]$CurrentRow = 0,

        [Parameter(ParameterSetName = 'Default')]
        [int]$MaxItems = 20,

        [string]$DomainFilter = ""
    )

    process {
        $BaseUri = "/json/controls/blockList?currentPolicyBeingEdited=$PolicyId&domainFilter=$([uri]::EscapeDataString($DomainFilter))"
        
        # --- Logic for -All Switch ---
        if ($All) {
            Write-Verbose "Mode: ALL. Querying metadata to determine total count..."
            
            # Initial "Ping" query to get the count (fetching 1 item is enough)
            $MetaUri = "$BaseUri&currentRow=0&maxItems=1"
            $MetaResponse = Invoke-iBossRequest -Service Gateway -Uri $MetaUri -Method GET
            
            # Depending on iBoss version, the property is usually 'count' or 'total'
            $TotalCount = if ($MetaResponse.count) { $MetaResponse.count } else { $MetaResponse.total }
            
            if (-not $TotalCount) {
                Write-Warning "Could not determine total count from API. Returning default page."
                $TotalCount = 20
            }
            else {
                Write-Verbose "Total items found: $TotalCount. Retrieving all..."
            }

            # Set parameters for the "Big" query
            $ReqRow = 0
            $ReqMax = $TotalCount
        }
        else {
            # Standard Pagination
            $ReqRow = $CurrentRow
            $ReqMax = $MaxItems
        }

        # --- Execute Final Query ---
        $FinalUri = "$BaseUri&currentRow=$ReqRow&maxItems=$ReqMax"
        
        if ($PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference') -ne 'SilentlyContinue') {
            Write-Verbose "Fetching: Offset $ReqRow, Limit $ReqMax"
        }

        $Response = Invoke-iBossRequest -Service Gateway -Uri $FinalUri -Method GET
        
        # Return just the entries array as requested
        return $Response.entries
    }
}
