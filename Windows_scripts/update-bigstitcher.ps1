# update-bigstitcher.ps1
# Pulls the latest BigStitcher-Spark_Keck_optimized repo on the WSL Linux side
# and refreshes execution permissions on all BigStitcher scripts.
#
# Usage: double-click update-bigstitcher.bat, or:
#   powershell.exe -ExecutionPolicy Bypass -File update-bigstitcher.ps1

# ==============================================================================
# Configuration  (must match install-bigstitcher.ps1)
# ==============================================================================
$DistroName = "Ubuntu-24.04"
$LinuxUser  = "keck"
$RepoPath   = "/home/$LinuxUser/BigStitcher/BigStitcher-Spark_Keck_optimized"
# ==============================================================================

function Step($n, $msg) { Write-Host "`n[$n] $msg" -ForegroundColor Cyan }
function OK($msg)        { Write-Host "  OK: $msg"    -ForegroundColor Green }
function Fail($msg)      { Write-Host "`nERROR: $msg`n" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "================================================="
Write-Host "  BigStitcher-Spark Keck Repo Update"
Write-Host "================================================="
Write-Host "  Distro : $DistroName"
Write-Host "  User   : $LinuxUser"
Write-Host "  Repo   : $RepoPath"
Write-Host ""

# --- Step 1: Verify repo exists ---
Step "1/3" "Checking repository"
wsl -d $DistroName -u $LinuxUser -- test -d $RepoPath
if ($LASTEXITCODE -ne 0) {
    Fail "Repository not found at $RepoPath`n  Run install-bigstitcher.bat first to set up the Linux environment."
}
OK "Repository found"

# --- Step 2: Fetch + hard reset to remote (discards any local changes) ---
Step "2/3" "Fetching latest changes from remote"
wsl -d $DistroName -u $LinuxUser -- git -C $RepoPath fetch origin
if ($LASTEXITCODE -ne 0) {
    Fail "git fetch failed. Check your network connection and repository credentials."
}

# Resolve the tracking branch (e.g. origin/main) and hard-reset to it
$Branch = wsl -d $DistroName -u $LinuxUser -- git -C $RepoPath rev-parse --abbrev-ref "@{upstream}"
if ($LASTEXITCODE -ne 0) {
    Fail "Could not determine remote tracking branch. Make sure the repo was cloned normally."
}
wsl -d $DistroName -u $LinuxUser -- git -C $RepoPath reset --hard $Branch.Trim()
if ($LASTEXITCODE -ne 0) {
    Fail "git reset --hard failed."
}
OK "Repository reset to $($Branch.Trim())"

# --- Step 3: Refresh execution permissions ---
Step "3/3" "Refreshing script permissions"
wsl -d $DistroName -u root -- bash -c "chmod +x '$RepoPath/BigStitcher_scripts/'*"
if ($LASTEXITCODE -ne 0) { Fail "chmod on BigStitcher_scripts/ failed." }
wsl -d $DistroName -u root -- bash -c "chmod +x '$RepoPath/Windows_scripts/install-bigstitcher.sh'"
if ($LASTEXITCODE -ne 0) { Fail "chmod on install-bigstitcher.sh failed." }
OK "Permissions refreshed"

Write-Host ""
Write-Host "================================================="
Write-Host "  Update complete."
Write-Host "================================================="
Write-Host ""
