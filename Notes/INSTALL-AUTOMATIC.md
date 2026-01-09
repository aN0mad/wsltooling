# Automatic WSL 2 Installation Guide

This guide explains how to use the fully automated WSL 2 installation script that handles reboots and continues automatically.

## Quick Start

### Prerequisites
- Windows 10 version 2004 or higher, or Windows 11
- Administrator access
- Internet connection

### One-Command Installation

1. **Open PowerShell as Administrator**
   - Right-click on the Start menu
   - Select "Windows PowerShell (Admin)" or "Terminal (Admin)"

2. **Navigate to the repository directory**
   ```powershell
   cd path\to\wsltooling
   ```

3. **Run the automatic installation script**
   ```powershell
   .\installWSLAutomatic.ps1
   ```

4. **Follow the prompts**
   - Enter your WSL instance name (e.g., `devbox`)
   - Enter installation path (e.g., `D:\WSL2\devbox`)
   - Enter your username
   - Choose whether to install all software (`true` or `false`)

5. **Let it handle the reboot**
   - If WSL features need to be enabled, the script will prompt for a reboot
   - After reboot, **log back in** - the script will continue automatically
   - Wait for the installation to complete

### Non-Interactive Installation

You can also provide all parameters upfront for a completely unattended installation:

```powershell
.\installWSLAutomatic.ps1 -wslName "devbox" `
                          -wslInstallationPath "D:\WSL2\devbox" `
                          -username "yourname" `
                          -installAllSoftware "true"
```

## How It Works

The script uses a multi-stage approach with automatic continuation and intelligent detection:

### Stage 0: Detection (Smart Skip)
- Checks if WSL features are already enabled
- Checks if WSL 2 kernel is already installed
- Skips unnecessary steps automatically
- Jumps directly to the appropriate stage

### Stage 1: Enable WSL Features
- Enables Microsoft-Windows-Subsystem-Linux
- Enables VirtualMachinePlatform
- Registers a scheduled task to continue after reboot
- Prompts for reboot (or auto-reboots if you choose)
- **Skipped** if features are already enabled

### Stage 2: Install WSL 2 (After Reboot)
- Automatically runs when you log back in
- Downloads and installs the WSL 2 kernel update
- Updates WSL to latest version
- Sets WSL default version to 2
- **Skipped** if WSL 2 kernel is already installed

### Stage 3: Install Ubuntu LTS
- Downloads Ubuntu 20.04 LTS (with checkpoint/resume capability)
- Imports into WSL 2
- Creates your user account
- Optionally installs all software packages

### Stage 4: Cleanup
- Removes the scheduled task
- Cleans up temporary files
- Reports completion

## State Management

The script maintains its state across reboots using JSON files in the `staging` folder:

- `staging/install-status.json` - Tracks the current installation stage
- `staging/install-config.json` - Stores your installation configuration

These files are automatically cleaned up when installation completes.

## What Gets Installed (if installAllSoftware = true)

The following software will be automatically installed in your WSL instance, if configured in `./scripts/install/installAllSoftware.sh`:

- **Base Packages**: git, virt-manager, firefox, dbus-x11, x11-apps, make, unzip
- **OpenVSCode Server**: Web-based VS Code (runs on port 3000)
- **Docker & Docker Compose V2**
- **OpenJDK 11**
- **Apache Maven**
- **Gradle**
- **Node.js** (via n - node version manager), npm, and TypeScript
- **Rust and Cargo**
- **Deno**
- **Google Chrome**
- **KVM & QEMU**

## Smart Detection

The script intelligently detects what's already installed and skips unnecessary steps:

### First Run on Fresh System
```
Stage 0: Detection → No WSL features found
Stage 1: Enable WSL features → Reboot required
[After reboot]
Stage 2: Install WSL 2 kernel
Stage 3: Install Ubuntu
```

### Run on System with WSL Already Enabled
```
Stage 0: Detection → WSL features found, no WSL 2 kernel
Stage 2: Install WSL 2 kernel (skip reboot!)
Stage 3: Install Ubuntu
```

### Run on System with WSL 2 Already Installed
```
Stage 0: Detection → WSL features and WSL 2 kernel found
Stage 3: Install Ubuntu (skip everything else!)
```

This means:
- ✅ No unnecessary downloads
- ✅ No unnecessary reboots
- ✅ Faster installation on systems with partial setup
- ✅ Safe to re-run the script

## Troubleshooting

### The script doesn't continue after reboot
- Check the Task Scheduler for "WSL2AutoInstallContinuation" task
- Make sure you logged in with the same user account
- Run the script again manually - it will detect the current stage and continue

### Script fails with "must be run as Administrator"
- Right-click PowerShell and select "Run as Administrator"
- In Windows Terminal, use Ctrl+Shift+Enter when launching a new tab

### Execution Policy errors
The script automatically sets the execution policy for the current session, but if you still have issues:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### Want to start over?
Delete the staging folder and run the script again:
```powershell
Remove-Item -Recurse -Force .\staging
.\installWSLAutomatic.ps1
```

## Comparison with Manual Installation

### Old Way (Manual)
1. Check if WSL is enabled manually
2. Run `enableWSL.ps1` as admin
3. Manually reboot
4. Log back in
5. Open PowerShell as admin again
6. Check if WSL 2 is installed manually
7. Run `installWSL2.ps1` as admin
8. Run `installUbuntuLTS.ps1` with parameters

### New Way (Automatic)
1. Run `installWSLAutomatic.ps1` as admin (with or without parameters)
2. Script auto-detects what's already installed
3. Reboot when prompted (only if needed, or let it auto-reboot)
4. Log back in (only if reboot was needed)
5. **Done!** (script continues automatically and skips what's already installed)

## Advanced Usage

### Skip the reboot prompt
If you're confident and want the script to reboot immediately without asking:

Modify the script or press 'Y' when prompted.

### Resume from a specific stage
The script automatically detects and resumes from the current stage. To manually reset:

```powershell
# Reset to initial state
Remove-Item .\staging\install-status.json

# Reset to specific stage (edit the JSON file)
@{ Stage = "WSLEnabled"; Timestamp = (Get-Date).ToString() } | ConvertTo-Json | Set-Content .\staging\install-status.json
```

## Security Notes

- The script creates a scheduled task that runs with highest privileges
- The task is automatically removed when installation completes
- Configuration files may contain your chosen username
- All files are stored locally in the `staging` folder

## Support

For issues or questions:
- Check the main [README.md](README.md) for general WSL usage
- Review the individual scripts: `enableWSL.ps1`, `installWSL2.ps1`, `installUbuntuLTS.ps1`
- Verify Windows version compatibility

---

**Note**: This automatic installer wraps the existing manual installation scripts and adds state management and automatic continuation. The underlying installation process remains the same.
