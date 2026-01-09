Automated creation of WSL 2 Development Machine
===

Welcome to the WSL Tooling repository. The aim of this project is to supply you with the ability to automatically install a fully working WSL 2 development environment just by invoking a powershell script even without the `wsl --install` flag.

I have fully reworked and updated the whole installation. Once your Windows is capable of running WSL 2 instances, Linux distribution installation is fully automatic with support for **any official WSL distribution**.

## 🚀 Quick Start - Fully Automatic Installation

**NEW!** For a completely automated installation that handles reboots and continues automatically:

```powershell
# Run as Administrator - Interactive mode (choose your Linux distribution)
.\installWSLAutomatic.ps1
```

**Or specify your preferred distribution:**

```powershell
# Run as Administrator - Unattended mode
.\installWSLAutomatic.ps1 -distributionName "Ubuntu-22.04" `
                          -wslName "devbox" `
                          -wslInstallationPath "D:\WSL2\devbox" `
                          -username "yourname" `
                          -installAllSoftware "false"
```

The script will:
- Enable WSL features if needed
- Handle the required reboot and continue automatically after you log back in
- Install WSL 2 kernel update
- Let you choose from any official Linux distribution (or use the one specified)
- Install and configure your chosen distribution
- Optionally install development tools (Debian-based distributions only)

See [INSTALL-AUTOMATIC.md](INSTALL-AUTOMATIC.md) for detailed instructions and options.

## 🐧 Supported Linux Distributions

The installer supports **any distribution** from Microsoft's official WSL catalog, including:
- Ubuntu (multiple versions)
- Debian
- Kali Linux
- Fedora
- openSUSE
- Alpine Linux
- Oracle Linux
- And more...

See [INSTALL-LINUX-DISTRO.md](INSTALL-LINUX-DISTRO.md) for the complete guide.

---

## Manual Installation (Traditional Method)

If you prefer manual control over each step, follow the instructions below.

### Preparation
This repository must be cloned on your local disk.

### Enable Windows Subsystem for Linux
***This step is only required if WSL support was never activated before on your Windows machine*** 

Open a powershell with **administrative** privileges and execute this script to enable WSL and VM platform on your machine.
It might be necessary to adjust the security policy (see first commnd below) because the Powershell scripts are not digitally signed (https:/go.microsoft.com/fwlink/?LinkID=135170):
```powershell
# Optional: Set Security to Bypass
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
# Enable WSL
.\enableWSL.ps1
```
This will take a couple of minutes. If it was not enabled before, you need to reboot Windows.

A restart is required if any of the two above features have not been installed before.

### Set WSL default version to 2

Set the default WSL version to 2. Open a powershell with administrative privileges:
```powershell
.\installWSL2.ps1
```

## Distribution Installation

### Download and Install Ubuntu LTS (20.04)
If not already done, open a new powershell with administrative privileges and install Ubuntu LTS. You **need** to provide four arguments. If you don't specify them on command line, then the script will ask:
- `<wslName>`: Provide a name for the WSL that is goind to be created (e.g. `devbox`)
- `<wslInstallationPath>`: The directory where the vhdx disk of the new WSL is stored
- `<username>`: the name of the user that is used when WSL distro is launched without `-u`
- `<installAllSoftware>`: Use `true`|`false`. Tell if all software packages (see [Available Software](#Available-Software) and make modifications to `./scripts/installAllSoftware.sh`) shall be installed or if `false` only a fully updated system with configured user is supplied
For example, the command can look as follows:
```powershell
.\installUbuntuLTS.ps1 devbox D:\WSL2\devbox kai true
```

**New Feature**: The installation script includes checkpoint/resume functionality:
- Automatically creates checkpoints after downloading the large (900+ MB) Ubuntu file
- Can resume installation after interruptions or failures
- Verifies file integrity with SHA256 checksums
- See [CHECKPOINT-RECOVERY.md](CHECKPOINT-RECOVERY.md) for details

### Available Software Package
If don't want to install all packages during initial WSL creation, you can install them one buy one. They are available here [./scripts](./scripts). These are currently available
- Ubuntu Base Package (git, virt-manager, firefox, dbus-x11, x11-apps, make, unzip) ([scripts/install/installBasePackages.sh](./scripts/install/installBasePackages.sh))
- OpenVSCode Server ([scripts/install/installOpenVSCodeServer.sh](./scripts/install/installOpenVSCodeServer.sh)). It is started automatically when you start and log into the WSL on port 3000.
- docker & compose V2 ([scripts/install/installDocker.sh](./scripts/install/installDocker.sh))
- OpenJDK 11 ([scripts/install/installOpenjdk.sh](scripts/install/installOpenjdk.sh))
- Apache Maven ([scripts/install/installMaven.sh](./scripts/install/installMaven.sh))
- Gradle ([scripts/install/installGradle.sh](./scripts/install/installGradle.sh))
- n (node manager), Nodejs, npm & Typescript ([scripts/install/installNodejs.sh](./scripts/install/installNodejs.sh)
- Rust and Cargo ([scripts/install/installRust.sh](./scripts/install/installRust.sh))
- Deno ([scripts/install/installDeno.sh](./scripts/install/installDeno.sh))
- Google Chrome ([scripts/install/installChrome.sh](./scripts/install/installChrome.sh))
- KVM & Qemu ([scripts/install/installKvm.sh](./scripts/install/installKvm.sh))


Firefox and other tools can be installed directly with Ubuntu's package manager `apt`. Some of the above scripts also use `apt` and apply additional configuration.

#### Removal
Not available yet, but with a fast internet connection and fast SSD you have the WSL recreated in approx. five minutes. :sunglasses:

## Usage

### X-Server
***Once Windows 11 including WSLg is generally available this will become superfluous.***

I recommend to use [VcXsrv](https://sourceforge.net/projects/vcxsrv/) (also available via chocolatey) to connect to user interfaces launched from WSL on display 0. The WSL linux setup configures everything properly. Use the following Powershell script to launch (it assume vcxsrv is installed at default location `C:\Program Files\VcXsrv\vcxsrv.exe`):
```powershell
.\scripts\xserver\xerver.ps1
```

### Certificates
Copy any certificates you require under `/usr/local/share/ca-certificates/` and the run the command:
```bash
sudo update-ca-certificates
```

## Experiments

### Convert Docker to WSL2

I have created a CentOS 7 based Dockerfile that serves as a demonstrator. You can convert the container image to a WSL with to quick commands. For instructions look [here](./containers/centos7/README)).

## Misc
- My Terminal recommendation in 2021 clearly is [Microsoft Terminal](https://github.com/microsoft/terminal)
- Overview of [WSL commands and launch configurations](https://docs.microsoft.com/en-us/windows/wsl/wsl-config)
- For Development wiht Visual Studio Code use the `Remote - WSL` extension

Constructive feedback is appreciated!

Have fun!

Kai
