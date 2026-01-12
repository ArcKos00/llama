# Скрипт для зупинки LLM Proxy Server
# PowerShell версія

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput "⚠ Зупинка серверів..." "Yellow"

$stoppedCount = 0

# Зупинка процесів на порту 8080 (Proxy Server)
try {
    $proxyProcesses = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue | 
        Select-Object -ExpandProperty OwningProcess -Unique

    if ($proxyProcesses) {
        foreach ($pid in $proxyProcesses) {
            try {
                $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
                if ($process) {
                    Write-Host "Зупинка proxy server (PID: $pid, процес: $($process.Name))"
                    Stop-Process -Id $pid -Force
                    $stoppedCount++
                }
            } catch {
                # Ігноруємо помилки
            }
        }
    }
} catch {
    # Ігноруємо помилки
}

# Зупинка процесів на порту 8000 (Llama Server)
try {
    $llamaProcesses = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue | 
        Select-Object -ExpandProperty OwningProcess -Unique

    if ($llamaProcesses) {
        foreach ($pid in $llamaProcesses) {
            try {
                $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
                if ($process) {
                    Write-Host "Зупинка llama server (PID: $pid, процес: $($process.Name))"
                    Stop-Process -Id $pid -Force
                    $stoppedCount++
                }
            } catch {
                # Ігноруємо помилки
            }
        }
    }
} catch {
    # Ігноруємо помилки
}

# Додатково: пошук процесів uvicorn та python з llama_cpp.server
$uvicornProcesses = Get-Process -Name "uvicorn" -ErrorAction SilentlyContinue
foreach ($proc in $uvicornProcesses) {
    Write-Host "Зупинка uvicorn (PID: $($proc.Id))"
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    $stoppedCount++
}

$pythonProcesses = Get-Process -Name "python*" -ErrorAction SilentlyContinue
foreach ($proc in $pythonProcesses) {
    try {
        $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)").CommandLine
        if ($cmdLine -match "llama_cpp\.server") {
            Write-Host "Зупинка python llama server (PID: $($proc.Id))"
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            $stoppedCount++
        }
    } catch {
        # Ігноруємо помилки
    }
}

if ($stoppedCount -gt 0) {
    Write-ColorOutput "✓ Зупинено $stoppedCount процес(ів)" "Green"
} else {
    Write-ColorOutput "⚠ Сервери не запущені" "Yellow"
}
