# Fix Windows Firewall for Python/pip
# Run as Administrator

Write-Host "=== Windows Firewall Fix for Python ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[ERROR] This script must be run as Administrator" -ForegroundColor Red
    Write-Host ""
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    Write-Host "Then run this script again" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "[OK] Running as Administrator" -ForegroundColor Green
Write-Host ""

# Find Python executable
Write-Host "Finding Python executable..." -ForegroundColor Yellow
try {
    $pythonPath = (Get-Command python -ErrorAction Stop).Source
    Write-Host "[OK] Found Python: $pythonPath" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Python not found in PATH" -ForegroundColor Red
    exit 1
}

# Add firewall rules
Write-Host ""
Write-Host "Adding Windows Firewall rules..." -ForegroundColor Yellow
Write-Host ""

# Remove old rules if exist
$ruleName = "Python - pip (Allow Outbound)"
$existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($existingRule) {
    Write-Host "Removing old firewall rule..." -ForegroundColor Gray
    Remove-NetFirewallRule -DisplayName $ruleName
}

# Add new rule for outbound connections
try {
    New-NetFirewallRule `
        -DisplayName $ruleName `
        -Description "Allow Python pip to download packages from PyPI" `
        -Direction Outbound `
        -Program $pythonPath `
        -Action Allow `
        -Protocol TCP `
        -RemotePort 443,80 `
        -Profile Any `
        -Enabled True | Out-Null
    
    Write-Host "[OK] Firewall rule added successfully" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to add firewall rule: $_" -ForegroundColor Red
    exit 1
}

# Test connection
Write-Host ""
Write-Host "Testing connection to PyPI..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

try {
    $pypiTest = Test-NetConnection pypi.org -Port 443 -WarningAction SilentlyContinue
    if ($pypiTest.TcpTestSucceeded) {
        Write-Host "[OK] Can now connect to pypi.org:443" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Still cannot connect to pypi.org:443" -ForegroundColor Yellow
        Write-Host "          You may need to check your antivirus settings" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[WARNING] Could not test connection" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "You can now run: .\setup.ps1" -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit"
