# Error Handling and Script Collaboration

This document explains how the installation scripts handle errors and communicate failure states.

## Script Collaboration

The automatic installation uses two main scripts that work together:

1. **`installWSLAutomatic.ps1`** - Orchestrator script
2. **`installUbuntuLTS.ps1`** - Ubuntu installation worker script

### Communication Flow

```
installWSLAutomatic.ps1
    │
    ├─ Stage 1: Enable WSL Features (if needed)
    │
    ├─ Stage 2: Install WSL 2 (if needed)
    │
    └─ Stage 3: Call installUbuntuLTS.ps1
         │
         ├─ Download Ubuntu appx
         ├─ Extract and import
         ├─ Configure system
         └─ Install software
              │
              └─ Returns exit code
                   ├─ 0 = Success
                   └─ 1 = Failure

installWSLAutomatic.ps1 checks exit code
    │
    ├─ Exit 0: Continue, mark as completed
    └─ Exit 1: Stop, preserve state, show error
```

## Exit Codes

Both scripts follow standard exit code conventions:

- **Exit 0**: Successful completion
- **Exit 1**: Error occurred

### installUbuntuLTS.ps1 Exit Points

| Condition | Exit Code | Preservation |
|-----------|-----------|--------------|
| Checksum mismatch (user declines re-download) | 1 | Appx file kept |
| Download failure | 1 | No files |
| .tar.gz not found in package | 1 | Appx and extracted folder kept |
| WSL import failure | 1 | Appx and extracted folder kept |
| Distribution verification failure | 1 | Appx and extracted folder kept |
| System update failure | 1 | Distribution imported, appx cleaned |
| User creation failure | 1 | Distribution imported, appx cleaned |
| Sudo configuration failure | 1 | Distribution imported, appx cleaned |
| Base packages installation failure | 1 | Distribution imported, appx cleaned |
| Software installation failure | 1 | Distribution imported, appx cleaned |
| Successful completion | 0 | All files cleaned, checkpoint cleared |

## Error Handling Examples

### Example 1: Download Failure

```powershell
# installUbuntuLTS.ps1
Write-Host "Downloading Ubuntu 20.04 LTS..."
curl.exe -L -o $appxPath https://aka.ms/wslubuntu2004

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to download Ubuntu package"
    Exit 1  # ← Returns to caller
}
```

```powershell
# installWSLAutomatic.ps1
& $installScript -wslName $Config.wslName ...

if ($LASTEXITCODE -ne 0) {  # ← Detects failure
    Write-Host "ERROR: Ubuntu installation failed!"
    Exit 1  # ← Stops entire installation
}
```

### Example 2: User Creation Failure

```powershell
# installUbuntuLTS.ps1
Write-Host "Creating user '$username'..."
wsl -d $wslName -u root bash -ic "./scripts/config/system/createUser.sh $username ubuntu"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create user. Exit code: $LASTEXITCODE"
    Write-Host "Make sure the createUser.sh script exists and is executable."
    Exit 1  # ← Returns with error code
}
```

### Example 3: Successful Completion

```powershell
# installUbuntuLTS.ps1
Write-Host "Ubuntu LTS installation completed successfully!"
Exit 0  # ← Explicit success
```

```powershell
# installWSLAutomatic.ps1
& $installScript -wslName $Config.wslName ...

if ($LASTEXITCODE -ne 0) {  # ← Check passes
    # Not executed
}

Set-InstallStatus -Stage "Completed"  # ← Marks as done
Write-Host "Ubuntu LTS installed successfully!"
```

## State Preservation on Failure

When `installUbuntuLTS.ps1` fails, the state is preserved for debugging:

### Before Import Failure
- **Preserved**: Downloaded appx (keeps original name `ubuntuLTS.appx`), extracted files
- **Reason**: Can debug extraction issues, retry import, resume from checkpoint
- **Location**: `staging/` folder

**Note**: The appx file is NOT renamed during extraction to allow checkpoint resume functionality.
- **Reason**: Can debug extraction issues, retry import
- **Location**: `staging/` folder

### After Import Success
- **Preserved**: WSL distribution, checkpoint file
- **Deleted**: Downloaded archives (no longer needed)
- **Reason**: Configuration can be retried without re-download

### Configuration Failure
- **Preserved**: WSL distribution, checkpoint file, installation state
- **Reason**: Can fix scripts and retry without re-import

## Retry Scenarios

### Retry After Download Failure
```powershell
# First attempt
.\installWSLAutomatic.ps1
# Download fails → Exit 1

# Fix network issue, retry
.\installWSLAutomatic.ps1
# Starts fresh, downloads again
```

### Retry After Import Failure  
```powershell
# First attempt
.\installWSLAutomatic.ps1
# Import fails → Archives preserved → Exit 1

# Fix issue (free space, permissions), retry
.\installWSLAutomatic.ps1
# Resume from checkpoint? Y
# Verifies checksum ✓
# Skips download
# Retries import → Success
```

### Retry After Configuration Failure
```powershell
# First attempt
.\installWSLAutomatic.ps1
# User creation fails → Distribution imported → Exit 1

# Fix createUser.sh script, retry
.\installWSLAutomatic.ps1
# Distribution already exists!
# Need to unregister first:
wsl --unregister devbox

# Then retry
.\installWSLAutomatic.ps1
# Resume from checkpoint? Y
# Uses cached download
# Re-imports and configures
```

## Best Practices

### For Users

1. **Check error messages**: They indicate exactly what failed
2. **Review exit codes**: Non-zero means something went wrong
3. **Preserve staging folder**: Contains valuable debugging info
4. **Retry after fixes**: Most errors are recoverable

### For Developers

1. **Always check `$LASTEXITCODE`** after external commands
2. **Exit with appropriate codes**: 0 for success, 1 for errors
3. **Preserve state on failure**: Don't delete files that might help debug
4. **Clear messages**: Tell users what failed and how to fix it
5. **Test error paths**: Simulate failures to ensure proper handling

## Error Message Anatomy

Good error messages in these scripts include:

1. **What failed**: "Failed to create user"
2. **Technical details**: "Exit code: 1"
3. **User guidance**: "Make sure the createUser.sh script exists"
4. **State information**: "Archives have been preserved in .\staging"

Example:
```
ERROR: Failed to create user. Exit code: 1
Make sure the createUser.sh script exists and is executable.
Distribution has been imported but configuration failed.
```

## Testing Error Handling

To test the error handling, you can simulate failures:

### Simulate Download Failure
```powershell
# Temporarily break network or use invalid URL
$badUrl = "https://invalid.url/package.appx"
# Replace in script temporarily, test error path
```

### Simulate Import Failure
```powershell
# Use invalid path or read-only filesystem
$wslInstallationPath = "C:\Windows\System32\InvalidPath"
# Should fail with proper error and preserve files
```

### Simulate Configuration Failure
```powershell
# Rename or delete the createUser.sh script
mv scripts/config/system/createUser.sh scripts/config/system/createUser.sh.bak
# Should fail with clear error message
```

---

This error handling ensures that failures are detected early, state is preserved for debugging, and users get clear feedback about what went wrong and how to fix it.
