@{
    RootModule = 'PSiBoss.psm1'
    ModuleVersion = '0.0.1'
    GUID = 'c6b7fbc4-0527-4d2b-9513-7fc606f8b079'
    Author = 'David Crawford'
    CompanyName = 'Unknown'
    Copyright = 'Unlicense license'
    Description = 'A PowerShell module for managing the iBoss Cloud Gateway via REST API.'
    PowerShellVersion = '5.1'
    RequiredModules = @()
    RequiredAssemblies = @()
    ScriptsToProcess = @()
    TypesToProcess = @()
    FormatsToProcess = @()

    # TODO: Do not use wildcards in actual version
    # During dev, we use '*' so I don't have to update this file every time we add a command.
    # Will control visibility inside the .psm1 file instead.
    FunctionsToExport = '*'
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('iBoss', 'Security', 'REST', 'API')

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/1NobleCyber/PSiBoss#Unlicense-1-ov-file'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/1NobleCyber/PSiBoss'
        }
    }
}