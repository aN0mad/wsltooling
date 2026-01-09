Param (
[Parameter(Mandatory=$True)][ValidateNotNull()][string]$wslName,
[Parameter(Mandatory=$True)][ValidateNotNull()][string]$wslInstallationPath,
[Parameter(Mandatory=$True)][ValidateNotNull()][string]$username,
[Parameter(Mandatory=$True)][ValidateNotNull()][string]$installAllSoftware
)

################################################################################
# Helper Functions
################################################################################

function Get-FileHash256 {
    param($FilePath)
    $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
    return $hash.Hash
}

function Get-InstallCheckpoint {
    $checkpointFile = ".\staging\ubuntu-install-checkpoint.json"
    if (Test-Path $checkpointFile) {
        return Get-Content $checkpointFile | ConvertFrom-Json
    }
    return $null
}

function Set-InstallCheckpoint {
    param(
        [string]$Stage,
        [string]$AppxHash = "",
        [string]$TarPath = ""
    )
    $checkpointFile = ".\staging\ubuntu-install-checkpoint.json"
    $checkpoint = @{
        Stage = $Stage
        Timestamp = (Get-Date).ToString()
        WslName = $wslName
        AppxHash = $AppxHash
        TarPath = $TarPath
    }
    $checkpoint | ConvertTo-Json | Set-Content $checkpointFile
    Write-Host "Checkpoint saved: $Stage" -ForegroundColor Green
}

function Clear-InstallCheckpoint {
    $checkpointFile = ".\staging\ubuntu-install-checkpoint.json"
    Remove-Item $checkpointFile -Force -ErrorAction SilentlyContinue
}

################################################################################
# Main Installation
################################################################################

# create staging directory if it does not exists
if (-Not (Test-Path -Path .\staging)) { 
    $dir = New-Item -ItemType Directory -Path .\staging
    Write-Host "Created staging directory"
}

# Check for existing checkpoint
$checkpoint = Get-InstallCheckpoint
if ($checkpoint -and $checkpoint.WslName -eq $wslName) {
    Write-Host "`nFound existing installation checkpoint for '$wslName'" -ForegroundColor Yellow
    Write-Host "Stage: $($checkpoint.Stage)" -ForegroundColor Yellow
    Write-Host "Timestamp: $($checkpoint.Timestamp)" -ForegroundColor Yellow
    $resume = Read-Host "Resume from checkpoint? (Y/N)"
    
    if ($resume -ne 'Y' -and $resume -ne 'y') {
        Write-Host "Starting fresh installation..." -ForegroundColor Cyan
        Clear-InstallCheckpoint
        $checkpoint = $null
    }
}


################################################################################
# Stage 1: Download Ubuntu Appx
################################################################################

$appxPath = ".\staging\ubuntuLTS.appx"
$appxHash = ""

if ($checkpoint -and $checkpoint.Stage -eq "AppxDownloaded") {
    Write-Host "`nResuming from downloaded Appx..." -ForegroundColor Cyan
    
    if (Test-Path $appxPath) {
        Write-Host "Verifying downloaded file integrity..." -ForegroundColor Cyan
        $currentHash = Get-FileHash256 -FilePath $appxPath
        
        if ($currentHash -eq $checkpoint.AppxHash) {
            Write-Host "File integrity verified! Checksum matches." -ForegroundColor Green
            $appxHash = $currentHash
        } else {
            Write-Warning "Checksum mismatch! File may be corrupted or tampered with."
            Write-Host "Expected: $($checkpoint.AppxHash)" -ForegroundColor Yellow
            Write-Host "Got:      $currentHash" -ForegroundColor Yellow
            $redownload = Read-Host "Re-download the file? (Y/N)"
            
            if ($redownload -eq 'Y' -or $redownload -eq 'y') {
                Remove-Item $appxPath -Force
                $checkpoint = $null
            } else {
                Write-Error "Installation aborted due to checksum mismatch"
                Exit 1
            }
        }
    } else {
        Write-Warning "Checkpoint exists but file not found. Re-downloading..."
        $checkpoint = $null
    }
}

if (-Not $checkpoint -or $checkpoint.Stage -ne "AppxDownloaded") {
    Write-Host "Downloading Ubuntu 20.04 LTS (this may take several minutes)..." -ForegroundColor Cyan
    curl.exe -L -o $appxPath https://aka.ms/wslubuntu2004
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to download Ubuntu package"
        Exit 1
    }
    
    Write-Host "Download complete. Computing checksum..." -ForegroundColor Cyan
    $appxHash = Get-FileHash256 -FilePath $appxPath
    Write-Host "SHA256: $appxHash" -ForegroundColor Gray
    
    # Create checkpoint after successful download
    Set-InstallCheckpoint -Stage "AppxDownloaded" -AppxHash $appxHash
}

################################################################################
# Stage 2: Extract and Import
################################################################################

Write-Host "`nExtracting Ubuntu package..." -ForegroundColor Cyan
$extractPath = ".\staging\$wslName"

# Don't rename the appx - just expand it directly
# Note: Expand-Archive requires a .zip extension, so we need to work around this
if (Test-Path $appxPath) {
    # Copy to a temp .zip file for extraction
    $tempZipPath = ".\staging\temp_extract.zip"
    Copy-Item $appxPath $tempZipPath -Force
    Expand-Archive $tempZipPath $extractPath -Force
    Remove-Item $tempZipPath -Force -ErrorAction SilentlyContinue
} else {
    Write-Error "Appx file not found at $appxPath"
    Exit 1
}

# Find the install.tar.gz file (it might be named differently in newer versions)
$tarFile = Get-ChildItem -Path $extractPath -Filter "*.tar.gz" -Recurse | Select-Object -First 1

if ($null -eq $tarFile) {
    Write-Error "Could not find .tar.gz file in the Ubuntu package"
    Exit 1
}

Write-Host "Found installation archive: $($tarFile.Name)" -ForegroundColor Green

if (-Not (Test-Path -Path $wslInstallationPath)) {
    New-Item -ItemType Directory -Path $wslInstallationPath -Force | Out-Null
}

Write-Host "Importing WSL distribution from $($tarFile.FullName)..." -ForegroundColor Cyan
wsl --import $wslName $wslInstallationPath $tarFile.FullName

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to import WSL distribution. Exit code: $LASTEXITCODE"
    Write-Host "Archives have been preserved in .\staging for debugging" -ForegroundColor Yellow
    Exit 1
}

Write-Host "WSL distribution imported successfully!" -ForegroundColor Green

# Verify the distribution was imported
$distros = wsl --list --quiet
if ($distros -notcontains $wslName) {
    Write-Error "Distribution $wslName was not imported successfully"
    Write-Host "Archives have been preserved in .\staging for debugging" -ForegroundColor Yellow
    Exit 1
}

# Only clean up after successful import
Write-Host "Cleaning up installation files..." -ForegroundColor Cyan
Remove-Item $appxPath -Force -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $extractPath -ErrorAction SilentlyContinue

################################################################################
# Stage 3: Configure Distribution
################################################################################

Write-Host "`nConfiguring WSL distribution..." -ForegroundColor Cyan

Write-Host "Updating the system..." -ForegroundColor Cyan
# Update the system
wsl -d $wslName -u root bash -ic "apt update; apt upgrade -y"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to update the system. Exit code: $LASTEXITCODE"
    Write-Host "Distribution has been imported but configuration failed." -ForegroundColor Yellow
    Exit 1
}

Write-Host "Creating user '$username'..." -ForegroundColor Cyan
# create your user and add it to sudoers
wsl -d $wslName -u root bash -ic "./scripts/config/system/createUser.sh $username ubuntu"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create user. Exit code: $LASTEXITCODE"
    Write-Host "Make sure the createUser.sh script exists and is executable." -ForegroundColor Yellow
    Exit 1
}

Write-Host "Restarting WSL instance..." -ForegroundColor Cyan
# ensure WSL Distro is restarted when first used with user account
wsl -t $wslName

################################################################################
# Stage 4: Install Software (Optional)
################################################################################

if ($installAllSoftware -ieq $true) {
    Write-Host "`nInstalling additional software..." -ForegroundColor Cyan
    
    Write-Host "Configuring sudo access..." -ForegroundColor Cyan
    wsl -d $wslName -u root bash -ic "./scripts/config/system/sudoNoPasswd.sh $username"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to configure sudo access. Exit code: $LASTEXITCODE"
        Exit 1
    }
    
    Write-Host "Installing base packages..." -ForegroundColor Cyan
    wsl -d $wslName -u root bash -ic ./scripts/install/installBasePackages.sh
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install base packages. Exit code: $LASTEXITCODE"
        Exit 1
    }
    
    Write-Host "Installing all software packages (this may take a while)..." -ForegroundColor Cyan
    wsl -d $wslName -u $username bash -ic ./scripts/install/installAllSoftware.sh
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install software packages. Exit code: $LASTEXITCODE"
        Exit 1
    }
}

################################################################################
# Completion
################################################################################

# Clear checkpoint after successful installation
Clear-InstallCheckpoint

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Ubuntu LTS installation completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nYou can launch your WSL with: wsl -d $wslName" -ForegroundColor Cyan
Write-Host "All installation files have been cleaned up.`n" -ForegroundColor Gray

# Exit with success code
Exit 0
