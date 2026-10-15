# Deploy llama-cli and Qwen2.5-1.5B to connected Android device via ADB
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

Write-Host "=== Checking connected ADB devices ===" -ForegroundColor Cyan
& $adb devices -l

$devices = (& $adb devices) | Where-Object { $_ -match "\tdevice$" }
if (-not $devices) {
    Write-Warning "No authorized Android device detected. Please connect your phone via USB and enable USB Debugging."
    exit 1
}

$targetDir = "/data/local/tmp/llama"
$binDir = "llama.cpp/build-android/bin"
$modelFile = "models/qwen2.5-1.5b-instruct-q4_k_m.gguf"

if (-not (Test-Path "$binDir/llama-cli")) {
    Write-Error "llama-cli binary not found at $binDir/llama-cli. Please wait for the build to finish."
    exit 1
}

if (-not (Test-Path $modelFile)) {
    Write-Error "Model file not found at $modelFile. Please wait for the download to finish."
    exit 1
}

Write-Host "`n=== Creating destination directory on device ($targetDir) ===" -ForegroundColor Cyan
& $adb shell "mkdir -p $targetDir"

Write-Host "`n=== Pushing llama-cli and shared libraries to device ===" -ForegroundColor Cyan
Get-ChildItem $binDir | ForEach-Object {
    Write-Host "Pushing $($_.Name)..."
    & $adb push $_.FullName "$targetDir/$($_.Name)"
}
& $adb shell "chmod +x $targetDir/llama-cli"

Write-Host "`n=== Checking if model already exists on device ===" -ForegroundColor Cyan
$existingModel = & $adb shell "ls -l $targetDir/qwen2.5-1.5b-instruct-q4_k_m.gguf 2>/dev/null"
if ($existingModel -match "qwen2.5") {
    Write-Host "Model file already exists on device:" -ForegroundColor Green
    Write-Host $existingModel
} else {
    Write-Host "Pushing model file (~1.12 GB) to device. This may take 30-60 seconds over USB 3.0..." -ForegroundColor Cyan
    & $adb push $modelFile "$targetDir/qwen2.5-1.5b-instruct-q4_k_m.gguf"
}

Write-Host "`n=== Running on-device inference test ===" -ForegroundColor Green
Write-Host "Command: export LD_LIBRARY_PATH=$targetDir; $targetDir/llama-cli -m $targetDir/qwen2.5-1.5b-instruct-q4_k_m.gguf -c 2048 -n 128 -t 4 -p 'Explain how a CPU executes a program in 2 sentences.'" -ForegroundColor Yellow

& $adb shell "export LD_LIBRARY_PATH=$targetDir; $targetDir/llama-cli -m $targetDir/qwen2.5-1.5b-instruct-q4_k_m.gguf -c 2048 -n 128 -t 4 -p 'Explain how a CPU executes a program in 2 sentences.'"
