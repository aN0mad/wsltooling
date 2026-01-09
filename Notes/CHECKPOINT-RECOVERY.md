# Checkpoint and Recovery System

The Ubuntu installation script includes a robust checkpoint and recovery system to handle interruptions and failures gracefully.

## How It Works

### Automatic Checkpoints

The installation process creates checkpoints at critical stages:

1. **After Appx Download** (`AppxDownloaded`)
   - Saves after the 900+ MB Ubuntu appx file is downloaded
   - Records the SHA256 hash of the downloaded file
   - Prevents re-downloading if the installation fails later

### What's Saved

The checkpoint file (`staging/ubuntu-install-checkpoint.json`) contains:
- **Stage**: Current installation stage
- **Timestamp**: When the checkpoint was created
- **WslName**: The distribution name being installed
- **AppxHash**: SHA256 checksum of the downloaded appx file
- **TarPath**: Path to the extracted tar.gz file (if applicable)

## Using Checkpoints

### Automatic Resume

If you run the installation script again after a failure:

```powershell
.\installUbuntuLTS.ps1 devbox D:\WSL2\devbox ryan true
```

The script will:
1. Detect the existing checkpoint
2. Display checkpoint information (stage, timestamp)
3. Ask if you want to resume or start fresh
4. Verify file integrity using checksums if resuming

### Example Resume Prompt

```
Found existing installation checkpoint for 'devbox'
Stage: AppxDownloaded
Timestamp: 1/9/2026 10:30:15 AM
Resume from checkpoint? (Y/N):
```

### Checksum Verification

When resuming from the `AppxDownloaded` checkpoint:

```
Resuming from downloaded Appx...
Verifying downloaded file integrity...
File integrity verified! Checksum matches.
```

If the checksum doesn't match:
```
Checksum mismatch! File may be corrupted or tampered with.
Expected: ABC123...
Got:      DEF456...
Re-download the file? (Y/N):
```

## Benefits

### 1. **Saves Time**
- No need to re-download 900+ MB if something fails
- Resume from where you left off

### 2. **Saves Bandwidth**
- Download once, retry installation multiple times
- Useful for metered or slow connections

### 3. **Security**
- SHA256 checksums verify file integrity
- Detects corrupted or tampered files
- Prevents installation of compromised packages

### 4. **Reliability**
- Archives preserved until successful import
- Can debug issues without losing downloaded files
- Easy recovery from temporary failures

## File Preservation

The script preserves downloaded and extracted files until the WSL distribution is successfully imported:

- `staging/ubuntuLTS.appx` → Kept with original name for resume capability
- `staging/<wslName>/` → Extracted files kept until import succeeds

**Note**: The appx file is NOT renamed during extraction. This allows the checkpoint/resume feature to find the file by its original name when resuming after a failure.

Files are **only deleted** after:
1. WSL distribution is successfully imported
2. Distribution is verified with `wsl --list`

If import fails, files remain for debugging.

## Manual Checkpoint Management

### View Current Checkpoint

```powershell
Get-Content .\staging\ubuntu-install-checkpoint.json | ConvertFrom-Json
```

### Clear Checkpoint (Start Fresh)

```powershell
Remove-Item .\staging\ubuntu-install-checkpoint.json
```

### Verify Downloaded File

```powershell
Get-FileHash -Path .\staging\ubuntuLTS.appx -Algorithm SHA256
```

## Troubleshooting

### Checkpoint exists but file missing

The script detects this and automatically re-downloads:
```
Checkpoint exists but file not found. Re-downloading...
```

### Want to force fresh installation

Choose 'N' when asked to resume:
```
Resume from checkpoint? (Y/N): N
Starting fresh installation...
```

Or manually delete the checkpoint file first.

### Checksum keeps failing

1. Check available disk space
2. Verify network connectivity
3. Try downloading from a different network
4. Check antivirus isn't corrupting the file

### Clear all installation artifacts

```powershell
Remove-Item -Recurse -Force .\staging
```

This removes:
- Checkpoint files
- Downloaded appx
- Extracted archives
- All temporary files

## Integration with Automatic Installation

The checkpoint system is fully integrated with `installWSLAutomatic.ps1`:

- Checkpoints work across reboots
- Resume capability independent of the reboot continuation system
- Both systems work together seamlessly

## Example Scenarios

### Scenario 1: Network Interruption During Extract

1. Download completes → Checkpoint created
2. Extraction starts
3. **Network disconnects** (doesn't matter, file already downloaded)
4. Extraction or import fails
5. Re-run script → Resumes from downloaded file
6. Completes successfully

### Scenario 2: Import Failure

1. Download completes → Checkpoint created
2. Extraction succeeds
3. WSL import fails (permissions, disk space, etc.)
4. **Files preserved** in staging folder
5. Fix the issue (free up space, check permissions)
6. Re-run script → Resumes from downloaded file
7. Completes successfully

### Scenario 3: Corruption Detection

1. Download completes → Checkpoint created with hash
2. File gets corrupted (disk error, antivirus, etc.)
3. Re-run script
4. **Checksum mismatch detected**
5. Prompted to re-download
6. Fresh download with new checkpoint
7. Completes successfully

---

This checkpoint system makes the installation process much more resilient to failures, saving time and bandwidth while ensuring file integrity.
