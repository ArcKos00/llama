# WSL/Linux Setup (Recommended)

## ✅ Advantages

- ✨ **No compiler needed** - uses prebuilt packages
- 🚀 **Fast setup** - 5 minutes total
- ⚡ **Better performance** - native Linux performance
- 🎯 **Easier maintenance** - standard Linux package management

## Prerequisites

### Windows Users

1. **Install WSL** (if not already installed)
   ```powershell
   wsl --install
   ```

2. **Restart computer** after WSL installation

### Verify WSL is running
```powershell
wsl --list --verbose
```

## Installation Steps

### 1. Open WSL Terminal

**From PowerShell:**
```powershell
wsl
```

**From Windows Terminal:**
- Click `+` (new tab)
- Select your Linux distribution

### 2. Navigate to Project

```bash
cd /home/kostanich/llama
```

### 3. Run Setup Script

```bash
./setup.sh
```

The script will automatically:
- ✅ Install Python 3.11
- ✅ Create virtual environment
- ✅ Install all dependencies
- ✅ Install llama-cpp-python (prebuilt, no compilation)
- ✅ Configure environment

### 4. Start Server

```bash
./start.sh
```

## Usage

### Starting the server
```bash
wsl
cd /home/kostanich/llama
./start.sh
```

Or from PowerShell:
```powershell
wsl bash -c "cd /home/kostanich/llama && ./start.sh"
```

### Stopping the server
```bash
./stop.sh
```

Or from PowerShell:
```powershell
wsl bash -c "cd /home/kostanich/llama && ./stop.sh"
```

### Checking logs
```bash
tail -f logs/llama_server.log
tail -f logs/proxy_server.log
```

## Accessing from Windows

The server running in WSL is accessible from Windows:

- **Proxy Server:** http://localhost:8000
- **Llama Server:** http://localhost:8080

## File Access

WSL files are accessible from Windows at:
```
\\wsl.localhost\Ubuntu-24.04\home\kostanich\llama\
```

You can edit files using Windows editors (VS Code, Notepad++, etc.)

## Troubleshooting

### WSL not found
```powershell
wsl --install
# Then restart computer
```

### Network issues in WSL
```bash
# Check DNS
cat /etc/resolv.conf

# Restart WSL (from PowerShell)
wsl --shutdown
wsl
```

### Python not found
The setup script will automatically install Python 3.11 if needed.

## CUDA Support (Optional)

If you have NVIDIA GPU and want GPU acceleration:

1. Install NVIDIA drivers in Windows
2. WSL will automatically use them (no additional setup needed in WSL2)
3. The setup script will detect CUDA and build with GPU support

## Performance Tips

- ✅ Use WSL2 (not WSL1) - check with `wsl --list --verbose`
- ✅ Store files in WSL filesystem for better I/O performance
- ✅ Close unnecessary Windows applications
- ✅ Increase WSL memory limit in `.wslconfig` if needed

## Comparison: WSL vs Windows Native

| Feature | WSL | Windows Native |
|---------|-----|----------------|
| Setup time | 5 minutes | 30-60 minutes |
| Compiler required | ❌ No | ✅ Yes (6+ GB) |
| Performance | ⚡ Faster | 🐌 Slower |
| Maintenance | ✅ Easy | ⚠️ Complex |
| **Recommendation** | **✅ Use this** | ⚠️ Only if necessary |
