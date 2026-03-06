# install-bigstitcher.ps1
# Copies install-bigstitcher.sh into the WSL distro and runs it.
# Run this after setup_linux_environment.bat has completed.
# Double-click install-bigstitcher.bat or:
#   powershell.exe -ExecutionPolicy Bypass -File install-bigstitcher.ps1

# ==============================================================================
# Configuration  (must match setup_linux_environment.ps1)
# ==============================================================================
$DistroName    = "Ubuntu-24.04"   # Must match setup_linux_environment.ps1
$LinuxUser     = "keck"
$Threads       = "40"             # CPU threads for BigStitcher build (-t)
$Memory        = "110"            # RAM in GB for BigStitcher build (-m)
$InstallScript = Join-Path $PSScriptRoot "install-bigstitcher.sh"
# ==============================================================================

function Step($n, $msg) { Write-Host "`n[$n] $msg" -ForegroundColor Cyan }
function OK($msg)   { Write-Host "  OK: $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "  WARN: $msg" -ForegroundColor Yellow }
function Fail($msg) { Write-Host "`nERROR: $msg`n" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "================================================="
Write-Host "  BigStitcher Installation"
Write-Host "================================================="
Write-Host "  Distro  : $DistroName"
Write-Host "  User    : $LinuxUser"
Write-Host "  Threads : $Threads"
Write-Host "  Memory  : ${Memory}GB"
Write-Host ""


# --- Step 1: Copy and patch install script ---
Step "1/2" "Preparing install script"

if (-not (Test-Path $InstallScript)) {
    Fail "install-bigstitcher.sh not found at: $InstallScript`n  Make sure it is in the same folder as this script."
}

$wslHome = "\\wsl.localhost\$DistroName\home\$LinuxUser"
if (-not (Test-Path $wslHome)) {
    Fail "Cannot reach WSL home at $wslHome`n  Make sure $DistroName is running (run setup_linux_environment.bat first)."
}

$content   = Get-Content $InstallScript -Raw
$content   = [regex]::Replace($content, '\./install -t \d+ -m \d+', "./install -t $Threads -m $Memory")
$content   = $content -replace "`r`n", "`n" -replace "`r", "`n"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$wslHome\install-bigstitcher.sh", $content, $utf8NoBom)

wsl -d $DistroName -u root -- chmod +x "/home/$LinuxUser/install-bigstitcher.sh"
wsl -d $DistroName -u root -- chown "${LinuxUser}:${LinuxUser}" "/home/$LinuxUser/install-bigstitcher.sh"
OK "install-bigstitcher.sh ready (threads=$Threads, memory=${Memory}GB)"


# --- Step 2: Run install script ---
Step "2/2" "Running BigStitcher installation"
Write-Host "  This will take 15-30 minutes. Do not close this window." -ForegroundColor Yellow
Write-Host ""

wsl -d $DistroName -u $LinuxUser -- bash "/home/$LinuxUser/install-bigstitcher.sh"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host "  Installation complete!" -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Distro : $DistroName"
    Write-Host "  User   : $LinuxUser"
    Write-Host "  Tools  : ~/BigStitcher/"
    Write-Host ""
    Write-Host "To run a stitching job:" -ForegroundColor Cyan
    Write-Host "  Double-click run-stitching.bat"
} else {
    Fail "Installation finished with errors. Check the output above."
}
