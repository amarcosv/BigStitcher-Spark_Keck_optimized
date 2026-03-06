# connect-server.ps1
# Connects to a network share via the WSL mount-server.sh script.
# Accepts a UNC path or a mapped drive letter.
#
# Usage:
#   .\connect-server.ps1 \\everest.wi.mit.edu\keck_scratch
#   .\connect-server.ps1 Z:\

# --- Configuration ---
$DistroName = "Ubuntu"   # Must match the distro used in setup-bigstitcher.ps1
$LinuxUser  = "keck"
# ---------------------

if ($args.Count -eq 0) {
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "  .\connect-server.ps1 \\server\sharename"
    Write-Host "  .\connect-server.ps1 Z:\"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\connect-server.ps1 \\everest.wi.mit.edu\keck_scratch"
    Write-Host "  .\connect-server.ps1 Z:\"
    Write-Host ""
    Write-Host "You will be prompted for your username and password."
    exit 0
}

$path = $args[0]

# --- Resolve mapped drive letter to UNC ---
if ($path -match '^[A-Za-z]:[\\]?$') {
    $letter = $path.Substring(0,2)
    $mapped = Get-WmiObject Win32_MappedLogicalDisk | Where-Object { $_.DeviceID -eq $letter }
    if (-not $mapped) {
        Write-Host "Error: Drive $letter is not a mapped network drive." -ForegroundColor Red
        exit 1
    }
    $path = $mapped.ProviderName
}

# --- Convert \\server\share to //server/share for WSL ---
$wslPath = "//" + $path.TrimStart('\').Replace('\', '/')

Write-Host ""
Write-Host "Connecting to: $wslPath" -ForegroundColor Cyan
Write-Host ""

wsl -d $DistroName -u $LinuxUser -- bash ~/mount-server.sh $wslPath
