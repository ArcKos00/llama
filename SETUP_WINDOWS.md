# Windows Native Setup

## ⚠️ Important

Windows native setup requires Visual Studio Build Tools (6+ GB) and takes 30-60 minutes.

**We recommend using WSL instead** - it's faster, easier, and has better performance.

## Prerequisites

1. **Python 3.11** - Install from https://www.python.org/downloads/
2. **Visual Studio Build Tools** with "Desktop development with C++"
   - Download: https://visualstudio.microsoft.com/downloads/
   - Select: "Desktop development with C++" workload
   - Size: ~6 GB
   - Time: 30-60 minutes

## Installation Steps

1. **Install Visual Studio Build Tools**
   ```powershell
   # Download and install from:
   # https://visualstudio.microsoft.com/downloads/
   # Select: "Desktop development with C++"
   ```

2. **Restart PowerShell** (to load new PATH)

3. **Run setup script**
   ```powershell
   .\setup.ps1
   ```

4. **Start server**
   ```powershell
   .\start.ps1
   ```

## Troubleshooting

### Compilation errors
- Ensure Visual Studio Build Tools is installed with C++ support
- Restart PowerShell after installing Build Tools
- Check that `cl.exe` is in PATH: `where cl`

### Network issues
- Run as Administrator: `.\fix_firewall.ps1`
- Temporarily disable antivirus
- Check Windows Firewall settings

## Alternative: Use WSL (Recommended)

WSL is much easier and faster:

```powershell
# Install WSL (if not installed)
wsl --install

# Open WSL terminal
wsl

# Navigate to project
cd /home/kostanich/llama

# Run setup
./setup.sh

# Start server
./start.sh
```

See [SETUP_WSL.md](SETUP_WSL.md) for details.
