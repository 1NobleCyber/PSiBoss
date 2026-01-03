# Private Functions (Hidden from user)
$PrivateFiles = Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1"
foreach ($File in $PrivateFiles) {
    . $File.FullName
}

# Public Functions (Visible to user)
$PublicFiles = Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1"
foreach ($File in $PublicFiles) {
    . $File.FullName
    Export-ModuleMember -Function $File.BaseName
}