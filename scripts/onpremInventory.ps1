# Windows Endpoint Inventory

Set-StrictMode -Version Latest

# 1. Collect endpoint information
$compSystem = Get-CimInstance -ClassName Win32_ComputerSystem
$compInfo = Get-ComputerInfo -Property CsName, WindowsProductName, OsVersion, OsBuildNumber, OsLastBootUpTime
$storage = Get-Volume -DriveLetter C | Select-Object DriveLetter, FileSystem, Size, SizeRemaining, HealthStatus
$networkInfo = Get-NetIPAddress -AddressFamily IPv4 | Select-Object IPAddress, InterfaceAlias, PrefixLength
$firewall = Get-NetFirewallProfile | Select-Object Name, Enabled
$cpu = Get-CimInstance -ClassName Win32_Processor

# 2. Collect bitlocker information and handle errors
try{
    $bitlocker = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop | Select-Object MountPoint, VolumeStatus, ProtectionStatus, EncryptionPercentage
}
catch{
    Write-Warning "Unable to retrieve Bitlocker Information: $($_.Exception.Message)"

    $bitlocker = [PSCustomObject]@{
        ProtectionStatus     = "Unknown"
        VolumeStatus         = "Unknown"
        EncryptionPercentage = $null
    }
}

# 3. Collect RAM size and storage information
$ramGB = $compSystem.TotalPhysicalMemory / 1GB
$ramGB = [math]::Round($ramGB, 2)
$totalDiskGB = [math]::Round($storage.Size / 1GB, 2)
$freeDiskGB = [math]::Round($storage.SizeRemaining / 1GB, 2)
$freeDiskPercent = [math]::Round(($storage.SizeRemaining / $storage.Size) * 100, 2)

# 4. Filter network interfaces we don't care about
# Where-Object to remove categories
$filteredNetwork = $networkInfo | Where-Object {
    $_.InterfaceAlias -notlike "Bluetooth Network Connection*" -and
    $_.IPAddress -ne "127.0.0.1" -and
    $_.IPAddress -notlike "169.254.*" -and
    $_.InterfaceAlias -notlike "vEthernet*"
}
$IPAddresses = ($filteredNetwork | Select-Object -ExpandProperty IPAddress) -join "; "

# 5. Collect firewall information
$enabledFirewall = ($firewall | Where-Object {$_.Enabled -eq $true} | Select-Object -ExpandProperty Name) -join '; '
$disabledFirewall = ($firewall | Where-Object {$_.Enabled -eq $false} | Select-Object -ExpandProperty Name) -join '; '


# 6. Combine properties into one PSCustomObject
$inventory = [PSCustomObject]@{ #PSCustom Object!
    Hostname = $compSystem.Name
    Manufacturer = $compSystem.Manufacturer
    Model = $compSystem.Model
    OperatingSystem = $compInfo.WindowsProductName
    OSVersion = $compInfo.OsVersion
    LastBootTime = $compInfo.OsLastBootUpTime
    CPU = $cpu.Name
    RAM_GB = $ramGB
    StorageSize_GB = $totalDiskGB
    FreeStorageSize_GB = $freeDiskGB
    FreeStoragePercent = $freeDiskPercent
    IPAddress = $IPAddresses
    EnabledFirewall = $enabledFirewall
    DisabledFirewall = $disabledFirewall
    Bitlocker = $bitlocker.ProtectionStatus
    BitlockerVolumeStatus = $bitlocker.VolumeStatus
    BitlockerEncryptionPercentage = $bitlocker.EncryptionPercentage
}

# 7. Display and export inventory
$inventory | Format-List
$sharePath = "\\localhost\networkShare"

$hostname = $env:COMPUTERNAME
$timestamp = Get-date -format "yyyy-MM-dd-HH-mm-ss"
$filename = "${hostname}_${timestamp}.csv"
$exportPath = Join-Path -Path $sharePath -ChildPath $filename
try {
    $inventory | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop

    Write-Warning "Inventory successfully exported to: $exportPath"
}
catch {
    Write-Warning "Inventory failed to export: $($_.Exception.Message)"
}
