################################################################################
# Automatic WSL Installation Script
# This script handles the complete WSL 2 installation process including
# automatic continuation after required reboot
################################################################################

Param (
    [Parameter(Mandatory=$False)][string]$wslName,
    [Parameter(Mandatory=$False)][string]$wslInstallationPath,
    [Parameter(Mandatory=$False)][string]$username,
    [Parameter(Mandatory=$False)][string]$distributionName,
    [Parameter(Mandatory=$False)][string]$installAllSoftware = "false"
)

# Ensure running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script must be run as Administrator!"
    Write-Host "Please right-click and select 'Run as Administrator'"
    Read-Host "Press Enter to exit"
    Exit 1
}

# Set execution policy for this session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Store the current script directory
$scriptDir = $PSScriptRoot
$statusFile = Join-Path $scriptDir "staging\install-status.json"
$configFile = Join-Path $scriptDir "staging\install-config.json"

# Create staging directory if it doesn't exist
if (-Not (Test-Path -Path (Join-Path $scriptDir "staging"))) {
    New-Item -ItemType Directory -Path (Join-Path $scriptDir "staging") | Out-Null
}

################################################################################
# Helper Functions
################################################################################

function Get-InstallStatus {
    if (Test-Path $statusFile) {
        return Get-Content $statusFile | ConvertFrom-Json
    }
    return @{ Stage = "Initial"; Timestamp = Get-Date }
}

function Set-InstallStatus {
    param($Stage)
    @{ Stage = $Stage; Timestamp = (Get-Date).ToString() } | ConvertTo-Json | Set-Content $statusFile
}

function Save-Configuration {
    param($Config)
    $Config | ConvertTo-Json | Set-Content $configFile
}

function Get-Configuration {
    if (Test-Path $configFile) {
        return Get-Content $configFile | ConvertFrom-Json
    }
    return $null
}

function Test-WSLFeatureEnabled {
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
    $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue
    
    if ($null -eq $wslFeature -or $null -eq $vmFeature) {
        return $false
    }
    
    return ($wslFeature.State -eq "Enabled" -and $vmFeature.State -eq "Enabled")
}

function Test-WSL2Installed {
    # First check if Virtual Machine Platform is enabled - this is REQUIRED for WSL 2
    $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue
    if ($null -eq $vmFeature -or $vmFeature.State -ne "Enabled") {
        return $false
    }
    
    # Check if WSL 2 is available by trying to get the default version
    try {
        $wslOutput = wsl --status 2>&1
        if ($LASTEXITCODE -eq 0) {
            # WSL is installed and working, check for WSL 2 support
            $versionOutput = wsl --list --verbose 2>&1
            # If we can run wsl commands, WSL 2 kernel is likely installed
            # Also check if we can set default version (this will fail if kernel not installed)
            return $true
        }
    } catch {
        # If wsl command fails, WSL 2 is not fully installed
        return $false
    }
    
    # Alternative check: Look for the WSL 2 kernel file
    $kernelPath = "$env:SystemRoot\System32\lxss\tools\kernel"
    if (Test-Path $kernelPath) {
        return $true
    }
    
    return $false
}

function Register-ContinuationTask {
    $taskName = "WSL2AutoInstallContinuation"
    
    # Create a scheduled task to run this script at logon
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
        -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Normal -File `"$($MyInvocation.PSCommandPath)`""
    
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    
    # Remove existing task if present
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    
    # Register new task
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null
    
    Write-Host "Registered continuation task to run at next logon" -ForegroundColor Green
}

function Unregister-ContinuationTask {
    $taskName = "WSL2AutoInstallContinuation"
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
}

function Validate-DistributionName {
    param($DistributionName)
    
    if ([string]::IsNullOrWhiteSpace($DistributionName)) {
        # Empty is OK - will be selected interactively
        return $true
    }
    
    Write-Host "Validating distribution name '$DistributionName'..." -ForegroundColor Cyan
    
    try {
        # Fetch the distribution list from Microsoft's GitHub
        $distroListUrl = "https://raw.githubusercontent.com/microsoft/WSL/master/distributions/DistributionInfo.json"
        $response = Invoke-WebRequest -Uri $distroListUrl -UseBasicParsing
        $distributions = ($response.Content | ConvertFrom-Json).Distributions
        
        # Check aliases
        $distributionAliases = @{
            "ubuntu" = "Ubuntu"
            "debian" = "Debian"
            "kali" = "Kali"
            "fedora" = "Fedora"
            "opensuse" = "openSUSE"
            "alpine" = "Alpine"
            "oracle" = "Oracle"
            "redhat" = "Oracle"
            "pengwin" = "Pengwin"
        }
        
        $searchName = $DistributionName
        if ($distributionAliases.ContainsKey($DistributionName.ToLower())) {
            $searchName = $distributionAliases[$DistributionName.ToLower()]
        }
        
        # Try exact match
        foreach ($distro in $distributions) {
            if ($distro.Name -eq $DistributionName) {
                Write-Host "[OK] Distribution '$DistributionName' validated successfully" -ForegroundColor Green
                return $true
            }
        }
        
        # Try partial match for aliases
        $distro_matches = @()
        foreach ($distro in $distributions) {
            if ($distro.Name -like "$searchName*") {
                $distro_matches += $distro
            }
        }
        
        if ($distro_matches.Count -gt 0) {
            $selectedDistro = $distro_matches[-1]
            Write-Host "[OK] Distribution '$DistributionName' will resolve to '$($selectedDistro.Name)'" -ForegroundColor Green
            return $true
        }
        
        # Distribution not found
        Write-Host "`n========================================" -ForegroundColor Red
        Write-Host "ERROR: Invalid Distribution Name" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "`nDistribution '$DistributionName' not found in the official list." -ForegroundColor Yellow
        Write-Host "`nCommon distribution names:" -ForegroundColor Cyan
        Write-Host "  ubuntu, debian, kali, fedora, opensuse, alpine, oracle" -ForegroundColor White
        Write-Host "`nTo see all available distributions, run:" -ForegroundColor Cyan
        Write-Host "  .\installLinuxDistro.ps1 -listDistributions`n" -ForegroundColor White
        return $false
    }
    catch {
        Write-Warning "Could not validate distribution name (network error). Will validate during installation."
        Write-Warning "Error: $_"
        return $true
    }
}

function Get-UserInput {
    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host "WSL 2 Automatic Installation Configuration" -ForegroundColor Cyan
    Write-Host "============================================`n" -ForegroundColor Cyan
    
    $config = @{}
    
    if ([string]::IsNullOrWhiteSpace($script:wslName)) {
        $config.wslName = Read-Host "Enter WSL instance name (e.g., 'devbox')"
    } else {
        $config.wslName = $script:wslName
    }
    
    if ([string]::IsNullOrWhiteSpace($script:wslInstallationPath)) {
        $config.wslInstallationPath = Read-Host "Enter installation path (e.g., 'D:\WSL2\devbox')"
    } else {
        $config.wslInstallationPath = $script:wslInstallationPath
    }
    
    if ([string]::IsNullOrWhiteSpace($script:username)) {
        $config.username = Read-Host "Enter username for WSL"
    } else {
        $config.username = $script:username
    }
    
    if ([string]::IsNullOrWhiteSpace($script:distributionName)) {
        # Will be prompted interactively by installLinuxDistro.ps1
        $config.distributionName = ""
    } else {
        $config.distributionName = $script:distributionName
    }
    
    if ([string]::IsNullOrWhiteSpace($script:installAllSoftware)) {
        $response = Read-Host "Install all software packages? (true/false)"
        $config.installAllSoftware = $response
    } else {
        $config.installAllSoftware = $script:installAllSoftware
    }
    
    # Validate distribution name if provided
    if (-not [string]::IsNullOrWhiteSpace($config.distributionName)) {
        if (-not (Validate-DistributionName -DistributionName $config.distributionName)) {
            Write-Host "`nExiting due to invalid distribution name.`n" -ForegroundColor Red
            Exit 1
        }
    }
    
    return $config
}

################################################################################
# Installation Stages
################################################################################

function Stage-EnableWSL {
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "Stage 1: Enabling WSL Features" -ForegroundColor Yellow
    Write-Host "========================================`n" -ForegroundColor Yellow
    
    # Run the enableWSL script
    Write-Host "Enabling Microsoft-Windows-Subsystem-Linux..." -ForegroundColor Cyan
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    
    Write-Host "Enabling VirtualMachinePlatform..." -ForegroundColor Cyan
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    
    Set-InstallStatus -Stage "WSLEnabled"
    Register-ContinuationTask
    
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "WSL features enabled successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "`nA REBOOT IS REQUIRED to continue installation." -ForegroundColor Yellow
    Write-Host "The installation will continue automatically after you log back in.`n" -ForegroundColor Yellow
    
    $response = Read-Host "Reboot now? (Y/N)"
    if ($response -eq 'Y' -or $response -eq 'y') {
        Write-Host "Rebooting in 10 seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    } else {
        Write-Host "Please reboot manually. Installation will continue automatically after logon." -ForegroundColor Yellow
    }
}

function Stage-InstallWSL2 {
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "Stage 2: Installing WSL 2" -ForegroundColor Yellow
    Write-Host "========================================`n" -ForegroundColor Yellow
    
    # Check if Virtual Machine Platform is enabled
    $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue
    
    if ($null -eq $vmFeature -or $vmFeature.State -ne "Enabled") {
        Write-Host "Virtual Machine Platform is not enabled!" -ForegroundColor Yellow
        Write-Host "Using the recommended method to enable WSL features..." -ForegroundColor Cyan
        Write-Host "Running: wsl.exe --install --no-distribution`n" -ForegroundColor Cyan
        
        wsl.exe --install --no-distribution
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to install WSL features. Exit code: $LASTEXITCODE"
            Write-Host "`nYou may need to:" -ForegroundColor Yellow
            Write-Host "  1. Enable virtualization in your BIOS" -ForegroundColor White
            Write-Host "  2. Ensure you're running as Administrator" -ForegroundColor White
            Exit 1
        }
        
        Write-Host "`n[OK] WSL features installed" -ForegroundColor Green
        Write-Host "`nA REBOOT IS REQUIRED for changes to take effect." -ForegroundColor Yellow
        
        Set-InstallStatus -Stage "WSLEnabled"
        Register-ContinuationTask
        
        Write-Host "The installation will continue automatically after you log back in.`n" -ForegroundColor Yellow
        
        $response = Read-Host "Reboot now? (Y/N)"
        if ($response -eq 'Y' -or $response -eq 'y') {
            Write-Host "Rebooting in 10 seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 10
            Restart-Computer -Force
        } else {
            Write-Host "Please reboot manually. Installation will continue automatically after logon." -ForegroundColor Yellow
        }
        Exit 0
    }
    
    # Check if WSL 2 is already installed
    if (Test-WSL2Installed) {
        Write-Host "WSL 2 kernel is already installed. Skipping installation..." -ForegroundColor Green
        
        # Still ensure default version is set to 2
        Write-Host "Verifying WSL default version is set to 2..." -ForegroundColor Cyan
        wsl --set-default-version 2 2>$null
        
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host "WSL 2 is ready!" -ForegroundColor Green
        Write-Host "========================================`n" -ForegroundColor Green
        
        Set-InstallStatus -Stage "WSL2Installed"
        return
    }
    
    $wslUpdatePath = Join-Path $scriptDir "staging\wsl_update_x64.msi"
    
    Write-Host "Downloading WSL 2 kernel update..." -ForegroundColor Cyan
    curl.exe -L -o $wslUpdatePath https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi
    
    Write-Host "Installing WSL 2 kernel update..." -ForegroundColor Cyan
    Start-Process msiexec.exe -ArgumentList "/i `"$wslUpdatePath`" /quiet /norestart" -Wait -NoNewWindow
    
    Write-Host "Updating WSL to latest version..." -ForegroundColor Cyan
    wsl --update
    
    Write-Host "Setting WSL default version to 2..." -ForegroundColor Cyan
    wsl --set-default-version 2
    
    Write-Host "Cleaning up..." -ForegroundColor Cyan
    Remove-Item $wslUpdatePath -Force -ErrorAction SilentlyContinue
    
    Set-InstallStatus -Stage "WSL2Installed"
    
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "WSL 2 installed successfully!" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Green
}

function Stage-InstallLinux {
    param($Config)
    
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "Stage 3: Installing Linux Distribution" -ForegroundColor Yellow
    Write-Host "========================================`n" -ForegroundColor Yellow
    
    Write-Host "Configuration:" -ForegroundColor Cyan
    Write-Host "  WSL Name: $($Config.wslName)" -ForegroundColor White
    Write-Host "  Installation Path: $($Config.wslInstallationPath)" -ForegroundColor White
    Write-Host "  Username: $($Config.username)" -ForegroundColor White
    if ($Config.distributionName) {
        Write-Host "  Distribution: $($Config.distributionName)" -ForegroundColor White
    } else {
        Write-Host "  Distribution: (will be selected interactively)" -ForegroundColor White
    }
    Write-Host "  Install All Software: $($Config.installAllSoftware)`n" -ForegroundColor White
    
    # Call the generalized Linux distribution installation script
    $installScript = Join-Path $scriptDir "installLinuxDistro.ps1"
    
    if ($Config.distributionName) {
        & $installScript -wslName $Config.wslName `
                         -wslInstallationPath $Config.wslInstallationPath `
                         -username $Config.username `
                         -distributionName $Config.distributionName `
                         -installAllSoftware $Config.installAllSoftware
    } else {
        & $installScript -wslName $Config.wslName `
                         -wslInstallationPath $Config.wslInstallationPath `
                         -username $Config.username `
                         -installAllSoftware $Config.installAllSoftware
    }
    
    # Check if Linux installation succeeded
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n========================================" -ForegroundColor Red
        Write-Host "ERROR: Linux distribution installation failed!" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "Exit code: $LASTEXITCODE" -ForegroundColor Yellow
        Write-Host "`nThe installation state has been preserved." -ForegroundColor Yellow
        Write-Host "You can review the error and run the script again to retry.`n" -ForegroundColor Yellow
        Exit 1
    }
    
    Set-InstallStatus -Stage "Completed"
    
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "Linux distribution installed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "`nWSL 2 installation completed!" -ForegroundColor Green
    Write-Host "You can now launch your WSL instance with: wsl -d $($Config.wslName)`n" -ForegroundColor Yellow
}

################################################################################
# Main Installation Flow
################################################################################

Write-Host @"

################################################################################
#                                                                              #
#               WSL 2 Automatic Installation Script                           #
#                                                                              #
################################################################################

"@ -ForegroundColor Cyan

$status = Get-InstallStatus

switch ($status.Stage) {
    "Initial" {
        # Check if WSL is already enabled
        if (Test-WSLFeatureEnabled) {
            Write-Host "WSL features are already enabled." -ForegroundColor Green
            
            # Check if WSL 2 is also installed
            if (Test-WSL2Installed) {
                Write-Host "WSL 2 kernel is already installed." -ForegroundColor Green
                Write-Host "Skipping directly to Ubuntu installation...`n" -ForegroundColor Green
                Set-InstallStatus -Stage "WSL2Installed"
            } else {
                Write-Host "Proceeding to WSL 2 installation...`n" -ForegroundColor Green
                Set-InstallStatus -Stage "WSLEnabled"
            }
            
            # Get configuration
            $config = Get-UserInput
            Save-Configuration -Config $config
            
            # Continue based on what's already installed
            if (Test-WSL2Installed) {
                # Skip directly to Linux installation
                Stage-InstallLinux -Config $config
            } else {
                # Install WSL2 first, then Linux
                Stage-InstallWSL2
                Stage-InstallLinux -Config $config
            }
            
            # Clean up
            Unregister-ContinuationTask
            Remove-Item $statusFile -Force -ErrorAction SilentlyContinue
            Remove-Item $configFile -Force -ErrorAction SilentlyContinue
        } else {
            # Get configuration before enabling WSL (in case of reboot)
            $config = Get-UserInput
            Save-Configuration -Config $config
            
            # Enable WSL features
            Stage-EnableWSL
        }
    }
    
    "WSLEnabled" {
        Write-Host "Continuing installation after reboot...`n" -ForegroundColor Green
        
        # Verify WSL is actually enabled
        if (-not (Test-WSLFeatureEnabled)) {
            Write-Host "ERROR: WSL features are not enabled. Something went wrong." -ForegroundColor Red
            Write-Host "Please check Windows Features and ensure WSL is enabled.`n" -ForegroundColor Red
            Exit 1
        }
        
        # Load saved configuration
        $config = Get-Configuration
        
        if ($null -eq $config) {
            Write-Host "ERROR: Configuration file not found. Please run the installation again." -ForegroundColor Red
            Exit 1
        }
        
        # Continue with WSL2 and Linux installation
        Stage-InstallWSL2
        Stage-InstallLinux -Config $config
        
        # Clean up
        Unregister-ContinuationTask
        Remove-Item $statusFile -Force -ErrorAction SilentlyContinue
        Remove-Item $configFile -Force -ErrorAction SilentlyContinue
        
        Write-Host "`nInstallation complete! Press Enter to exit..." -ForegroundColor Green
        Read-Host
    }
    
    "WSL2Installed" {
        Write-Host "WSL 2 is already installed. Continuing with Linux installation...`n" -ForegroundColor Green
        
        $config = Get-Configuration
        
        if ($null -eq $config) {
            # No saved config - this is a fresh run, not a continuation
            # Get configuration from parameters or prompt
            $config = Get-UserInput
            Save-Configuration -Config $config
        }
        
        Stage-InstallLinux -Config $config
        
        # Clean up
        Unregister-ContinuationTask
        Remove-Item $statusFile -Force -ErrorAction SilentlyContinue
        Remove-Item $configFile -Force -ErrorAction SilentlyContinue
    }
    
    "Completed" {
        Write-Host "Installation was already completed!`n" -ForegroundColor Green
        
        # Clean up
        Unregister-ContinuationTask
        Remove-Item $statusFile -Force -ErrorAction SilentlyContinue
        Remove-Item $configFile -Force -ErrorAction SilentlyContinue
        
        $config = Get-Configuration
        if ($config) {
            Write-Host "You can launch your WSL instance with: wsl -d $($config.wslName)`n" -ForegroundColor Yellow
        }
    }
}
