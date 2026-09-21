# ============================================================
#  set-dns.ps1
#  Sets DNS servers to 192.0.2.10 (primary) and 192.0.2.11
#  on ALL active (connected) network adapters, regardless of
#  their name. Run elevated:
#    powershell -ExecutionPolicy Bypass -File set-dns.ps1
#  Edit $Primary/$Secondary to your DNS servers first.
# ============================================================

$Primary   = '192.0.2.10'
$Secondary = '192.0.2.11'

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
