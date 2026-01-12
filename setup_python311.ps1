# Скрипт для встановлення та налаштування Python 3.11
# PowerShell версія

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Конфігурація
$REQUIRED_PYTHON_VERSION = "3.11"
$PYTHON_DOWNLOAD_URL = "https://www.python.org/ftp/python/3.11.8/python-3.11.8-amd64.exe"
$VENV_NAME = ".venv"

# Функції для виведення
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Step {
    param([string]$Message)
    Write-ColorOutput "`n> $Message" "Cyan"
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "[OK] $Message" "Green"
}

function Write-Error-Custom {
    param([string]$Message)
    Write-ColorOutput "[ERROR] $Message" "Red"
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-ColorOutput "[WARNING] $Message" "Yellow"
}

function Get-PythonVersion {
    param([string]$PythonCommand)
    
    try {
        $version = & $PythonCommand --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $version -match "Python (\d+\.\d+)") {
            return $matches[1]
        }
    } catch {
        return $null
    }
    return $null
}

Write-ColorOutput "╔════════════════════════════════════════════════╗" "Cyan"
Write-ColorOutput "║      Python 3.11 - Налаштування оточення       ║" "Cyan"
Write-ColorOutput "╚════════════════════════════════════════════════╝" "Cyan"

# 1. Перевірка наявності Python 3.11
Write-Step "[1/5] Перевірка Python 3.11"

$python311Found = $false
$pythonCommand = $null

# Спроба знайти python3.11
$pythonCommands = @("python3.11", "python3", "python", "py -3.11")

foreach ($cmd in $pythonCommands) {
    $version = Get-PythonVersion -PythonCommand $cmd
    if ($version -and $version -eq $REQUIRED_PYTHON_VERSION) {
        $python311Found = $true
        $pythonCommand = $cmd
        Write-Success "Python 3.11 знайдено: $cmd"
        break
    }
}

if (-not $python311Found) {
    Write-Warning-Custom "Python 3.11 не знайдено"
    $installPython = Read-Host "Завантажити та встановити Python 3.11.8? (y/n)"
    
    if ($installPython -match "^[Yy]$") {
        Write-Warning-Custom "Завантаження Python 3.11.8..."
        $installerPath = "$env:TEMP\python-3.11.8-amd64.exe"
        
        try {
            Write-Host "Завантаження з $PYTHON_DOWNLOAD_URL..."
            $ProgressPreference = 'Continue'
            Invoke-WebRequest -Uri $PYTHON_DOWNLOAD_URL -OutFile $installerPath -TimeoutSec 600
            
            Write-Success "Завантаження завершено"
            Write-Warning-Custom "Запуск інсталятора Python..."
            Write-Warning-Custom "ВАЖЛИВО: Під час встановлення:"
            Write-Warning-Custom "  1. Оберіть 'Add Python 3.11 to PATH'"
            Write-Warning-Custom "  2. Оберіть 'Install Now' або 'Customize installation'"
            Write-Warning-Custom "  3. Переконайтесь що встановлено pip"
            Write-Host ""
            Read-Host "Натисніть Enter для запуску інсталятора"
            
            # Запуск інсталятора
            Start-Process -FilePath $installerPath -Wait
            
            Write-Success "Інсталяція Python завершена"
            Write-Warning-Custom "ПЕРЕЗАПУСТІТЬ PowerShell для застосування змін PATH"
            Write-Warning-Custom "Після перезапуску запустіть цей скрипт знову"
            
            # Очищення
            Remove-Item $installerPath -ErrorAction SilentlyContinue
            
            Read-Host "Натисніть Enter для виходу"
            exit 0
            
        } catch {
            Write-Error-Custom "Помилка завантаження/встановлення Python: $_"
            Write-Warning-Custom "Завантажте та встановіть Python 3.11 вручну:"
            Write-Warning-Custom "https://www.python.org/downloads/"
            exit 1
        }
    } else {
        Write-Error-Custom "Python 3.11 обов'язковий для роботи проекту"
        exit 1
    }
}

# Повторна перевірка після можливого встановлення
if (-not $pythonCommand) {
    foreach ($cmd in $pythonCommands) {
        $version = Get-PythonVersion -PythonCommand $cmd
        if ($version -and $version -eq $REQUIRED_PYTHON_VERSION) {
            $pythonCommand = $cmd
            break
        }
    }
}

if (-not $pythonCommand) {
    Write-Error-Custom "Python 3.11 не знайдено. Перезапустіть PowerShell після встановлення Python"
    exit 1
}

# 2. Перевірка pip
Write-Step "[2/5] Перевірка pip"
try {
    $pipVersion = & $pythonCommand -m pip --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "pip не знайдено"
    }
    Write-Success "pip знайдено: $pipVersion"
} catch {
    Write-Error-Custom "pip не знайдено"
    Write-Warning-Custom "Встановлення pip..."
    try {
        & $pythonCommand -m ensurepip --default-pip
        Write-Success "pip встановлено"
    } catch {
        Write-Error-Custom "Не вдалося встановити pip"
        exit 1
    }
}

# 3. Створення віртуального середовища
Write-Step "[3/5] Створення віртуального середовища"
if (Test-Path $VENV_NAME) {
    Write-Warning-Custom "Віртуальне середовище вже існує: $VENV_NAME"
    $recreate = Read-Host "Перестворити віртуальне середовище? (y/n)"
    
    if ($recreate -match "^[Yy]$") {
        Write-Warning-Custom "Видалення старого віртуального середовища..."
        Remove-Item -Recurse -Force $VENV_NAME
        
        Write-Host "Створення нового віртуального середовища..."
        & $pythonCommand -m venv $VENV_NAME
        Write-Success "Віртуальне середовище створено: $VENV_NAME"
    } else {
        Write-Warning-Custom "Використовується існуюче віртуальне середовище"
    }
} else {
    Write-Host "Створення віртуального середовища..."
    & $pythonCommand -m venv $VENV_NAME
    Write-Success "Віртуальне середовище створено: $VENV_NAME"
}

# Шлях до Python у віртуальному середовищі
$venvPython = Join-Path $VENV_NAME "Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    Write-Error-Custom "Не вдалося створити віртуальне середовище"
    exit 1
}

# 4. Оновлення pip у віртуальному середовищі
Write-Step "[4/5] Оновлення pip у віртуальному середовищі"
& $venvPython -m pip install --upgrade pip setuptools wheel *>$null
Write-Success "pip оновлено у віртуальному середовищі"

# 5. Встановлення залежностей
Write-Step "[5/5] Встановлення залежностей проекту"
if (Test-Path "requirements.txt") {
    Write-Warning-Custom "Встановлення залежностей з requirements.txt..."
    & $venvPython -m pip install -r requirements.txt
    Write-Success "Залежності встановлено"
} else {
    Write-Warning-Custom "requirements.txt не знайдено, пропускаємо встановлення залежностей"
}

# Підсумок
Write-Host ""
Write-ColorOutput "╔════════════════════════════════════════════════╗" "Green"
Write-ColorOutput "║     Python 3.11 середовище налаштовано!       ║" "Green"
Write-ColorOutput "╚════════════════════════════════════════════════╝" "Green"
Write-Host ""
Write-Success "✓ Python 3.11 встановлено та налаштовано"
Write-Success "✓ Віртуальне середовище: $VENV_NAME"
Write-Success "✓ Всі залежності встановлено"
Write-Host ""
Write-ColorOutput "Для активації віртуального середовища:" "Cyan"
Write-ColorOutput "  $VENV_NAME\Scripts\Activate.ps1" "Yellow"
Write-Host ""
Write-ColorOutput "Для деактивації:" "Cyan"
Write-ColorOutput "  deactivate" "Yellow"
Write-Host ""
Write-ColorOutput "Для перевірки версії Python:" "Cyan"
Write-ColorOutput "  python --version" "Yellow"
Write-Host ""
