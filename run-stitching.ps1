# run-stitching.ps1
# Runs stitch_dataset_IP_server.sh inside WSL with automatic path conversion.
# Accepts UNC paths (\\server\share\...) or mapped drive letters (Z:\...).
# Auto-mounts the share if not already connected.
#
# Usage:
#   .\run-stitching.ps1 <czi-path> <xml-name>
#
# Examples:
#   .\run-stitching.ps1 "\\everest.wi.mit.edu\keck_scratch\data\file.czi" myDataset
#   .\run-stitching.ps1 "Z:\data\file.czi" myDataset

# --- Configuration ---
$DistroName = "Ubuntu-24.04"   # Must match setup-bigstitcher.ps1
$LinuxUser  = "keck"
# ---------------------

if ($args.Count -lt 2) {
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "  .\run-stitching.ps1 <czi-path> <xml-name>"
    Write-Host ""
    Write-Host "Arguments:" -ForegroundColor Cyan
    Write-Host "  czi-path   Full path to the .czi input file (UNC or mapped drive)"
    Write-Host "  xml-name   Dataset XML name without extension"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\run-stitching.ps1 '\\everest.wi.mit.edu\keck_scratch\data\file.czi' myDataset"
    Write-Host "  .\run-stitching.ps1 'Z:\data\file.czi' myDataset"
    exit 0
}

$cziPathRaw = $args[0]
$xmlName    = $args[1]


# --- Helper: resolve a Windows path to WSL /mnt/... format ---
function Resolve-WslPath($path) {
    # Resolve mapped drive letter to UNC if needed
    if ($path -match '^[A-Za-z]:\\') {
        $letter = $path.Substring(0,2)
        $mapped = Get-WmiObject Win32_MappedLogicalDisk | Where-Object { $_.DeviceID -eq $letter }
        if (-not $mapped) {
            Write-Host "Error: Drive $letter is not a mapped network drive." -ForegroundColor Red
            exit 1
        }
        $path = $mapped.ProviderName + $path.Substring(2)
    }

    # \\server\share\rest\of\path -> /mnt/share/rest/of/path
    $parts   = $path.TrimStart('\').Split('\')
    $server  = $parts[0]
    $share   = $parts[1]
    $rest    = if ($parts.Length -gt 2) { ($parts[2..($parts.Length-1)] -join '/') } else { "" }
    $wslPath = if ($rest) { "/mnt/$share/$rest" } else { "/mnt/$share" }

    return [PSCustomObject]@{
        WslPath = $wslPath
        Share   = $share
        Server  = $server
    }
}


# --- Resolve CZI path ---
$czi = Resolve-WslPath $cziPathRaw

Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  BigStitcher Stitching Job" -ForegroundColor Cyan
Write-Host "================================================="
Write-Host "  CZI file : $($czi.WslPath)"
Write-Host "  XML name : $xmlName"
Write-Host ""


# --- Auto-mount share if not already mounted ---
wsl -d $DistroName -- mountpoint -q /mnt/$($czi.Share) 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Share /mnt/$($czi.Share) is not mounted. Connecting..." -ForegroundColor Yellow
    Write-Host ""
    $mountUser = Read-Host "  Username for $($czi.Server)"
    $mountPass = Read-Host "  Password" -AsSecureString
    $mountPassPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($mountPass))

    $serverPath = "//$($czi.Server)/$($czi.Share)"
    $mountPoint = "/mnt/$($czi.Share)"
    $keckUid    = wsl -d $DistroName -u $LinuxUser -- id -u
    $keckGid    = wsl -d $DistroName -u $LinuxUser -- id -g
    $mountOpts  = "username=$mountUser,password=$mountPassPlain,vers=3.0,rsize=4194304,wsize=4194304,cache=loose,actimeo=60,uid=$keckUid,gid=$keckGid"

    wsl -d $DistroName -u $LinuxUser -- bash -c "sudo mkdir -p '$mountPoint' && sudo mount -t cifs '$serverPath' '$mountPoint' -o '$mountOpts'"

    # Verify mount succeeded before proceeding
    wsl -d $DistroName -- mountpoint -q /mnt/$($czi.Share) 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Mount failed. Check your credentials and server path." -ForegroundColor Red
        exit 1
    }
    Write-Host "  Mounted at $mountPoint" -ForegroundColor Green
}

Write-Host "Share is mounted. Starting stitching job..." -ForegroundColor Green
Write-Host ""


# --- Run stitching script ---
wsl -d $DistroName -u $LinuxUser -- bash `
    ~/BigStitcher/BigStitcher-Spark_Keck_optimized/stitch_dataset_IP_server.sh `
    "$($czi.WslPath)" "$xmlName"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Stitching job completed successfully." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Stitching job finished with errors (exit code $LASTEXITCODE)." -ForegroundColor Red
}
