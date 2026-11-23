$reports = Get-ChildItem -Path "\\localhost\networkShare" -Filter "*.csv"

$inventoryData = $reports | ForEach-Object {
    Import-Csv -Path $_.FullName
}
$inventoryData | Format-Table Hostname, OperatingSystem, RAM_GB, FreeStoragePercent
$exportPath = Join-Path $PSScriptRoot "..\samples\consolidatedFile.csv"
$inventoryData | Export-Csv -Path $exportPath -NoTypeInformation