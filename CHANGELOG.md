# Changelog

## 2026-01-14
- **Bug Fix**: Fixed nested .appx architecture handling in `installLinuxDistro.ps1`
  - Detects multi-architecture distribution packages (e.g., Debian)
  - Automatically selects appropriate architecture package (x64, ARM64, or x86)
  - Extracts nested .appx files to find install.tar.gz
  - Improved error messages showing extract contents when tar.gz not found
  - Resolves installation failures for distributions with bundled architecture variants

## 2026-01-09
- **Major Feature**: Generalized Linux distribution installer (`installLinuxDistro.ps1`)
  - Fetches available distributions from Microsoft's official GitHub repository
  - Supports interactive distribution selection from menu
  - Supports command-line distribution specification for unattended install
  - Detects package family (Debian, RedHat, SUSE, Alpine) for appropriate configuration
  - User creation adapted per distribution family
  - Checkpoint/resume functionality with SHA256 verification
  - Replaces Ubuntu-specific installer with flexible solution
  - `installWSLAutomatic.ps1` updated to use new generalized installer
  - Software installation currently supported for Debian-based distributions only
- **Major Feature**: Added checkpoint/resume functionality to `installUbuntuLTS.ps1`
  - Creates checkpoint after downloading Ubuntu appx (900+ MB file)
  - Allows resuming installation after crashes or interruptions
  - Verifies file integrity using SHA256 checksum before proceeding
  - Prevents re-downloading if file already exists and checksum matches
  - Preserves installation archives until WSL distribution is successfully imported
  - Only cleans up files after complete successful installation
  - Interactive prompts to resume from checkpoint or start fresh
- **Enhancement**: Added WSL 2 kernel detection to `installWSLAutomatic.ps1`
  - Checks if WSL 2 kernel is already installed before downloading
  - Skips kernel installation if already present
  - Saves time and bandwidth on systems with WSL 2 already installed
  - Intelligently routes to appropriate installation stage based on current state
- **Enhancement**: Improved error handling and script collaboration
  - `installWSLAutomatic.ps1` now properly detects failures in `installUbuntuLTS.ps1`
  - Added exit code checking for all WSL commands in `installUbuntuLTS.ps1`
  - System update, user creation, and software installation failures now properly exit with error codes
  - Clear error messages indicate which step failed
  - Installation state preserved on failure for easier debugging and retry
- **Bug Fix**: Fixed checkpoint resume issue with file renaming
  - Appx file now keeps original name (`ubuntuLTS.appx`) during extraction
  - Checkpoint resume now works correctly without re-downloading
  - Uses temporary file for extraction instead of renaming original
  - Prevents breaking checkpoint functionality when installation fails mid-process

## 2026-01-08
- **Major Feature**: Added fully automatic installation with `installWSLAutomatic.ps1`
  - Handles the complete WSL 2 installation process from start to finish
  - Automatically continues after required reboot using scheduled tasks
  - Saves configuration state across reboots
  - Supports both interactive and unattended installation modes
  - Eliminates manual steps between `enableWSL.ps1` and `installWSL2.ps1`
- Added comprehensive documentation:
  - `INSTALL-AUTOMATIC.md` - Detailed guide for automatic installation
  - `QUICK-REFERENCE.md` - Quick command reference for all installation methods
  - `example-automatic-install.ps1` - Example script showing unattended usage
- Updated `README.md` to feature the automatic installation method
- **Fixed**: Added `wsl --update` step before setting default version to 2
  - Resolves "Windows Subsystem for Linux must be updated" error
  - Applied to both `installWSL2.ps1` and `installWSLAutomatic.ps1`
- **Fixed**: Improved Ubuntu installation robustness in `installUbuntuLTS.ps1`
  - Now dynamically finds the .tar.gz file instead of hardcoding path
  - Added error checking for WSL import operation
  - Added verification that distribution was imported successfully
  - Added informative progress messages throughout installation
  - Improved error handling and reporting

## 2021-09-29
- Added OpenVSCode Server

## 2021-09-28
- Fixed Issue #1: Staging area is now created if it does not exist
- Fixed Issue #2: Updated [README.md](./README.md) and updated default wsl.conf
- Updated docker-compose from `1.28.4` to `2.0.0`. Command is now `docker compose` instead of `docker-compose`
- Updated Gradle from `6.8.3`to `7.2`
- Updated Apache Maven to from `3.6.3` to `3.8.2`
- n install the latest nodejs version instead of lts version
- All other software packages are installed with the latest version
- Added [.gitattributes](.gitattributes) config to ensure sh files stay with lf line ending 
- Introduced this changelog
