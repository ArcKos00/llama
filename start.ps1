# LLM Proxy Server - Start Script
# PowerShell version

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Output functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Load configuration from config.json
$config = Get-Content "config.json" | ConvertFrom-Json
$MODEL_PATH = $config.model.path
$LLAMA_HOST = "127.0.0.1"
$LLAMA_PORT = "8000"
$PROXY_HOST = "0.0.0.0"
$PROXY_PORT = "8080"
$N_GPU_LAYERS = $config.model.gpu_layer
$N_CTX = $config.model.context_size

Write-ColorOutput "========================================" "Green"
Write-ColorOutput "     LLM Proxy Server - Starting       " "Green"
Write-ColorOutput "========================================" "Green"
Write-Host ""

# Global variables for processes
$script:llamaProcess = $null
$script:proxyProcess = $null

# Cleanup function
function Stop-Servers {
    Write-Host ""
    Write-ColorOutput "Stopping servers..." "Yellow"
    
    if ($script:proxyProcess -and !$script:proxyProcess.HasExited) {
        Write-Host "Stopping proxy server (PID: $($script:proxyProcess.Id))"
        Stop-Process -Id $script:proxyProcess.Id -Force -ErrorAction SilentlyContinue
    }
    
    if ($script:llamaProcess -and !$script:llamaProcess.HasExited) {
        Write-Host "Stopping llama server (PID: $($script:llamaProcess.Id))"
        Stop-Process -Id $script:llamaProcess.Id -Force -ErrorAction SilentlyContinue
    }
    
    Write-ColorOutput "Servers stopped" "Green"
}

# Ctrl+C handler
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Stop-Servers } | Out-Null

try {
    # Check virtual environment
    $venvPython = ".\.venv\Scripts\python.exe"
    if (-not (Test-Path $venvPython)) {
        Write-ColorOutput "Virtual environment .venv not found" "Yellow"
        Write-ColorOutput "Run: .\setup.ps1" "Yellow"
        $venvPython = "python"
    } else {
        Write-ColorOutput "Using virtual environment .venv" "Green"
    }

    # Start llama-cpp-python server
    Write-ColorOutput "`n[1/2] Starting llama-cpp-python server on ${LLAMA_HOST}:${LLAMA_PORT}..." "Cyan"
    
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
    Write-ColorOutput "Llama server started (PID: $($script:llamaProcess.Id))" "Green"

    # Wait for llama server to be ready
    Write-ColorOutput "Waiting for llama server to be ready (up to 60 seconds)..." "Yellow"
    $maxAttempts = 30
    $attempt = 0
    $llamaReady = $false
    
    while ($attempt -lt $maxAttempts) {
        try {
            $response = Invoke-WebRequest -Uri "http://${LLAMA_HOST}:${LLAMA_PORT}/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-ColorOutput "Llama server ready" "Green"
                $llamaReady = $true
                break
            }
        } catch {
            # Ignore, server not ready yet
        }
        Start-Sleep -Seconds 2
        $attempt++
    }
    
    if (-not $llamaReady) {
        Write-ColorOutput "Llama server failed to start within timeout" "Red"
        Stop-Servers
        exit 1
    }

    # Start FastAPI proxy server
    Write-ColorOutput "`n[2/2] Starting FastAPI proxy server on ${PROXY_HOST}:${PROXY_PORT}..." "Cyan"
    
    $proxyArgs = @(
        "app_server:app",
        "--host", $PROXY_HOST,
        "--port", $PROXY_PORT
    )
    
    $script:proxyProcess = Start-Process -FilePath "uvicorn" -ArgumentList $proxyArgs -NoNewWindow -PassThru
    Write-ColorOutput "Proxy server started (PID: $($script:proxyProcess.Id))" "Green"

    # Wait for proxy server to be ready
    Write-ColorOutput "Waiting for proxy server to be ready..." "Yellow"
    Start-Sleep -Seconds 3
    
    $proxyAttempts = 15
    $proxyAttempt = 0
    $proxyReady = $false
    
    while ($proxyAttempt -lt $proxyAttempts) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:${PROXY_PORT}/docs" -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-ColorOutput "Proxy server ready" "Green"
                $proxyReady = $true
                break
            }
        } catch {
            # Ignore
        }
        Start-Sleep -Seconds 1
        $proxyAttempt++
    }
    
    if (-not $proxyReady) {
        Write-ColorOutput "Proxy server may not be ready yet" "Yellow"
    }

    # Display information
    Write-Host ""
    Write-ColorOutput "========================================" "Green"
    Write-ColorOutput "      Servers started successfully!    " "Green"
    Write-ColorOutput "========================================" "Green"
    Write-Host ""
    Write-Host "Llama server:  http://${LLAMA_HOST}:${LLAMA_PORT}" -ForegroundColor Cyan
    Write-Host "Proxy server:  http://${PROXY_HOST}:${PROXY_PORT}" -ForegroundColor Cyan
    Write-Host "API Docs:      http://localhost:${PROXY_PORT}/docs" -ForegroundColor Cyan
    Write-Host ""
    Write-ColorOutput "Press Ctrl+C to stop servers" "Yellow"
    Write-Host ""

    # Wait for completion
    while ($true) {
        if ($script:proxyProcess.HasExited -or $script:llamaProcess.HasExited) {
            Write-ColorOutput "One of the servers stopped" "Yellow"
            break
        }
        Start-Sleep -Seconds 1
    }

} catch {
    Write-ColorOutput "Error: $_" "Red"
} finally {
    Stop-Servers
}
