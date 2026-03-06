# setup_linux_environment.ps1
# Sets up a fresh WSL Ubuntu instance ready for BigStitcher installation.
# Run via setup_linux_environment.bat (double-click) or:
#   powershell.exe -ExecutionPolicy Bypass -File setup_linux_environment.ps1

# ==============================================================================
# Configuration
# ==============================================================================
$DistroName = "Ubuntu-24.04"   # Change to e.g. "Ubuntu" for the default distro
$LinuxUser  = "keck"
$LinuxPass  = "keck"
# ==============================================================================

function Step($n, $msg) { Write-Host "`n[$n] $msg" -ForegroundColor Cyan }
function OK($msg)   { Write-Host "  OK: $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "  WARN: $msg" -ForegroundColor Yellow }
function Fail($msg) { Write-Host "`nERROR: $msg`n" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "================================================="
Write-Host "  BigStitcher Environment Setup"
Write-Host "================================================="
Write-Host "  Distro : $DistroName"
Write-Host "  User   : $LinuxUser"
Write-Host ""


# --- Step 1: Check WSL ---
Step "1/5" "Checking WSL"
$null = wsl --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Warn "WSL not available. Attempting to enable (requires Administrator)..."
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart | Out-Null
    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart | Out-Null
    Write-Host ""
    Write-Host "WSL has been enabled." -ForegroundColor Yellow
    Write-Host "Please RESTART your PC and run this script again." -ForegroundColor Yellow
    exit 0
}
OK "WSL is available"


# --- Step 2: Check / install distro ---
Step "2/5" "Checking $DistroName"
$distroList = (wsl --list --quiet 2>$null | Out-String) -replace '\x00', ''
if ($distroList -notmatch [regex]::Escape($DistroName)) {
    Write-Host "  $DistroName not found. Installing..." -ForegroundColor Yellow
    wsl --install -d $DistroName
    Write-Host ""
    Write-Host "$DistroName installed." -ForegroundColor Yellow
    Write-Host "Please RESTART your PC and run this script again." -ForegroundColor Yellow
    exit 0
}
OK "$DistroName is installed"


# --- Step 3: Create Linux user ---
Step "3/5" "Creating Linux user '$LinuxUser'"
wsl -d $DistroName -u root -- useradd -m -s /bin/bash -G sudo $LinuxUser
if ($LASTEXITCODE -ne 0) {
    Warn "User '$LinuxUser' may already exist - continuing"
} else {
    OK "User '$LinuxUser' created"
}

wsl -d $DistroName -u root -- bash -c "echo '${LinuxUser}:${LinuxPass}' | chpasswd"
OK "Password configured"


# --- Step 4: Write /etc/wsl.conf ---
Step "4/5" "Configuring default user"
wsl -d $DistroName -u root -- bash -c "echo '[boot]' > /etc/wsl.conf"
wsl -d $DistroName -u root -- bash -c "echo 'systemd=true' >> /etc/wsl.conf"
wsl -d $DistroName -u root -- bash -c "echo '' >> /etc/wsl.conf"
wsl -d $DistroName -u root -- bash -c "echo '[user]' >> /etc/wsl.conf"
wsl -d $DistroName -u root -- bash -c "echo 'default=$LinuxUser' >> /etc/wsl.conf"
OK "/etc/wsl.conf written - WSL will boot as '$LinuxUser'"


# --- Step 5: Configure WSL memory (.wslconfig) ---
Step "5/5" "Configuring WSL memory (.wslconfig)"
$wslconfigPath = Join-Path $env:USERPROFILE ".wslconfig"

if (Test-Path $wslconfigPath) {
    $existing = Get-Content $wslconfigPath -Raw
    if ($existing -match '\[wsl2\]') {
        $existing = [regex]::Replace($existing, '(?m)^memory\s*=.*$',     "memory=110GB")
        $existing = [regex]::Replace($existing, '(?m)^processors\s*=.*$', "processors=40")
        if ($existing -notmatch '(?m)^memory\s*=') {
            $existing = $existing -replace '\[wsl2\]', "[wsl2]`r`nmemory=110GB"
        }
        if ($existing -notmatch '(?m)^processors\s*=') {
            $existing = $existing -replace '\[wsl2\]', "[wsl2]`r`nprocessors=40"
        }
        Set-Content -Path $wslconfigPath -Value $existing -Encoding UTF8
        OK "Updated existing .wslconfig: memory=110GB, processors=40"
    } else {
        Add-Content -Path $wslconfigPath -Value "`r`n[wsl2]`r`nmemory=110GB`r`nprocessors=40`r`n" -Encoding UTF8
        OK "Appended [wsl2] section to existing .wslconfig"
    }
} else {
    Set-Content -Path $wslconfigPath -Value "[wsl2]`r`nmemory=110GB`r`nprocessors=40`r`n" -Encoding UTF8
    OK "Created .wslconfig: memory=110GB, processors=40"
}

wsl --terminate $DistroName 2>$null
Start-Sleep -Seconds 2


Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "  Distro ready!" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Distro : $DistroName"
Write-Host "  User   : $LinuxUser"
Write-Host ""
Write-Host "Next step:" -ForegroundColor Cyan
Write-Host "  Double-click install-bigstitcher.bat to install BigStitcher."
Write-Host "  (This will take 15-30 minutes)"
