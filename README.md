# PSiBoss

**PSiBoss** is a PowerShell module designed to facilitate authentication and seamless interactions with the **iBoss Cloud Gateway REST API**. It allows administrators and security teams to automate gateway management, URL classification, allow/block lists, asset tracking, and log retrieval.

## Features

- **Authentication Handling**: Easily authenticate and manage API session tokens with `Connect-iBoss` (supports Multi-Factor Authentication/TOTP).
- **List Management**: Programmatically add, retrieve, or remove domains and IPs from your Allow/Block lists.
- **Log and Report Management**: Fetch log entries and log tables to analyze traffic and threats dynamically.
- **Asset Discovery**: Query and retrieve counts and details of devices (assets) connected to your iBoss environment.
- **URL Classification**: Check category mappings with `Get-iBossURLLookup` and submit recategorization requests natively.

## Installation

Currently, this module can be installed locally from the repository.

```powershell
# Clone the repository
git clone https://github.com/1NobleCyber/PSiBoss.git

# Navigate to the project directory
cd PSiBoss

# Import the module
Import-Module .\src\PSiBoss.psd1 -Verbose
```

## Getting Started

First, you'll need to authenticate to your iBoss instance using `Connect-iBoss`.

```powershell
# Prompt for credentials
$cred = Get-Credential

# Connect to iBoss (Standard Auth)
Connect-iBoss -Credential $cred

# Connect to iBoss (With MFA / TOTP)
Connect-iBoss -Credential $cred -TOTP "123456"
```

## Usage Examples

### Retrieve Current Assets
```powershell
# Get a list of the latest 10 assets
Get-iBossAsset -Count 10
```

### Manage Allow/Block Lists
```powershell
# Add a domain to the block list
Add-iBossBlockList -Domain "malicious-site.com"

# View the current block list
Get-iBossBlockList
```

### Perform URL Lookups
```powershell
# Check the category of a specific URL
Get-iBossURLLookup -Url "https://example.com"
```

### Fetch Log Entries
```powershell
# Retrieve recent traffic logs
Get-iBossLogEntry -Limit 50
```

## Available Commands

| Command | Description |
|---|---|
| `Connect-iBoss` | Connects to the iBoss Cloud Gateway and captures Session/XSRF tokens. |
| `Get-iBossAsset` | Retrieves asset details from the gateway. |
| `Get-iBossAssetCount` | Retrieves the total count of registered assets. |
| `Add-iBossAllowList` | Adds entries to the Allow List. |
| `Get-iBossAllowList` | Retrieves the current Allow List. |
| `Remove-iBossAllowList` | Removes entries from the Allow List. |
| `Get-iBossAllowListSetting`| Retrieves Allow List settings. |
| `Add-iBossBlockList` | Adds entries to the Block List. |
| `Get-iBossBlockList` | Retrieves the current Block List. |
| `Remove-iBossBlockList` | Removes entries from the Block List. |
| `Get-iBossLogEntry` | Retrieves specific log entries. |
| `Get-iBossLogTable` | Retrieves log tables. |
| `Get-iBossLogIcon` | Retrieves associated log icons. |
| `Get-iBossGroup` | Retrieves group configurations. |
| `Get-iBossURLLookup` | Checks the categorization of a URL. |
| `Submit-iBossUrlRecategorization` | Submits a URL for recategorization. |

## Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/1NobleCyber/PSiBoss/issues).

## License

This project is licensed under the [Unlicense](LICENSE) - see the LICENSE file for details.
