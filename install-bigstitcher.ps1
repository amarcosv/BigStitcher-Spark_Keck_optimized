# install-bigstitcher.ps1
# Clones BigStitcher-Spark_Keck_optimized into WSL and runs its install script.
# Run this after setup_linux_environment.bat has completed.
# Double-click install-bigstitcher.bat or:
#   powershell.exe -ExecutionPolicy Bypass -File install-bigstitcher.ps1

# ==============================================================================
# Configuration  (must match setup_linux_environment.ps1)
# ==============================================================================
$DistroName = "Ubuntu-24.04"   # Must match setup_linux_environment.ps1
$LinuxUser  = "keck"
$Threads    = "40"             # CPU threads for BigStitcher build (-t)
$Memory     = "110"            # RAM in GB for BigStitcher build (-m)
$RepoUrl    = "https://github.com/amarcosv/BigStitcher-Spark_Keck_optimized.git"
$RepoDir    = "/home/$LinuxUser/BigStitcher/BigStitcher-Spark_Keck_optimized"
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


# --- Pre-check: WSL home reachable ---
$wslHome = "\\wsl.localhost\$DistroName\home\$LinuxUser"
if (-not (Test-Path $wslHome)) {
    Fail "Cannot reach WSL home at $wslHome`n  Make sure $DistroName is running (run setup_linux_environment.bat first)."
}


# --- Step 1: Clone repository ---
Step "1/2" "Cloning BigStitcher-Spark_Keck_optimized into WSL"

wsl -d $DistroName -u $LinuxUser -- bash -c "mkdir -p ~/BigStitcher"
if ($LASTEXITCODE -ne 0) { Fail "Failed to create ~/BigStitcher directory." }

# Check if already cloned to avoid re-cloning
wsl -d $DistroName -u $LinuxUser -- test -d "$RepoDir/.git"
if ($LASTEXITCODE -eq 0) {
    Warn "Repo already cloned at $RepoDir - pulling latest instead."
    wsl -d $DistroName -u $LinuxUser -- git -C "$RepoDir" pull
} else {
    wsl -d $DistroName -u $LinuxUser -- git clone "$RepoUrl" "$RepoDir"
    if ($LASTEXITCODE -ne 0) { Fail "git clone failed. Check network connectivity and repo URL." }
}

wsl -d $DistroName -u root -- chmod +x "$RepoDir/install-bigstitcher.sh"
OK "Repository ready at $RepoDir"


# --- Step 2: Patch thread/memory values and run install script ---
Step "2/2" "Running BigStitcher installation"
Write-Host "  This will take 15-30 minutes. Do not close this window." -ForegroundColor Yellow
Write-Host ""

# Patch ./install -t N -m M in the cloned script
$shPath = "$wslHome\BigStitcher\BigStitcher-Spark_Keck_optimized\install-bigstitcher.sh"
$content = Get-Content $shPath -Raw
$content = [regex]::Replace($content, '\./install -t \d+ -m \d+', "./install -t $Threads -m $Memory")
$content = $content -replace "`r`n", "`n" -replace "`r", "`n"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($shPath, $content, $utf8NoBom)

wsl -d $DistroName -u $LinuxUser -- bash "$RepoDir/install-bigstitcher.sh"

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
