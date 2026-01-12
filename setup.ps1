# Скрипт для повного налаштування середовища LLM Proxy Server
# PowerShell версія

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Функція для виведення кольорового тексту
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Step {
    param([string]$Message)
    Write-ColorOutput "`n▶ $Message" "Cyan"
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "✓ $Message" "Green"
}

function Write-Error-Custom {
    param([string]$Message)
    Write-ColorOutput "✗ $Message" "Red"
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-ColorOutput "⚠ $Message" "Yellow"
}

Write-ColorOutput "╔════════════════════════════════════════════════╗" "Cyan"
Write-ColorOutput "║   LLM Proxy Server - Налаштування середовища   ║" "Cyan"
Write-ColorOutput "╚════════════════════════════════════════════════╝" "Cyan"

# 1. Перевірка Python
Write-Step "[1/10] Перевірка Python"
try {
    $pythonVersion = python --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Python не знайдено"
    }
    Write-Success "Python знайдено: $pythonVersion"
} catch {
    Write-Error-Custom "Python не знайдено. Встановіть Python 3.8 або новіше"
    exit 1
}

# 2. Перевірка pip
Write-Step "[2/10] Перевірка pip"
try {
    $pipVersion = python -m pip --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "pip не знайдено"
    }
    Write-Success "pip знайдено: $pipVersion"
} catch {
    Write-Error-Custom "pip не знайдено. Встановіть pip"
    exit 1
}

# 3. Створення віртуального середовища (опційно)
Write-Step "[3/10] Віртуальне середовище"
if (Test-Path "venv") {
    Write-Warning-Custom "Віртуальне середовище вже існує, пропускаємо створення"
} else {
    $response = Read-Host "Створити віртуальне середовище? (y/n)"
    if ($response -match "^[Yy]$") {
        python -m venv venv
        Write-Success "Віртуальне середовище створено"
        Write-Warning-Custom "Для активації використайте: .\venv\Scripts\Activate.ps1"
    } else {
        Write-Warning-Custom "Віртуальне середовище не створено"
    }
}

# 4. Оновлення pip
Write-Step "[4/10] Оновлення pip"
python -m pip install --upgrade pip *>$null
Write-Success "pip оновлено"

# 5. Встановлення основних залежностей
Write-Step "[5/10] Встановлення залежностей з requirements.txt"
if (Test-Path "requirements.txt") {
    python -m pip install -r requirements.txt
    Write-Success "Залежності встановлено"
} else {
    Write-Error-Custom "requirements.txt не знайдено"
    exit 1
}

# 6. Перевірка та встановлення CUDA
Write-Step "[6/10] Перевірка CUDA"
$cudaAvailable = $false
try {
    $nvccVersion = nvcc --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $cudaAvailable = $true
        Write-Success "CUDA вже встановлено: $($nvccVersion | Select-String 'release')"
    }
} catch {
    $cudaAvailable = $false
}

if (-not $cudaAvailable) {
    Write-Warning-Custom "CUDA не знайдено"
    
    # Перевірка наявності NVIDIA GPU
    $hasNvidiaGPU = $false
    try {
        $gpuInfo = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -like "*NVIDIA*" }
        if ($gpuInfo) {
            $hasNvidiaGPU = $true
            Write-Warning-Custom "Знайдено NVIDIA GPU: $($gpuInfo.Name)"
        }
    } catch {
        Write-Warning-Custom "Не вдалося визначити наявність NVIDIA GPU"
    }
    
    if ($hasNvidiaGPU) {
        Write-Host ""
        Write-Warning-Custom "Для максимальної продуктивності рекомендується встановити CUDA Toolkit"
        $installCuda = Read-Host "Встановити CUDA Toolkit 12.x? (y/n)"
        
        if ($installCuda -match "^[Yy]$") {
            Write-Warning-Custom "Завантаження CUDA Toolkit..."
            Write-Warning-Custom "Це може зайняти 10-20 хвилин залежно від швидкості інтернету"
            
            # URL для CUDA 12.6 (остання стабільна версія)
            $cudaInstallerUrl = "https://developer.download.nvidia.com/compute/cuda/12.6.0/network_installers/cuda_12.6.0_windows_network.exe"
            $cudaInstaller = "$env:TEMP\cuda_installer.exe"
            
            try {
                Write-Host "Завантаження з $cudaInstallerUrl..."
                # Використовуємо WebClient для показу прогресу
                $webClient = New-Object System.Net.WebClient
                $webClient.DownloadFile($cudaInstallerUrl, $cudaInstaller)
                
                Write-Success "Завантаження завершено"
                Write-Warning-Custom "Запуск інсталятора CUDA..."
                Write-Warning-Custom "Виберіть 'Custom' та встановіть принаймні: CUDA Toolkit, CUDA Runtime"
                
                # Запуск інсталятора
                Start-Process -FilePath $cudaInstaller -Wait
                
                Write-Success "Інсталяція CUDA завершена"
                Write-Warning-Custom "ПЕРЕЗАПУСТІТЬ PowerShell для застосування змін PATH"
                Write-Warning-Custom "Після перезапуску запустіть setup.ps1 знову"
                
                # Очищення
                Remove-Item $cudaInstaller -ErrorAction SilentlyContinue
                
                Read-Host "Натисніть Enter для виходу"
                exit 0
                
            } catch {
                Write-Error-Custom "Помилка завантаження/встановлення CUDA: $_"
                Write-Warning-Custom "Завантажте та встановіть CUDA вручну:"
                Write-Warning-Custom "https://developer.nvidia.com/cuda-downloads"
            }
        } else {
            Write-Warning-Custom "Продовжуємо без CUDA (використовуватиметься CPU)"
        }
    } else {
        Write-Warning-Custom "NVIDIA GPU не знайдено, використовуватиметься CPU версія"
    }
}

# 7. Встановлення llama-cpp-python[server]
Write-Step "[7/10] Встановлення llama-cpp-python[server]"
Write-Warning-Custom "Це може зайняти кілька хвилин..."

# Повторна перевірка CUDA після можливої інсталяції
$cudaAvailable = $false
try {
    $nvccVersion = nvcc --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $cudaAvailable = $true
    }
} catch {
    $cudaAvailable = $false
}

if ($cudaAvailable) {
    Write-Success "CUDA доступна, встановлюємо з підтримкою GPU"
    $env:CMAKE_ARGS = "-DLLAMA_CUBLAS=on"
    python -m pip install llama-cpp-python[server] --upgrade --force-reinstall --no-cache-dir
    Write-Success "llama-cpp-python[server] встановлено з підтримкою CUDA"
} else {
    Write-Warning-Custom "Встановлюємо CPU версію"
    python -m pip install "llama-cpp-python[server]"
    Write-Success "llama-cpp-python[server] встановлено (CPU)"
}

# 8. Перевірка PowerShell скриптів
Write-Step "[8/10] Перевірка PowerShell скриптів"
$scripts = @("start.ps1", "stop.ps1", "start_llama_server.ps1", "start_proxy_server.ps1")
foreach ($script in $scripts) {
    if (Test-Path $script) {
        Write-Success "$script - знайдено"
    } else {
        Write-Warning-Custom "$script - не знайдено"
    }
}

# 9. Перевірка моделей
Write-Step "[9/10] Перевірка моделей"
$modelsDir = ".\models"
if (-not (Test-Path $modelsDir)) {
    Write-Warning-Custom "Директорія models\ не знайдена, створюємо..."
    New-Item -ItemType Directory -Path $modelsDir -Force | Out-Null
}

$models = Get-ChildItem -Path $modelsDir -Filter "*.gguf" -File -ErrorAction SilentlyContinue
$modelCount = $models.Count

if ($modelCount -eq 0) {
    Write-Warning-Custom "Моделі .gguf не знайдено в $modelsDir\"
    Write-Warning-Custom "Завантажте моделі у форматі GGUF в директорію models\"
    Write-Warning-Custom "Наприклад з: https://huggingface.co/"
} else {
    Write-Success "Знайдено моделей: $modelCount"
    foreach ($model in $models) {
        Write-Host "  " -NoNewline
        Write-ColorOutput "• $($model.Name)" "Green"
    }
}

# 10. Завантаження моделі Mistral
Write-Step "[10/10] Завантаження моделі Mistral"
$modelFileName = "mistral-7b-instruct-v0.3.Q4_K_M.gguf"
$modelPath = Join-Path $modelsDir $modelFileName

if (Test-Path $modelPath) {
    Write-Success "Модель вже завантажена: $modelFileName"
} else {
    Write-Warning-Custom "Модель $modelFileName не знайдена"
    $downloadModel = Read-Host "Завантажити модель Mistral 7B Instruct? (~4.4 GB) (y/n)"
    
    if ($downloadModel -match "^[Yy]$") {
        # URL для моделі на HuggingFace
        $modelUrl = "https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.3-GGUF/resolve/main/mistral-7b-instruct-v0.3.Q4_K_M.gguf"
        
        Write-Warning-Custom "Завантаження моделі з HuggingFace..."
        Write-Warning-Custom "Це може зайняти 10-30 хвилин залежно від швидкості інтернету"
        
        try {
            # Використовуємо Invoke-WebRequest з прогресом
            $ProgressPreference = 'Continue'
            Write-Host "Завантаження $modelFileName..."
            Invoke-WebRequest -Uri $modelUrl -OutFile $modelPath -TimeoutSec 3600
            
            Write-Success "Модель успішно завантажена: $modelFileName"
            
            # Оновлення config.json з правильним шляхом
            if (Test-Path "config.json") {
                try {
                    $config = Get-Content "config.json" | ConvertFrom-Json
                    $config.model.path = $modelPath
                    $config | ConvertTo-Json -Depth 10 | Set-Content "config.json"
                    Write-Success "config.json оновлено з шляхом до моделі"
                } catch {
                    Write-Warning-Custom "Не вдалося автоматично оновити config.json"
                }
            }
        } catch {
            Write-Error-Custom "Помилка завантаження моделі: $_"
            Write-Warning-Custom "Завантажте модель вручну з:"
            Write-Warning-Custom $modelUrl
            
            # Видалення неповного файлу якщо завантаження не вдалося
            if (Test-Path $modelPath) {
                Remove-Item $modelPath -ErrorAction SilentlyContinue
            }
        }
    } else {
        Write-Warning-Custom "Завантаження моделі пропущено"
        Write-Warning-Custom "Ви можете завантажити модель пізніше з:"
        Write-Warning-Custom "https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.3-GGUF"
    }
}

# Перевірка конфігурації
Write-Host ""
Write-Step "Перевірка конфігурації"
if (Test-Path "config.json") {
    try {
        $config = Get-Content "config.json" | ConvertFrom-Json
        $modelPath = $config.model.path
        
        # Конвертація WSL шляху якщо потрібно
        if ($modelPath -match "^/") {
            # Це Unix шлях, перевіряємо як є
            if (Test-Path $modelPath) {
                Write-Success "Модель в config.json існує: $(Split-Path -Leaf $modelPath)"
            } else {
                Write-Warning-Custom "Модель в config.json не знайдена: $modelPath"
                Write-Warning-Custom "Оновіть шлях до моделі в config.json"
            }
        } else {
            # Це Windows шлях
            if (Test-Path $modelPath) {
                Write-Success "Модель в config.json існує: $(Split-Path -Leaf $modelPath)"
            } else {
                Write-Warning-Custom "Модель в config.json не знайдена: $modelPath"
                Write-Warning-Custom "Оновіть шлях до моделі в config.json"
            }
        }
    } catch {
        Write-Warning-Custom "Помилка читання config.json"
    }
} else {
    Write-Error-Custom "config.json не знайдено"
}

# Підсумок
Write-Host ""
Write-ColorOutput "╔════════════════════════════════════════════════╗" "Cyan"
Write-ColorOutput "║            Налаштування завершено!            ║" "Cyan"
Write-ColorOutput "╚════════════════════════════════════════════════╝" "Cyan"
Write-Host ""
Write-Success "✓ Всі залежності встановлено"
Write-Success "✓ Середовище готове до використання"
Write-Host ""
Write-Warning-Custom "Наступні кроки:"
Write-Host "  1. Переконайтесь що модель є в директорії models\"
Write-Host "  2. Перевірте config.json (шлях до моделі)"
Write-ColorOutput "  3. Запустіть сервер: " "White" -NoNewline
Write-ColorOutput ".\start.ps1" "Green"
Write-Host ""
Write-ColorOutput "Документація: README.md" "Cyan"
Write-Host ""
