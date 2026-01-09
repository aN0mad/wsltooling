################################################################################
# WSL 2 Installation Script
# This script installs the WSL 2 kernel and sets WSL 2 as the default version
################################################################################

Write-Host "WSL 2 Installation" -ForegroundColor Cyan
Write-Host "==================`n" -ForegroundColor Cyan

# Check if Virtual Machine Platform is enabled
$vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue

if ($null -eq $vmFeature -or $vmFeature.State -ne "Enabled") {
    Write-Warning "Virtual Machine Platform is not enabled!"
    Write-Host "`nUsing the recommended method to enable WSL features..." -ForegroundColor Yellow
    Write-Host "Running: wsl.exe --install --no-distribution`n" -ForegroundColor Cyan
    
    wsl.exe --install --no-distribution
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install WSL features. Exit code: $LASTEXITCODE"
        Write-Host "`nYou may need to:" -ForegroundColor Yellow
        Write-Host "  1. Enable virtualization in your BIOS" -ForegroundColor White
        Write-Host "  2. Run this script as Administrator" -ForegroundColor White
        Write-Host "  3. Reboot after installation" -ForegroundColor White
        Exit 1
    }
    
    Write-Host "`n[OK] WSL features installed" -ForegroundColor Green
    Write-Host "`nA REBOOT IS REQUIRED before WSL 2 will work." -ForegroundColor Yellow
    Write-Host "Please reboot your system, then run this script again.`n" -ForegroundColor Yellow
    
    $reboot = Read-Host "Reboot now? (Y/N)"
    if ($reboot -eq 'Y' -or $reboot -eq 'y') {
        Write-Host "Rebooting in 10 seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    }
    Exit 0
}

Write-Host "[OK] Virtual Machine Platform is enabled" -ForegroundColor Green

# Create staging directory if it does not exist
if (-Not (Test-Path -Path .\staging)) { 
    $dir = New-Item -ItemType Directory -Path .\staging
}

Write-Host "`nDownloading WSL 2 kernel update..." -ForegroundColor Cyan
curl.exe -L -o .\staging\wsl_update_x64.msi https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi

Write-Host "Installing WSL 2 kernel update..." -ForegroundColor Cyan
Start-Process msiexec.exe -ArgumentList "/i `".\staging\wsl_update_x64.msi`" /quiet /norestart" -Wait -NoNewWindow

Write-Host "Updating WSL to latest version..." -ForegroundColor Cyan
wsl --update

Write-Host "Setting WSL default version to 2..." -ForegroundColor Cyan
wsl --set-default-version 2

Write-Host "Cleaning up..." -ForegroundColor Cyan
Remove-Item .\staging\wsl_update_x64.msi -Force -ErrorAction SilentlyContinue

Write-Host "`n[OK] WSL 2 installation completed successfully!`n" -ForegroundColor Green
