# Скрипт для запуску LLM Proxy Server
# PowerShell версія

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Функції для кольорового виводу
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Конфігурація з config.json
$config = Get-Content "config.json" | ConvertFrom-Json
$MODEL_PATH = $config.model.path
$LLAMA_HOST = "127.0.0.1"
$LLAMA_PORT = "8000"
$PROXY_HOST = "0.0.0.0"
$PROXY_PORT = "8080"
$N_GPU_LAYERS = $config.model.gpu_layer
$N_CTX = $config.model.context_size

Write-ColorOutput "╔════════════════════════════════════════════════╗" "Green"
Write-ColorOutput "║           LLM Proxy Server - Запуск            ║" "Green"
Write-ColorOutput "╚════════════════════════════════════════════════╝" "Green"
Write-Host ""

# Глобальні змінні для процесів
$script:llamaProcess = $null
$script:proxyProcess = $null

# Функція очищення
function Stop-Servers {
    Write-Host ""
    Write-ColorOutput "⚠ Зупинка серверів..." "Yellow"
    
    if ($script:proxyProcess -and !$script:proxyProcess.HasExited) {
        Write-Host "Зупинка proxy server (PID: $($script:proxyProcess.Id))"
        Stop-Process -Id $script:proxyProcess.Id -Force -ErrorAction SilentlyContinue
    }
    
    if ($script:llamaProcess -and !$script:llamaProcess.HasExited) {
        Write-Host "Зупинка llama server (PID: $($script:llamaProcess.Id))"
        Stop-Process -Id $script:llamaProcess.Id -Force -ErrorAction SilentlyContinue
    }
    
    Write-ColorOutput "✓ Сервери зупинено" "Green"
}

# Обробник Ctrl+C
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Stop-Servers } | Out-Null

try {
    # Перевірка віртуального середовища
    $venvPython = ".\.venv\Scripts\python.exe"
    if (-not (Test-Path $venvPython)) {
        Write-ColorOutput "⚠ Віртуальне середовище .venv не знайдено" "Yellow"
        Write-ColorOutput "  Запустіть: .\setup_python311.ps1" "Yellow"
        $venvPython = "python"
    } else {
        Write-ColorOutput "✓ Використовується віртуальне середовище .venv" "Green"
    }

    # Запуск llama-cpp-python server
    Write-ColorOutput "`n▶ [1/2] Запуск llama-cpp-python server на ${LLAMA_HOST}:${LLAMA_PORT}..." "Cyan"
    
    $llamaArgs = @(
        "-m", "llama_cpp.server",
        "--model", $MODEL_PATH,
        "--host", $LLAMA_HOST,
        "--port", $LLAMA_PORT,
        "--n_gpu_layers", $N_GPU_LAYERS,
        "--n_ctx", $N_CTX,
        "--verbose"
    )
    
    $script:llamaProcess = Start-Process -FilePath $venvPython -ArgumentList $llamaArgs -NoNewWindow -PassThru
    Write-ColorOutput "✓ Llama server запущено (PID: $($script:llamaProcess.Id))" "Green"

    # Очікування готовності llama server
    Write-ColorOutput "⚠ Очікування готовності llama server (до 60 секунд)..." "Yellow"
    $maxAttempts = 30
    $attempt = 0
    $llamaReady = $false
    
    while ($attempt -lt $maxAttempts) {
        try {
            $response = Invoke-WebRequest -Uri "http://${LLAMA_HOST}:${LLAMA_PORT}/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-ColorOutput "✓ Llama server готовий" "Green"
                $llamaReady = $true
                break
            }
        } catch {
            # Ігноруємо, сервер ще не готовий
        }
        Start-Sleep -Seconds 2
        $attempt++
    }
    
    if (-not $llamaReady) {
        Write-ColorOutput "✗ Llama server не запустився за відведений час" "Red"
        Stop-Servers
        exit 1
    }

    # Запуск FastAPI proxy server
    Write-ColorOutput "`n▶ [2/2] Запуск FastAPI proxy server на ${PROXY_HOST}:${PROXY_PORT}..." "Cyan"
    
    $proxyArgs = @(
        "app_server:app",
        "--host", $PROXY_HOST,
        "--port", $PROXY_PORT
    )
    
    $script:proxyProcess = Start-Process -FilePath "uvicorn" -ArgumentList $proxyArgs -NoNewWindow -PassThru
    Write-ColorOutput "✓ Proxy server запущено (PID: $($script:proxyProcess.Id))" "Green"

    # Очікування готовності proxy server
    Write-ColorOutput "⚠ Очікування готовності proxy server..." "Yellow"
    Start-Sleep -Seconds 3
    
    $proxyAttempts = 15
    $proxyAttempt = 0
    $proxyReady = $false
    
    while ($proxyAttempt -lt $proxyAttempts) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:${PROXY_PORT}/docs" -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-ColorOutput "✓ Proxy server готовий" "Green"
                $proxyReady = $true
                break
            }
        } catch {
            # Ігноруємо
        }
        Start-Sleep -Seconds 1
        $proxyAttempt++
    }
    
    if (-not $proxyReady) {
        Write-ColorOutput "⚠ Proxy server може бути ще не готовий" "Yellow"
    }

    # Виведення інформації
    Write-Host ""
    Write-ColorOutput "╔════════════════════════════════════════════════╗" "Green"
    Write-ColorOutput "║         Сервери успішно запущено!              ║" "Green"
    Write-ColorOutput "╚════════════════════════════════════════════════╝" "Green"
    Write-Host ""
    Write-Host "📊 Llama server:  http://${LLAMA_HOST}:${LLAMA_PORT}" -ForegroundColor Cyan
    Write-Host "🚀 Proxy server:  http://${PROXY_HOST}:${PROXY_PORT}" -ForegroundColor Cyan
    Write-Host "📖 API Docs:      http://localhost:${PROXY_PORT}/docs" -ForegroundColor Cyan
    Write-Host ""
    Write-ColorOutput "⚠ Натисніть Ctrl+C для зупинки серверів" "Yellow"
    Write-Host ""

    # Очікування завершення
    while ($true) {
        if ($script:proxyProcess.HasExited -or $script:llamaProcess.HasExited) {
            Write-ColorOutput "⚠ Один з серверів зупинився" "Yellow"
            break
        }
        Start-Sleep -Seconds 1
    }

} catch {
    Write-ColorOutput "✗ Помилка: $_" "Red"
} finally {
    Stop-Servers
}
