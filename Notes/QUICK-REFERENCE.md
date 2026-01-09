# WSL 2 Installation - Quick Reference

## Automatic Installation (Recommended)

### Interactive Mode
```powershell
# Open PowerShell as Administrator
.\installWSLAutomatic.ps1
```
- Follow the prompts to configure your installation
- Script will handle reboot and continue automatically

### Unattended Mode
```powershell
# Open PowerShell as Administrator
.\installWSLAutomatic.ps1 -wslName "devbox" `
                          -wslInstallationPath "D:\WSL2\devbox" `
                          -username "yourname" `
                          -installAllSoftware "true"
```
- All parameters provided upfront
- Minimal user interaction required

## Manual Installation (Traditional)

### Step 1: Enable WSL
```powershell
# Open PowerShell as Administrator
.\enableWSL.ps1
# REBOOT REQUIRED
```

### Step 2: Install WSL 2
```powershell
# Open PowerShell as Administrator (after reboot)
.\installWSL2.ps1
```

### Step 3: Install Ubuntu
```powershell
# Open PowerShell as Administrator
.\installUbuntuLTS.ps1 devbox D:\WSL2\devbox yourname true
```

## Common Commands

### Launch WSL
```powershell
wsl -d devbox
```

### List installed distributions
```powershell
wsl --list --verbose
```

### Set default distribution
```powershell
wsl --set-default devbox
```

### Stop a running distribution
```powershell
wsl --terminate devbox
```

### Unregister a distribution
```powershell
wsl --unregister devbox
```

## Troubleshooting

### Resume from checkpoint (Ubuntu installation)
```powershell
# Script automatically detects and offers to resume
.\installUbuntuLTS.ps1 devbox D:\WSL2\devbox yourname true

# Clear checkpoint to start fresh
Remove-Item .\staging\ubuntu-install-checkpoint.json
```

### Automatic installation stuck?
```powershell
# Check scheduled task
Get-ScheduledTask -TaskName "WSL2AutoInstallContinuation"

# Manually trigger continuation (as Admin)
.\installWSLAutomatic.ps1
```

### Reset automatic installation
```powershell
# Remove state files and start over
Remove-Item -Recurse -Force .\staging
.\installWSLAutomatic.ps1
```

### Check WSL version
```powershell
wsl --version
```

### Update WSL
```powershell
wsl --update
```

## Files

| File | Purpose |
|------|---------|
| `installWSLAutomatic.ps1` | Fully automatic installation with reboot handling |
| `enableWSL.ps1` | Enable WSL features (manual step 1) |
| `installWSL2.ps1` | Install WSL 2 kernel (manual step 2) |
| `installUbuntuLTS.ps1` | Install Ubuntu LTS (manual step 3) |
| `INSTALL-AUTOMATIC.md` | Detailed automatic installation guide |
| `README.md` | Complete documentation |

## Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `-wslName` | Name of WSL instance | `devbox` |
| `-wslInstallationPath` | Where to store the WSL VHDX | `D:\WSL2\devbox` |
| `-username` | Linux username to create | `yourname` |
| `-installAllSoftware` | Install all dev tools | `true` or `false` |
