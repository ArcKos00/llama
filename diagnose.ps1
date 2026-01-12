# Network Diagnostics for Python/pip
# PowerShell version

Write-Host "=== Python/pip Network Diagnostics ===" -ForegroundColor Cyan
Write-Host ""

# 1. Check Python
Write-Host "[1/6] Checking Python..." -ForegroundColor Yellow
try {
    $pythonPath = (Get-Command python -ErrorAction Stop).Source
    $pythonVersion = python --version 2>&1
    Write-Host "[OK] Python: $pythonVersion" -ForegroundColor Green
    Write-Host "      Path: $pythonPath" -ForegroundColor Gray
} catch {
    Write-Host "[ERROR] Python not found" -ForegroundColor Red
    exit 1
}

# 2. Check pip
Write-Host ""
Write-Host "[2/6] Checking pip..." -ForegroundColor Yellow
try {
    $pipVersion = python -m pip --version 2>&1
    Write-Host "[OK] pip: $pipVersion" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] pip not found" -ForegroundColor Red
    exit 1
}

# 3. Check Internet connectivity
Write-Host ""
Write-Host "[3/6] Checking Internet connectivity..." -ForegroundColor Yellow
try {
    $googleTest = Test-Connection google.com -Count 1 -Quiet -ErrorAction Stop
    if ($googleTest) {
        Write-Host "[OK] Internet connection works (google.com)" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Cannot reach google.com" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[WARNING] Cannot test Internet connection" -ForegroundColor Yellow
}

# 4. Check PyPI connectivity
Write-Host ""
Write-Host "[4/6] Checking PyPI connectivity..." -ForegroundColor Yellow
try {
    $pypiTest = Test-NetConnection pypi.org -Port 443 -WarningAction SilentlyContinue -ErrorAction Stop
    if ($pypiTest.TcpTestSucceeded) {
        Write-Host "[OK] Can connect to pypi.org:443" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Cannot connect to pypi.org:443" -ForegroundColor Red
        Write-Host "        Firewall or network issue detected!" -ForegroundColor Red
    }
} catch {
    Write-Host "[ERROR] Cannot test PyPI connection" -ForegroundColor Red
}

# 5. Check proxy settings
Write-Host ""
Write-Host "[5/6] Checking proxy settings..." -ForegroundColor Yellow
$httpProxy = [System.Environment]::GetEnvironmentVariable("HTTP_PROXY")
$httpsProxy = [System.Environment]::GetEnvironmentVariable("HTTPS_PROXY")

if ($httpProxy -or $httpsProxy) {
    Write-Host "[INFO] Proxy detected:" -ForegroundColor Cyan
    if ($httpProxy) { Write-Host "      HTTP_PROXY: $httpProxy" -ForegroundColor Gray }
    if ($httpsProxy) { Write-Host "      HTTPS_PROXY: $httpsProxy" -ForegroundColor Gray }
} else {
    Write-Host "[INFO] No proxy configured" -ForegroundColor Gray
}

# 6. Try pip install test
Write-Host ""
Write-Host "[6/6] Testing pip install..." -ForegroundColor Yellow
Write-Host "      Trying to fetch package info from PyPI..." -ForegroundColor Gray

try {
    $env:PIP_TIMEOUT = "10"
    $testOutput = python -m pip search httpx 2>&1 | Out-String
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] pip can connect to PyPI" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] pip search disabled, trying download..." -ForegroundColor Yellow
        
        # Try actual download
        $testDownload = python -m pip download httpx --no-deps --dest $env:TEMP 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] pip can download packages" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] pip cannot download packages" -ForegroundColor Red
            Write-Host $testDownload -ForegroundColor Red
        }
    }
} catch {
    Write-Host "[ERROR] pip test failed: $_" -ForegroundColor Red
}

# Summary
Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "If PyPI connection failed, try these solutions:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Check Windows Firewall:" -ForegroundColor White
Write-Host "   - Open Windows Security > Firewall & network protection" -ForegroundColor Gray
Write-Host "   - Allow Python through firewall" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Check Antivirus:" -ForegroundColor White
Write-Host "   - Temporarily disable antivirus and try again" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Use alternative PyPI mirror:" -ForegroundColor White
Write-Host "   python -m pip install -i https://mirrors.aliyun.com/pypi/simple/ httpx" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Install offline:" -ForegroundColor White
Write-Host "   - Download .whl files on another computer" -ForegroundColor Gray
Write-Host "   - Copy to this machine and install: pip install package.whl" -ForegroundColor Gray
Write-Host ""
Write-Host "5. Check WSL network:" -ForegroundColor White
Write-Host "   - Your files are on WSL but you're using Windows Python" -ForegroundColor Gray
Write-Host "   - Try running from WSL directly: ./setup.sh" -ForegroundColor Gray
Write-Host ""
