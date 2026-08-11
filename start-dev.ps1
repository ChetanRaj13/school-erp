# Usage: .\start-dev.ps1
# Or: powershell -ExecutionPolicy Bypass -File .\start-dev.ps1

$ErrorActionPreference = "Stop"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " Starting School ERP Local Development Environment" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check prerequisites
$omrDir = Join-Path $PSScriptRoot "services\omr-pipeline"
$appDir = Join-Path $PSScriptRoot "app"

if (-not (Test-Path (Join-Path $omrDir "main.py"))) {
    Write-Host "[ERROR] Could not find OMR pipeline service at '$omrDir'." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path (Join-Path $appDir "pubspec.yaml"))) {
    Write-Host "[ERROR] Could not find Flutter app at '$appDir'." -ForegroundColor Red
    exit 1
}

# Check Python availability
try {
    $pythonVer = python --version 2>&1
    Write-Host "[CHECK] Python detected: $pythonVer" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Python is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install Python 3.9+ to run the OMR attendance service." -ForegroundColor Yellow
    exit 1
}

# Check uvicorn availability
try {
    python -c "import uvicorn" 2>&1 | Out-Null
    Write-Host "[CHECK] uvicorn module detected." -ForegroundColor Green
} catch {
    Write-Host "[ERROR] 'uvicorn' module is missing in Python environment." -ForegroundColor Red
    Write-Host "Please install service dependencies by running:" -ForegroundColor Yellow
    Write-Host "  pip install -r services/omr-pipeline/requirements.txt" -ForegroundColor Yellow
    exit 1
}

# Check Flutter availability
try {
    $flutterVer = flutter --version 2>&1 | Select-Object -First 1
    Write-Host "[CHECK] Flutter detected: $flutterVer" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Flutter is not installed or not in PATH." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[1/2] Starting OMR Attendance Service (FastAPI) on http://localhost:8002..." -ForegroundColor Cyan

# Launch OMR FastAPI server in a new terminal window
$omrProcess = Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$omrDir'; Write-Host 'Starting OMR Service on port 8002...' -ForegroundColor Cyan; python -m uvicorn main:app --port 8002" -PassThru

Start-Sleep -Seconds 2

if (-not $omrProcess.HasExited) {
    Write-Host "[SUCCESS] OMR Attendance Service started (PID: $($omrProcess.Id)) at http://localhost:8002" -ForegroundColor Green
} else {
    Write-Host "[WARNING] OMR process exited unexpectedly. Check port 8002 availability." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[2/2] Starting Flutter Web App..." -ForegroundColor Cyan
Write-Host "Executing 'flutter run -d chrome' in '$appDir'..." -ForegroundColor Gray
Write-Host ""

Set-Location $appDir
flutter run -d chrome
