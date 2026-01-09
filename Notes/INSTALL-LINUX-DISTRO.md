# Linux Distribution Installation Guide

This guide explains how to use the generalized Linux distribution installer that supports any WSL distribution from Microsoft's official list.

## Overview

The `installLinuxDistro.ps1` script replaces the Ubuntu-specific installer with a flexible solution that:
- Fetches the latest distribution list from Microsoft's GitHub
- Supports interactive distribution selection
- Works with Debian, Red Hat, SUSE, Alpine, and other Linux families
- Includes checkpoint/resume functionality
- Handles user creation appropriately for each distribution family

## Quick Start

### Interactive Mode (Recommended)

```powershell
.\installLinuxDistro.ps1
```

The script will:
1. Fetch the list of available distributions
2. Display a menu for you to choose from
3. Prompt for WSL name, installation path, and username
4. Download and install your chosen distribution

### Unattended Mode

```powershell
.\installLinuxDistro.ps1 -wslName "mylinux" `
                         -wslInstallationPath "D:\WSL2\mylinux" `
                         -username "ryan" `
                         -distributionName "Ubuntu-22.04" `
                         -installAllSoftware "false"
```

## Parameters

| Parameter | Required | Description | Example |
|-----------|----------|-------------|---------|
| `-wslName` | No* | Name for the WSL instance | `"devbox"` |
| `-wslInstallationPath` | No* | Path where VHDX will be stored | `"D:\WSL2\devbox"` |
| `-username` | No* | Linux username to create | `"ryan"` |
| `-distributionName` | No | Specific distribution to install | `"Ubuntu-22.04"` |
| `-installAllSoftware` | No | Install additional software (Debian only) | `"true"` or `"false"` |

\* If not provided, you'll be prompted interactively

## Supported Distributions

The script fetches the current list from:
`https://github.com/microsoft/WSL/blob/master/distributions/DistributionInfo.json`

This typically includes:
- **Ubuntu** (various versions)
- **Debian**
- **Kali Linux**
- **openSUSE** (Leap, Tumbleweed)
- **SUSE Linux Enterprise**
- **Alpine Linux**
- **Fedora**
- **Oracle Linux**
- **Pengwin**
- And more...

## Distribution Families

The script automatically detects the distribution family and applies appropriate configuration:

### Debian-based
- **Distributions**: Ubuntu, Debian, Kali, Pengwin
- **Package Manager**: apt
- **Sudo Group**: sudo
- **Software Installation**: Fully supported

### Red Hat-based
- **Distributions**: Fedora, Oracle Linux
- **Package Manager**: dnf/yum
- **Sudo Group**: wheel
- **Software Installation**: Not yet supported

### SUSE-based
- **Distributions**: openSUSE, SUSE Linux Enterprise
- **Package Manager**: zypper
- **Sudo Group**: wheel
- **Software Installation**: Not yet supported

### Alpine
- **Distributions**: Alpine Linux
- **Package Manager**: apk
- **Shell**: ash (not bash)
- **Software Installation**: Not yet supported

## Examples

### Install Ubuntu 22.04

```powershell
.\installLinuxDistro.ps1 -distributionName "Ubuntu-22.04" `
                         -wslName "ubuntu22" `
                         -wslInstallationPath "C:\WSL\ubuntu22" `
                         -username "myuser"
```

### Install Debian (Interactive)

```powershell
.\installLinuxDistro.ps1
# Select Debian from the menu when prompted
```

### Install Fedora

```powershell
.\installLinuxDistro.ps1 -distributionName "Fedora" `
                         -wslName "fedora" `
                         -wslInstallationPath "D:\WSL2\fedora" `
                         -username "admin"
```

### Install Alpine Linux

```powershell
.\installLinuxDistro.ps1 -distributionName "Alpine" `
                         -wslName "alpine" `
                         -wslInstallationPath "D:\WSL2\alpine" `
                         -username "alpineuser"
```

## Checkpoint and Resume

Just like the Ubuntu installer, this script supports checkpoint/resume:

```powershell
# First attempt - download succeeds, import fails
.\installLinuxDistro.ps1 -distributionName "Ubuntu-22.04" ...

# Fix the issue, retry
.\installLinuxDistro.ps1 -distributionName "Ubuntu-22.04" ...
# Prompt: Resume from checkpoint? Y
# Uses cached download, retries import
```

See [CHECKPOINT-RECOVERY.md](CHECKPOINT-RECOVERY.md) for details.

## Software Installation

Currently, automatic software installation (via `-installAllSoftware "true"`) is only supported for **Debian-based** distributions.

This includes:
- Base packages (git, firefox, etc.)
- OpenVSCode Server
- Docker
- Development tools (Java, Maven, Gradle, Node.js, etc.)

For other distribution families, you'll need to install software manually after the distribution is set up.

## User Creation

The script creates a user and configures sudo access automatically:

### Debian/Ubuntu/Kali
```bash
useradd -m -s /bin/bash $username
usermod -aG sudo $username
echo '$username ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$username
```

### Fedora/Oracle/Red Hat
```bash
useradd -m -s /bin/bash $username
usermod -aG wheel $username
echo '$username ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$username
```

### Alpine
```bash
adduser -D -s /bin/ash $username
echo '$username ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$username
```

The user is also set as the default user in `/etc/wsl.conf`.

## Troubleshooting

### Distribution not in list

If your distribution isn't showing up:
1. Check Microsoft's official list: https://github.com/microsoft/WSL/blob/master/distributions/DistributionInfo.json
2. Ensure you have internet connectivity
3. The distribution might not be officially supported

### User creation fails

For unknown or custom distributions:
```powershell
# The script will warn and skip user creation
# You'll need to create the user manually:
wsl -d mylinux -u root
# Then inside WSL:
useradd -m -s /bin/bash myuser
passwd myuser
usermod -aG sudo myuser  # or wheel, depending on distro
```

### Software installation not working

Software installation currently only works for Debian-based distributions. For others:
```powershell
# Install manually after setup
wsl -d mylinux
# Then use the distribution's package manager:
# Fedora: sudo dnf install ...
# openSUSE: sudo zypper install ...
# Alpine: sudo apk add ...
```

### Download URL not found

Some distributions in the JSON might not have `Amd64PackageUrl` or `PackageUrl` fields. The script will error out. You may need to manually specify the download URL by modifying the script temporarily.

## Integration with Automatic Installer

The automatic installer (`installWSLAutomatic.ps1`) now uses this generalized script:

```powershell
.\installWSLAutomatic.ps1 -distributionName "Debian" `
                          -wslName "debian" `
                          -wslInstallationPath "C:\WSL\debian" `
                          -username "ryan"
```

All the same automatic reboot handling, WSL 2 detection, and error handling applies.

## Comparison with Old Ubuntu Installer

| Feature | installUbuntuLTS.ps1 | installLinuxDistro.ps1 |
|---------|---------------------|------------------------|
| Distributions | Ubuntu 20.04 only | Any official WSL distro |
| Distribution selection | Hardcoded | Interactive or CLI parameter |
| User creation | Ubuntu/Debian specific | Family-aware |
| Software install | Ubuntu/Debian scripts | Debian-based only (for now) |
| Checkpoint/resume | ✅ | ✅ |
| Checksum verification | ✅ | ✅ |

## Future Enhancements

Planned improvements:
- [ ] Software installation support for Red Hat-based distributions
- [ ] Software installation support for SUSE-based distributions
- [ ] Software installation support for Alpine
- [ ] Custom distribution URL support
- [ ] Architecture selection (ARM64 support)
- [ ] Distribution-specific post-install configurations

## Legacy Ubuntu Installer

The original `installUbuntuLTS.ps1` is still available for backward compatibility but is no longer actively maintained. New users should use `installLinuxDistro.ps1`.

---

This flexible installer makes it easy to set up any Linux distribution in WSL 2 with just a few commands!
