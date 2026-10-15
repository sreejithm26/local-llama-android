# Build and Install Llama Android App
param(
    [switch]$InstallOnly
)

$ErrorActionPreference = "Stop"

$androidSdk = "$env:LOCALAPPDATA\Android\Sdk"
$adb = "$androidSdk\platform-tools\adb.exe"
$projectDir = "$PSScriptRoot\llama.cpp\examples\llama.android"
$apkPath = "$projectDir\app\build\outputs\apk\debug\app-debug.apk"
$modelFile = "$PSScriptRoot\models\qwen2.5-1.5b-instruct-q4_k_m.gguf"

if (-not $InstallOnly) {
    Write-Host "=== Setting up local.properties ===" -ForegroundColor Cyan
    $localProperties = "sdk.dir=$($androidSdk -replace '\\', '\\')"
    Set-Content -Path "$projectDir\local.properties" -Value $localProperties -Encoding UTF8

    Write-Host "=== Building Android APK with Gradle ===" -ForegroundColor Cyan
    $env:ANDROID_HOME = $androidSdk
    Push-Location $projectDir
    try {
        java -cp "gradle/wrapper/gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain assembleDebug
    } finally {
        Pop-Location
    }
}

if (-not (Test-Path $apkPath)) {
    Write-Error "APK not found at $apkPath. Build might have failed."
    exit 1
}

Write-Host "`n=== APK built successfully! ===" -ForegroundColor Green
Write-Host "APK Location: $apkPath" -ForegroundColor Green

# Check if ADB device is connected
Write-Host "`n=== Checking connected Android devices ===" -ForegroundColor Cyan
$devices = (& $adb devices) | Where-Object { $_ -match "\tdevice$" }
if (-not $devices) {
    Write-Warning "No connected Android device found via ADB."
    Write-Host "You can manually install the APK by transferring it to your phone:"
    Write-Host "  $apkPath" -ForegroundColor Yellow
    exit 0
}

Write-Host "Device detected. Installing APK on device..." -ForegroundColor Cyan
& $adb install -r $apkPath

Write-Host "`n=== Checking model in phone's Download directory ===" -ForegroundColor Cyan
$remoteDownload = "/sdcard/Download/qwen2.5-1.5b-instruct-q4_k_m.gguf"
$hasModel = & $adb shell "ls -l $remoteDownload 2>/dev/null"
if ($hasModel -match "qwen2.5") {
    Write-Host "Model already exists in phone Download folder: $remoteDownload" -ForegroundColor Green
} else {
    if (Test-Path $modelFile) {
        Write-Host "Pushing Qwen2.5 model (~1.12GB) to phone's Download folder for easy access in app..." -ForegroundColor Cyan
        & $adb push $modelFile $remoteDownload
        Write-Host "Model copied to $remoteDownload" -ForegroundColor Green
    } else {
        Write-Warning "Local model file not found at $modelFile. Run python download_model.py first."
    }
}

Write-Host "`n=== Ready to run! ===" -ForegroundColor Green
Write-Host "1. Open the 'Llama' / 'AI Chat' app on your phone."
Write-Host "2. Tap the floating button in the bottom right to select a model."
Write-Host "3. Browse to your 'Downloads' folder and select 'qwen2.5-1.5b-instruct-q4_k_m.gguf'."
Write-Host "4. Start chatting completely locally on your phone!"
