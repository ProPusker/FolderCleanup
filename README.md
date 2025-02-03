```markdown
# Automated File Cleanup Script



A robust PowerShell script for automated file cleanup with configurable retention policies, logging, and email notifications.

## Features

- 🗑️ **Automated File Deletion** based on age
- ⚙️ **XML Configuration** for easy setup
- 📅 **Custom Retention Rules** by folder path
- 📨 **Email Notifications** with logs
- 🔒 **Secure Credential Handling**
- 📊 **Detailed Statistics Reporting**
- 🔄 **Log Rotation** with retention control

## Table of Contents
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Logs](#logs)
- [Troubleshooting](#troubleshooting)
- [Security](#security)
- [License](#license)

---

## Installation

1. **Clone Repository**:
   ```powershell
   git clone https://github.com/yourrepo/file-cleanup.git
   cd file-cleanup
   ```

2. **Required Modules**:
   ```powershell
   Install-Module -Name ActiveDirectory, AWSPowerShell
   ```

3. **Create Configuration File**:
   - Copy `config.example.xml` to `FileCleanup.xml`
   - Edit with your settings (see [Configuration](#configuration))

---


### Configuration Details
1. **RootPath**: Base directory to scan
2. **Smtp**: Email alert credentials
   - Encode password:
     ```powershell
     [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("your_password"))
     ```
3. **CleanupRules**: Path patterns and retention days
   - Uses file glob patterns (`*` wildcards supported)

---

## Usage

### Basic Cleanup
```powershell
.\FileCleanup.ps1
```

### Verbose Mode
```powershell
.\FileCleanup.ps1 -Verbose
```

### Sample Output
```
[INFO] Removed: D:\CorporateData\logs\app.log (Age: 181d, Size: 42.3 MB)
[STATS] Deleted 15 files (Total: 2.1 GB)
```

---

## Logs

### Log Location
`\logs\FileCleanup_<timestamp>.log`

### Log Format
```
MM/DD/YYYY HH:mm:ss.fff|LINE#|LEVEL|MESSAGE
08/15/2023 14:23:45.123|42|INFO|Removed old file: D:\data\temp.txt
```

### Log Rotation
- Max size: 64KB
- Retains last 5 logs
- Archived as `FileCleanup_YYYYMMDD-HHmmss.log`

---

## Troubleshooting

### Common Issues

**1. File Access Denied**
- Run PowerShell as Administrator
- Verify script has modify permissions

**2. SMTP Errors**
- Check Office 365 credentials
- Verify TLS 1.2 enabled:
  ```powershell
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  ```

**3. Configuration Errors**
- Validate XML structure
- Check Base64 password encoding

**4. Path Not Found**
- Verify RootPath exists
- Check retention rule patterns

---

## Security

### Credential Safety
- Passwords stored as Base64
- XML file should have restricted permissions:
  ```powershell
  icacls FileCleanup.xml /inheritance:r /grant:r "Administrators:(F)"
  ```

### Audit Trail
- All deletions logged with timestamps
- Email notifications include attachment

---
