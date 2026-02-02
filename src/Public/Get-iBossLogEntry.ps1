function Get-iBossLogEntry {
    <#
    .SYNOPSIS
        Retrieves log entries from the iBoss Cloud Reporting Service.
    
    .DESCRIPTION
        Queries the iBoss Reporting API for log entries. It dynamically calculates the appropriate 
        table name (based on the provided StartTime) and supports filtering by user, IP, and more.
    
    .PARAMETER StartTime
        The start time for the query.
    
    .PARAMETER EndTime
        The end time for the query. Defaults to the current time.
    
    .PARAMETER Filter
        A general filter string.
    
    .PARAMETER UserName
        Filter logs by a specific username.
    
    .PARAMETER SourceIp
        Filter logs by Source IP Address.
    
    .PARAMETER Limit
        The maximum number of items to return. Default is 100.
    
    .PARAMETER LogType
        The base log type name (e.g. 'url_log_entry'). 
        The actual table name queried will be suffix-appended with the date (e.g. url_log_entry_01262026).
    
    .PARAMETER EventLogType
        Specifies the type of log entry to retrieve. 
        Valid values: 'All', 'Access', 'UserActivity', 'ConnectionError', 'Search', 'ZTNA', 'SDWAN', 'DNS', 'ConnectorRegistration', 'ZTNAPeerRegistration', 'SoftOverride', 'Audit'.


        
    .EXAMPLE
        Get-iBossLogEntry -StartTime (Get-Date).AddMinutes(-30) -UserName "Jane.Doe1"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [DateTime]$StartTime,

        [Parameter(Mandatory = $false)]
        [DateTime]$EndTime = (Get-Date),

        [Parameter(Mandatory = $false)]
        [string]$Filter,

        [Parameter(Mandatory = $false)]
        [string]$UserName,

        [Parameter(Mandatory = $false)]
        [string]$SourceIp,

        [Parameter(Mandatory = $false)]
        [int]$Limit = 100,

        [Parameter(Mandatory = $false)]
        [string]$LogType = "url_log_entry",

        [Parameter(Mandatory = $false)]
        [ValidateSet('All', 'Access', 'UserActivity', 'ConnectionError', 'Search', 'ZTNA', 'SDWAN', 'DNS', 'ConnectorRegistration', 'ZTNAPeerRegistration', 'SoftOverride', 'Audit')]
        [string]$EventLogType = 'All'

    )

    process {
        # 1. Validation
        if (-not $Global:iBossSession) {
            throw "Not connected. Please run Connect-iBoss first."
        }

        # 2. Convert Dates to Epoch Milliseconds
        $StartEpoch = [int64](($StartTime.ToUniversalTime() - [DateTime]::Parse("1970-01-01")).TotalMilliseconds)
        $EndEpoch = [int64](($EndTime.ToUniversalTime() - [DateTime]::Parse("1970-01-01")).TotalMilliseconds)

        # 3. Get and Filter Tables
        Write-Verbose "Retrieving available log tables..."
        
        # Determine LogFamily from LogType (e.g. url_log_entry -> url, ips_log -> ips)
        $LogFamily = $LogType.Split('_')[0]
        if ($LogFamily -notin @('url', 'ips', 'el')) {
            Write-Verbose "Could not determine standard LogFamily from '$LogType'. Defaulting to 'url'."
            $LogFamily = 'url'
        }

        $AllTables = Get-iBossLogTables -LogFamily $LogFamily

        # Filter tables that match the LogType and overlap with the time range
        $TargetTables = $AllTables | Where-Object {
            $TableLogType = $_.displayString -replace '_\d{8}$', '' # Remove date suffix to get type
            
            # 1. Match Log Type (exact match of prefix)
            $TypeMatch = $TableLogType -eq $LogType

            # 2. Check Time Overlap
            # Table End Time (if null, use current time)
            $TableEnd = if ($_.endDate) { $_.endDate } else { [DateTimeOffset]::Now.ToUnixTimeMilliseconds() }
            $TableStart = $_.startDate

            # Overlap: (StartA <= EndB) and (EndA >= StartB)
            $TimeMatch = ($StartEpoch -le $TableEnd) -and ($EndEpoch -ge $TableStart)

            $TypeMatch -and $TimeMatch
        }

        if (-not $TargetTables) {
            Write-Warning "No log tables found for LogType '$LogType' in the specified time range."
            return
        }

        Write-Verbose "Found $($TargetTables.Count) matching table(s): $($TargetTables.tableName -join ', ')"

        # 4. Map EventLogType to Query Parameters
        $TypeSettings = switch ($EventLogType) {
            'All' { @{ statusRecordType = '-1'; auditRecord = '-1'; noiseFilter = '-1'; isProxyError = '-1'; callout = '-1'; statusRecord = '-1' } }
            'Access' { @{ statusRecordType = '0'; auditRecord = '-1'; noiseFilter = '-1'; isProxyError = '-1'; callout = '-1'; statusRecord = '-1' } }
            'UserActivity' { @{ statusRecordType = '1'; auditRecord = '-1'; noiseFilter = '-1'; isProxyError = '-1'; callout = '-1'; statusRecord = '-1' } }
            'ConnectionError' { @{ statusRecordType = '-1'; auditRecord = '-1'; noiseFilter = '-1'; isProxyError = '1'; callout = '-1'; statusRecord = '-1' } }
            'Search' { @{ statusRecordType = '2'; auditRecord = '-1'; noiseFilter = '-1'; isProxyError = '-1'; callout = '-1'; statusRecord = '-1' } }
            'ZTNA' { @{ statusRecordType = '-1'; auditRecord = '-1'; noiseFilter = '-1'; isProxyError = '-1'; callout = '-1'; statusRecord = '2' } }
            'SDWAN' { @{ statusRecordType = '-1'; auditRecord = '-1'; noiseFilter = '-1'; isProxyError = '-1'; callout = '1'; statusRecord = '-1' } }
            'DNS' { @{ statusRecordType = '-1'; auditRecord = '-1'; noiseFilter = '2'; isProxyError = '-1'; callout = '-1'; statusRecord = '-1' } }
            'ConnectorRegistration' { @{ statusRecordType = '-1'; auditRecord = '-1'; noiseFilter = '3'; isProxyError = '-1'; callout = '-1'; statusRecord = '-1' } }
            'ZTNAPeerRegistration' { @{ statusRecordType = '-1'; auditRecord = '-1'; noiseFilter = '4'; isProxyError = '-1'; callout = '-1'; statusRecord = '-1' } }
            'SoftOverride' { @{ statusRecordType = '3'; auditRecord = '-1'; noiseFilter = '-1'; isProxyError = '-1'; callout = '-1'; statusRecord = '-1' } }
            'Audit' { @{ statusRecordType = '-1'; auditRecord = '0'; noiseFilter = '-1'; isProxyError = '-1'; callout = '-1'; statusRecord = '-1' } }
        }

        # 5. Build Base Query Parameters
        $BaseQueryParams = @{
            action                = ""
            addTag                = "true"
            auditRecord           = $TypeSettings['auditRecord']
            callout               = $TypeSettings['callout']
            caseInsensitive       = "false"
            categoryId            = "1000000" 
            currentLogEntryId     = "-1"
            currentLogTable       = ""
            currentRowNumber      = "1"
            email                 = ""
            endTimeMillies        = $EndEpoch
            externalSearchEnabled = "false"
            generatorId           = "-1"
            includeAllRecord      = "true"
            includeLogReports     = "true"
            isAdvancedSearch      = "true"
            isProxyError          = $TypeSettings['isProxyError']
            locale                = "en_US"
            localizeLogTime       = "true"
            logReductionType      = "0"
            maxItemsToReturn      = $Limit
            mitm                  = "-1"
            noiseFilter           = $TypeSettings['noiseFilter']
            orderAscending        = "false"
            priority              = "-1"
            proxyErrorWildcard    = "true"
            reportingGroup        = "-1"
            scrollForward         = "true"
            searchRiskType        = "-1"
            sortByCriteria        = "SORT_BY_ID"
            startTimeMillies      = $StartEpoch
            statusRecord          = $TypeSettings['statusRecord']
            statusRecordType      = $TypeSettings['statusRecordType']
            swgGateway            = "all"
            # tableName             = $TableName (Will be set in loop)
            tlsVersion            = "" 
            url                   = ""
            urlFilter             = "" 
            wildCard              = "false"
        }

        # Apply Optional Filters
        if (-not [string]::IsNullOrWhiteSpace($Filter)) {
            $BaseQueryParams['urlFilter'] = $Filter
        }
        
        if (-not [string]::IsNullOrWhiteSpace($UserName)) {
            $BaseQueryParams['username'] = $UserName
        }

        if (-not [string]::IsNullOrWhiteSpace($SourceIp)) {
            $BaseQueryParams['sourceIp'] = $SourceIp
        }

        # 6. Execute Queries for Each Table
        $AllResults = @()

        foreach ($Table in $TargetTables) {
            Write-Verbose "Querying table: $($Table.tableName)"
            
            # Clone params for this iteration
            $QueryParams = $BaseQueryParams.Clone()
            $QueryParams['tableName'] = $Table.tableName

            # Construct Query String
            $QueryString = ($QueryParams.Keys | ForEach-Object { 
                    "$($_)=$([Uri]::EscapeDataString($QueryParams[$_]))" 
                }) -join "&"

            $Uri = "/ibreports/web/log/url/entries?$QueryString"
            
            try {
                $Result = Invoke-iBossRequest -Service Reporting -Uri $Uri -Verbose:$VerbosePreference
                if ($Result) {
                    # Some APIs return the array directly, others wrap it. 
                    # Assuming array of entries based on previous logic.
                    $AllResults += $Result
                }
            }
            catch {
                Write-Warning "Failed to query table $($Table.tableName): $_"
            }
        }

        return $AllResults
    }
}
