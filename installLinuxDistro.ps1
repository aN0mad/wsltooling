################################################################################
# WSL Linux Distribution Installation Script
# This script handles downloading and installing any WSL Linux distribution
# from Microsoft's official distribution list
################################################################################

Param (
    [Parameter(Mandatory=$False)][string]$wslName,
    [Parameter(Mandatory=$False)][string]$wslInstallationPath,
    [Parameter(Mandatory=$False)][string]$username,
    [Parameter(Mandatory=$False)][string]$distributionName,
    [Parameter(Mandatory=$False)][string]$installAllSoftware = "false",
    [Parameter(Mandatory=$False)][switch]$listDistributions
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
    $checkpointFile = ".\staging\distro-install-checkpoint.json"
    if (Test-Path $checkpointFile) {
        return Get-Content $checkpointFile | ConvertFrom-Json
    }
    return $null
}

function Set-InstallCheckpoint {
    param(
        [string]$Stage,
        [string]$PackageHash = "",
        [string]$DistroName = "",
        [string]$DownloadUrl = ""
    )
    $checkpointFile = ".\staging\distro-install-checkpoint.json"
    $checkpoint = @{
        Stage = $Stage
        Timestamp = (Get-Date).ToString()
        WslName = $wslName
        PackageHash = $PackageHash
        DistroName = $DistroName
        DownloadUrl = $DownloadUrl
    }
    $checkpoint | ConvertTo-Json | Set-Content $checkpointFile
    Write-Host "Checkpoint saved: $Stage" -ForegroundColor Green
}

function Clear-InstallCheckpoint {
    $checkpointFile = ".\staging\distro-install-checkpoint.json"
    Remove-Item $checkpointFile -Force -ErrorAction SilentlyContinue
}

function Get-DistributionList {
    Write-Host "Fetching available distributions from Microsoft..." -ForegroundColor Cyan
    
    try {
        $url = "https://raw.githubusercontent.com/microsoft/WSL/master/distributions/DistributionInfo.json"
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        $distrosData = $response.Content | ConvertFrom-Json
        return $distrosData.Distributions
    } catch {
        Write-Error "Failed to fetch distribution list: $_"
        Write-Host "Please check your internet connection." -ForegroundColor Yellow
        Exit 1
    }
}

function Show-DistributionMenu {
    param($Distributions)
    
    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host "Available WSL Distributions" -ForegroundColor Cyan
    Write-Host "============================================`n" -ForegroundColor Cyan
    
    $index = 1
    $menu = @{}
    
    foreach ($distro in $Distributions) {
        Write-Host "$index. $($distro.Name)" -ForegroundColor White
        if ($distro.Description) {
            Write-Host "   $($distro.Description)" -ForegroundColor Gray
        }
        $menu[$index] = $distro
        $index++
    }
    
    Write-Host "`n============================================`n" -ForegroundColor Cyan
    
    do {
        $selection = Read-Host "Select a distribution (1-$($menu.Count))"
        $selectionNum = [int]$selection
    } while ($selectionNum -lt 1 -or $selectionNum -gt $menu.Count)
    
    return $menu[$selectionNum]
}

function Get-DistributionByName {
    param(
        $Distributions,
        [string]$Name
    )
    
    # Map common/simplified names to actual distribution names
    # This allows users to specify "ubuntu" instead of "Ubuntu-22.04"
    $distributionAliases = @{
        "ubuntu" = "Ubuntu"  # Will match latest Ubuntu
        "debian" = "Debian"
        "kali" = "Kali"
        "fedora" = "Fedora"
        "opensuse" = "openSUSE"
        "suse" = "SUSE"
        "alpine" = "Alpine"
        "oracle" = "Oracle"
        "redhat" = "Oracle"  # Oracle Linux is the Red Hat-compatible option
        "pengwin" = "Pengwin"
    }
    
    # Check if the name is an alias
    $searchName = $Name
    if ($distributionAliases.ContainsKey($Name.ToLower())) {
        $searchName = $distributionAliases[$Name.ToLower()]
        Write-Host "Mapping '$Name' to latest '$searchName' distribution..." -ForegroundColor Cyan
    }
    
    # Try exact match first
    foreach ($distro in $Distributions) {
        if ($distro.Name -eq $Name) {
            return $distro
        }
    }
    
    # Try partial match (for aliases like "ubuntu" matching "Ubuntu-22.04")
    # Find the latest version (assuming higher version numbers come later)
    $matches = @()
    foreach ($distro in $Distributions) {
        if ($distro.Name -like "$searchName*") {
            $matches += $distro
        }
    }
    
    if ($matches.Count -gt 0) {
        # Return the last match (likely the latest version)
        $selectedDistro = $matches[-1]
        Write-Host "Selected: $($selectedDistro.Name)" -ForegroundColor Green
        return $selectedDistro
    }
    
    Write-Error "Distribution '$Name' not found in the official list"
    Write-Host "`nTip: Use one of these common names or exact distribution names:" -ForegroundColor Yellow
    Write-Host "  Common names: ubuntu, debian, kali, fedora, opensuse, alpine, oracle" -ForegroundColor Gray
    Write-Host "`nOr run without -distributionName to see all available distributions interactively." -ForegroundColor Gray
    Exit 1
}

function Get-DistroPackageFamily {
    param($DistroName)
    
    # Map distributions to their package families for configuration
    $packageFamilies = @{
        "Ubuntu" = "debian"
        "Debian" = "debian"
        "Kali" = "debian"
        "openSUSE" = "suse"
        "SUSE" = "suse"
        "Alpine" = "alpine"
        "Fedora" = "redhat"
        "Oracle" = "redhat"
        "Pengwin" = "debian"
    }
    
    foreach ($key in $packageFamilies.Keys) {
        if ($DistroName -like "*$key*") {
            return $packageFamilies[$key]
        }
    }
    
    return "unknown"
}

function Show-AvailableDistributions {
    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host "Available Distribution Names" -ForegroundColor Cyan
    Write-Host "============================================`n" -ForegroundColor Cyan
    
    Write-Host "Common Names (auto-select latest version):" -ForegroundColor Yellow
    Write-Host "  ubuntu       - Latest Ubuntu LTS" -ForegroundColor White
    Write-Host "  debian       - Latest Debian" -ForegroundColor White
    Write-Host "  kali         - Latest Kali Linux" -ForegroundColor White
    Write-Host "  fedora       - Latest Fedora" -ForegroundColor White
    Write-Host "  opensuse     - Latest openSUSE" -ForegroundColor White
    Write-Host "  alpine       - Latest Alpine Linux" -ForegroundColor White
    Write-Host "  oracle       - Latest Oracle Linux" -ForegroundColor White
    
    Write-Host "`nFor specific versions, run without -distributionName" -ForegroundColor Gray
    Write-Host "to see the full interactive menu.`n" -ForegroundColor Gray
    
    Write-Host "Example Usage:" -ForegroundColor Cyan
    Write-Host "  .\installLinuxDistro.ps1 -distributionName ubuntu `\" -ForegroundColor White
    Write-Host "                           -wslName myubuntu `\" -ForegroundColor White
    Write-Host "                           -wslInstallationPath C:\WSL\myubuntu `\" -ForegroundColor White
    Write-Host "                           -username myuser`n" -ForegroundColor White
}

################################################################################
# Main Installation
################################################################################

# Create staging directory if it doesn't exist
if (-Not (Test-Path -Path .\staging)) { 
    $dir = New-Item -ItemType Directory -Path .\staging
    Write-Host "Created staging directory"
}

# Check for existing checkpoint
$checkpoint = Get-InstallCheckpoint
if ($checkpoint -and $checkpoint.WslName -eq $wslName) {
    Write-Host "`nFound existing installation checkpoint for '$wslName'" -ForegroundColor Yellow
    Write-Host "Stage: $($checkpoint.Stage)" -ForegroundColor Yellow
    Write-Host "Distribution: $($checkpoint.DistroName)" -ForegroundColor Yellow
    Write-Host "Timestamp: $($checkpoint.Timestamp)" -ForegroundColor Yellow
    $resume = Read-Host "Resume from checkpoint? (Y/N)"
    
    if ($resume -ne 'Y' -and $resume -ne 'y') {
        Write-Host "Starting fresh installation..." -ForegroundColor Cyan
        Clear-InstallCheckpoint
        $checkpoint = $null
    }
}

################################################################################
# Stage 0: Get Distribution Information
################################################################################

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "WSL Linux Distribution Installer" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Yellow

# Handle -listDistributions flag
if ($listDistributions) {
    Show-AvailableDistributions
    Exit 0
}

# Get distribution list
$distributions = Get-DistributionList

# Select distribution
$selectedDistro = $null

if ($checkpoint -and $checkpoint.DistroName) {
    # Resume with previous distribution
    $selectedDistro = Get-DistributionByName -Distributions $distributions -Name $checkpoint.DistroName
    Write-Host "Resuming with distribution: $($selectedDistro.Name)" -ForegroundColor Cyan
} elseif ([string]::IsNullOrWhiteSpace($distributionName)) {
    # Interactive mode
    $selectedDistro = Show-DistributionMenu -Distributions $distributions
} else {
    # Command-line specified distribution
    $selectedDistro = Get-DistributionByName -Distributions $distributions -Name $distributionName
}

Write-Host "`nSelected distribution: $($selectedDistro.Name)" -ForegroundColor Green
if ($selectedDistro.Description) {
    Write-Host "$($selectedDistro.Description)" -ForegroundColor Gray
}

# Get remaining configuration
if ([string]::IsNullOrWhiteSpace($wslName)) {
    $wslName = Read-Host "`nEnter WSL instance name (e.g., 'mylinux')"
}

if ([string]::IsNullOrWhiteSpace($wslInstallationPath)) {
    $wslInstallationPath = Read-Host "Enter installation path (e.g., 'D:\WSL2\mylinux')"
}

if ([string]::IsNullOrWhiteSpace($username)) {
    $username = Read-Host "Enter username for WSL"
}

# Determine package family for configuration
$packageFamily = Get-DistroPackageFamily -DistroName $selectedDistro.Name
Write-Host "`nPackage family detected: $packageFamily" -ForegroundColor Gray

if ($packageFamily -eq "unknown") {
    Write-Warning "Unknown package family. Advanced configuration will be skipped."
    $installAllSoftware = "false"
}

################################################################################
# Stage 1: Download Distribution Package
################################################################################

# Use the download URL from the distribution info
# Note: The actual JSON structure may vary, adjust based on real data
$downloadUrl = $selectedDistro.Amd64PackageUrl
if ([string]::IsNullOrWhiteSpace($downloadUrl)) {
    # Fallback: try other URL properties
    $downloadUrl = $selectedDistro.PackageUrl
}

if ([string]::IsNullOrWhiteSpace($downloadUrl)) {
    Write-Error "No download URL found for $($selectedDistro.Name)"
    Exit 1
}

$packagePath = ".\staging\$($selectedDistro.Name).appx"
$packageHash = ""

if ($checkpoint -and $checkpoint.Stage -eq "PackageDownloaded") {
    Write-Host "`nResuming from downloaded package..." -ForegroundColor Cyan
    
    if (Test-Path $packagePath) {
        Write-Host "Verifying downloaded file integrity..." -ForegroundColor Cyan
        $currentHash = Get-FileHash256 -FilePath $packagePath
        
        if ($currentHash -eq $checkpoint.PackageHash) {
            Write-Host "File integrity verified! Checksum matches." -ForegroundColor Green
            $packageHash = $currentHash
        } else {
            Write-Warning "Checksum mismatch! File may be corrupted or tampered with."
            Write-Host "Expected: $($checkpoint.PackageHash)" -ForegroundColor Yellow
            Write-Host "Got:      $currentHash" -ForegroundColor Yellow
            $redownload = Read-Host "Re-download the file? (Y/N)"
            
            if ($redownload -eq 'Y' -or $redownload -eq 'y') {
                Remove-Item $packagePath -Force
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

if (-Not $checkpoint -or $checkpoint.Stage -ne "PackageDownloaded") {
    Write-Host "`nDownloading $($selectedDistro.Name) (this may take several minutes)..." -ForegroundColor Cyan
    Write-Host "URL: $downloadUrl" -ForegroundColor Gray
    
    curl.exe -L -o $packagePath $downloadUrl
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to download distribution package"
        Exit 1
    }
    
    Write-Host "Download complete. Computing checksum..." -ForegroundColor Cyan
    $packageHash = Get-FileHash256 -FilePath $packagePath
    Write-Host "SHA256: $packageHash" -ForegroundColor Gray
    
    # Create checkpoint after successful download
    Set-InstallCheckpoint -Stage "PackageDownloaded" -PackageHash $packageHash -DistroName $selectedDistro.Name -DownloadUrl $downloadUrl
}

################################################################################
# Stage 2: Extract and Import
################################################################################

Write-Host "`nExtracting distribution package..." -ForegroundColor Cyan
$extractPath = ".\staging\$wslName"

# Copy to a temp .zip file for extraction
if (Test-Path $packagePath) {
    $tempZipPath = ".\staging\temp_extract.zip"
    Copy-Item $packagePath $tempZipPath -Force
    Expand-Archive $tempZipPath $extractPath -Force
    Remove-Item $tempZipPath -Force -ErrorAction SilentlyContinue
} else {
    Write-Error "Package file not found at $packagePath"
    Exit 1
}

# Find the install.tar.gz file (or .tar.gz variant)
$tarFile = Get-ChildItem -Path $extractPath -Filter "*.tar.gz" -Recurse | Select-Object -First 1

if ($null -eq $tarFile) {
    # Some distributions might use .tar instead
    $tarFile = Get-ChildItem -Path $extractPath -Filter "*.tar" -Recurse | Select-Object -First 1
}

if ($null -eq $tarFile) {
    Write-Error "Could not find .tar.gz or .tar file in the distribution package"
    Exit 1
}

Write-Host "Found installation archive: $($tarFile.Name)" -ForegroundColor Green

if (-Not (Test-Path -Path $wslInstallationPath)) {
    New-Item -ItemType Directory -Path $wslInstallationPath -Force | Out-Null
}

# Pre-flight check: Verify WSL2 requirements are met
Write-Host "Verifying WSL2 requirements..." -ForegroundColor Cyan
$wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
$vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue

if ($null -eq $wslFeature -or $wslFeature.State -ne "Enabled") {
    Write-Error "Windows Subsystem for Linux feature is not enabled!"
    Write-Host "`nRecommended: Use the modern WSL install command:" -ForegroundColor Yellow
    Write-Host "  wsl.exe --install --no-distribution" -ForegroundColor White
    Write-Host "`nOr enable manually with:" -ForegroundColor Yellow
    Write-Host "  dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart" -ForegroundColor White
    Write-Host "`nOr use the automatic installer:" -ForegroundColor Yellow
    Write-Host "  .\installWSLAutomatic.ps1" -ForegroundColor White
    Exit 1
}

if ($null -eq $vmFeature -or $vmFeature.State -ne "Enabled") {
    Write-Error "Virtual Machine Platform feature is not enabled!"
    Write-Host "`nThis is REQUIRED for WSL 2 to function." -ForegroundColor Yellow
    Write-Host "`nRecommended: Use the modern WSL install command:" -ForegroundColor Yellow
    Write-Host "  wsl.exe --install --no-distribution" -ForegroundColor White
    Write-Host "`nOr enable manually with:" -ForegroundColor Yellow
    Write-Host "  dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart" -ForegroundColor White
    Write-Host "`nThen reboot your system." -ForegroundColor Yellow
    Write-Host "`nOr use the automatic installer which handles this:" -ForegroundColor Yellow
    Write-Host "  .\installWSLAutomatic.ps1" -ForegroundColor White
    Exit 1
}

Write-Host "[OK] WSL2 requirements verified" -ForegroundColor Green

Write-Host "Importing WSL distribution from $($tarFile.FullName)..." -ForegroundColor Cyan
wsl --import $wslName $wslInstallationPath $tarFile.FullName

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to import WSL distribution. Exit code: $LASTEXITCODE"
    Write-Host "`nCommon causes:" -ForegroundColor Yellow
    Write-Host "  1. Virtual Machine Platform not enabled (requires reboot after enabling)" -ForegroundColor White
    Write-Host "  2. Virtualization not enabled in BIOS" -ForegroundColor White
    Write-Host "  3. Hyper-V conflicts" -ForegroundColor White
    Write-Host "`nArchives have been preserved in .\staging for debugging" -ForegroundColor Yellow
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
Remove-Item $packagePath -Force -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $extractPath -ErrorAction SilentlyContinue

################################################################################
# Stage 3: Basic Configuration
################################################################################

Write-Host "`nConfiguring WSL distribution..." -ForegroundColor Cyan

# Set default user (if distribution supports it)
# Note: Not all distributions handle this the same way
Write-Host "Setting up default user '$username'..." -ForegroundColor Cyan

# The user creation process varies by distribution family
switch ($packageFamily) {
    "debian" {
        # Debian-based: Ubuntu, Debian, Kali, etc.
        Write-Host "Updating package lists..." -ForegroundColor Cyan
        wsl -d $wslName -u root bash -ic "apt update"
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Package update failed, but continuing..."
        }
        
        Write-Host "Creating user '$username'..." -ForegroundColor Cyan
        wsl -d $wslName -u root bash -ic "useradd -m -s /bin/bash $username && usermod -aG sudo $username && echo '$username ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$username"
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create user. Exit code: $LASTEXITCODE"
            Exit 1
        }
    }
    
    "redhat" {
        # Red Hat-based: Fedora, Oracle Linux, etc.
        Write-Host "Creating user '$username'..." -ForegroundColor Cyan
        wsl -d $wslName -u root bash -ic "useradd -m -s /bin/bash $username && usermod -aG wheel $username && echo '$username ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$username"
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create user. Exit code: $LASTEXITCODE"
            Exit 1
        }
    }
    
    "suse" {
        # SUSE-based: openSUSE, SUSE Linux Enterprise
        Write-Host "Creating user '$username'..." -ForegroundColor Cyan
        wsl -d $wslName -u root bash -ic "useradd -m -s /bin/bash $username && usermod -aG wheel $username && echo '$username ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$username"
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create user. Exit code: $LASTEXITCODE"
            Exit 1
        }
    }
    
    "alpine" {
        # Alpine Linux
        Write-Host "Creating user '$username'..." -ForegroundColor Cyan
        wsl -d $wslName -u root ash -ic "adduser -D -s /bin/ash $username && echo '$username ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$username"
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create user. Exit code: $LASTEXITCODE"
            Exit 1
        }
    }
    
    default {
        Write-Warning "Unknown package family. Skipping user creation."
        Write-Host "You may need to create the user manually after installation." -ForegroundColor Yellow
    }
}

# Configure default user in WSL config
$wslConfigPath = "\\wsl$\$wslName\etc\wsl.conf"
if ($packageFamily -ne "unknown") {
    Write-Host "Configuring default user in wsl.conf..." -ForegroundColor Cyan
    
    $wslConfig = @"
[user]
default=$username
"@
    
    wsl -d $wslName -u root bash -ic "echo '$wslConfig' > /etc/wsl.conf"
}

Write-Host "Restarting WSL instance..." -ForegroundColor Cyan
wsl -t $wslName

################################################################################
# Stage 4: Install Software (Optional, Debian-based only for now)
################################################################################

if ($installAllSoftware -ieq "true" -and $packageFamily -eq "debian") {
    Write-Host "`nInstalling additional software (Debian/Ubuntu systems only)..." -ForegroundColor Cyan
    
    # Check if our scripts exist
    if (Test-Path ".\scripts\config\system\sudoNoPasswd.sh") {
        Write-Host "Configuring sudo access..." -ForegroundColor Cyan
        wsl -d $wslName -u root bash -ic "./scripts/config/system/sudoNoPasswd.sh $username"
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to configure sudo access. Continuing..."
        }
    }
    
    if (Test-Path ".\scripts\install\installBasePackages.sh") {
        Write-Host "Installing base packages..." -ForegroundColor Cyan
        wsl -d $wslName -u root bash -ic ./scripts/install/installBasePackages.sh
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to install base packages. Continuing..."
        }
    }
    
    if (Test-Path ".\scripts\install\installAllSoftware.sh") {
        Write-Host "Installing all software packages (this may take a while)..." -ForegroundColor Cyan
        wsl -d $wslName -u $username bash -ic ./scripts/install/installAllSoftware.sh
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to install software packages. Continuing..."
        }
    }
} elseif ($installAllSoftware -ieq "true") {
    Write-Warning "Software installation is currently only supported for Debian-based distributions."
    Write-Host "Skipping software installation..." -ForegroundColor Yellow
}

################################################################################
# Completion
################################################################################

# Clear checkpoint after successful installation
Clear-InstallCheckpoint

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "$($selectedDistro.Name) installation completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nYou can launch your WSL with: wsl -d $wslName" -ForegroundColor Cyan
Write-Host "Default user: $username" -ForegroundColor Gray
Write-Host "All installation files have been cleaned up.`n" -ForegroundColor Gray

# Exit with success code
Exit 0
