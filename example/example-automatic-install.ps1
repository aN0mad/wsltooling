# Example: Fully Automated WSL Installation
# This script demonstrates how to run a completely unattended installation

# Configuration
$wslName = "devbox"
$wslInstallationPath = "D:\WSL2\devbox"
$username = "developer"
$installAllSoftware = "true"
$distribution = "ubuntu"

# Run the automatic installation with all parameters
.\installWSLAutomatic.ps1 -wslName $wslName `
                          -wslInstallationPath $wslInstallationPath `
                          -username $username `
                          -installAllSoftware $installAllSoftware `
                          -distributionName $distribution

# Note: If a reboot is required, the script will prompt you
# After reboot and logon, it will continue automatically
