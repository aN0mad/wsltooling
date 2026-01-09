# Distribution Name Validation

## Overview

The automatic WSL installation script (`installWSLAutomatic.ps1`) now validates the distribution name **at the very beginning** of the installation process, before enabling WSL features or rebooting.

## Why This Matters

Previously, if you provided an invalid distribution name:
1. ✅ WSL features would be enabled
2. ✅ System would reboot
3. ✅ WSL 2 kernel would be installed
4. ❌ **Distribution installation would fail** (after 10-15 minutes)

Now, validation happens immediately:
1. ✅ Distribution name is validated (takes ~2 seconds)
2. ❌ If invalid, exits immediately with helpful error
3. ✅ If valid, proceeds with installation

## How It Works

### Validation Function

The `Validate-DistributionName` function:
- Fetches the official distribution list from Microsoft's GitHub
- Checks both exact names and aliases
- Provides helpful error messages with suggestions
- Handles network errors gracefully (continues installation)

### Validation Timing

The validation is called in `Get-UserInput` function, which runs:
- **Before Stage 1** (EnableWSL) - when starting fresh
- **Before Stage 2** (InstallWSL2) - when continuing after reboot
- **Before Stage 3** (InstallLinux) - final safety check

### What Gets Validated

✅ **Exact distribution names**: `Ubuntu-22.04`, `Debian`, etc.
✅ **Common aliases**: `ubuntu`, `debian`, `kali`, `fedora`, `opensuse`, `alpine`, `oracle`
✅ **Empty string**: Interactive mode (no validation needed)
❌ **Invalid names**: `centos`, `invalidDistro123`, typos

## Usage Examples

### Valid - Using Alias
```powershell
.\installWSLAutomatic.ps1 -distributionName ubuntu -wslName myubuntu -wslInstallationPath C:\WSL\myubuntu -username myuser
```
Output:
```
Validating distribution name 'ubuntu'...
✓ Distribution 'ubuntu' will resolve to 'Ubuntu-22.04'
```

### Valid - Using Exact Name
```powershell
.\installWSLAutomatic.ps1 -distributionName "Ubuntu-22.04" -wslName myubuntu -wslInstallationPath C:\WSL\myubuntu -username myuser
```
Output:
```
Validating distribution name 'Ubuntu-22.04'...
✓ Distribution 'Ubuntu-22.04' validated successfully
```

### Invalid - Typo
```powershell
.\installWSLAutomatic.ps1 -distributionName ubunto -wslName myubuntu -wslInstallationPath C:\WSL\myubuntu -username myuser
```
Output:
```
Validating distribution name 'ubunto'...

========================================
ERROR: Invalid Distribution Name
========================================

Distribution 'ubunto' not found in the official list.

Common distribution names:
  ubuntu, debian, kali, fedora, opensuse, alpine, oracle

To see all available distributions, run:
  .\installLinuxDistro.ps1 -listDistributions

Exiting due to invalid distribution name.
```

### Valid - Interactive Mode
```powershell
.\installWSLAutomatic.ps1 -wslName myubuntu -wslInstallationPath C:\WSL\myubuntu -username myuser
```
Output:
```
(No validation - will show interactive menu during installation)
```

## Error Handling

### Network Errors
If the validation cannot fetch the distribution list (e.g., no internet):
- Shows a warning
- **Continues with installation** (validation will happen later in installLinuxDistro.ps1)
- Prevents installation failure due to temporary network issues

### Invalid Names
If the distribution name is invalid:
- Shows clear error message
- Lists common distribution names
- Suggests running with `-listDistributions` flag
- **Exits immediately** with error code 1

## Testing

Run the test script to verify validation logic:

```powershell
.\test-distro-validation.ps1
```

This tests:
- Valid aliases (ubuntu, debian, kali)
- Exact version names (Ubuntu-22.04)
- Invalid names (centos, typos)
- Empty strings (interactive mode)

## Benefits

1. **Fail Fast**: Invalid input detected in seconds, not after reboot
2. **Better UX**: Clear error messages with helpful suggestions
3. **Time Saving**: No wasted time on reboots/installations that will fail
4. **Automated Installations**: Safe for scripts/automation - catches config errors early
5. **Graceful Degradation**: Network errors don't block installation

## Technical Details

### Validation Logic
```powershell
1. If distributionName is empty → Return true (interactive mode)
2. Fetch distribution list from GitHub
3. Check exact match with distribution name
4. Check partial match using aliases
5. If match found → Return true
6. If no match → Show error and return false
```

### Called From
- `Get-UserInput` function (lines 208-246 in installWSLAutomatic.ps1)
- Runs before saving configuration
- Runs before any installation stages

### Integration Points
- Works with all distribution aliases
- Uses same alias mapping as `installLinuxDistro.ps1`
- Consistent error messages across scripts
