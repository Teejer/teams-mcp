# ============================================================
#  set-dns.ps1
#  Sets DNS servers to 10.10.1.27 (primary) and 10.10.1.30
#  on ALL active (connected) network adapters, regardless of
#  their name. Run elevated:
#    powershell -ExecutionPolicy Bypass -File set-dns.ps1
# ============================================================

$Primary   = '10.10.1.27'
$Secondary = '10.10.1.30'

# Requires -RunAsAdministrator fails cleanly if not elevated
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator."
    exit 1
}

# All connected, non-virtual adapters (physical Ethernet + Wi-Fi)
$adapters = Get-NetAdapter | Where-Object {
    $_.Status -eq 'Up' -and $_.Virtual -eq $false
}

if (-not $adapters) {
    Write-Warning "No connected physical adapters found."
    exit 0
}

foreach ($ad in $adapters) {
    Write-Host "Configuring $($ad.Name) ..."
    Set-DnsClientServerAddress -InterfaceIndex $ad.ifIndex `
        -ServerAddresses ($Primary, $Secondary)
}

Write-Host "`nCurrent DNS configuration:"
Get-DnsClientServerAddress -AddressFamily IPv4 |
    Where-Object { $_.ServerAddresses } |
    Format-Table InterfaceAlias, ServerAddresses -AutoSize
