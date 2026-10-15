# run_android_app.ps1 - Build, install, push model, and launch the Local Llama Android app
# Usage: .\run_android_app.ps1
$ErrorActionPreference = "Stop"

$sdkRoot   = "$env:LOCALAPPDATA\Android\Sdk"
$adb       = "$sdkRoot\platform-tools\adb.exe"
$sdkMgr    = "$sdkRoot\cmdline-tools\latest\bin\sdkmanager.bat"
$projectDir = "$PSScriptRoot\llama.cpp\examples\llama.android"
$apkPath   = "$projectDir\app\build\outputs\apk\debug\app-debug.apk"
$modelSrc  = "$PSScriptRoot\models\qwen2.5-1.5b-instruct-q4_k_m.gguf"
$modelDst  = "/sdcard/Download/qwen2.5-1.5b-instruct-q4_k_m.gguf"

# Step 1: Verify device
Write-Host "`n=== Checking connected devices ===" -ForegroundColor Cyan
& $adb devices -l
$devices = (& $adb devices) | Where-Object { $_ -match "\tdevice" }
if (-not $devices) {
    Write-Error "No authorized Android device detected. Connect your phone and enable USB Debugging."
    exit 1
}
Write-Host "Device found." -ForegroundColor Green

# Step 2: Install SDK platform 36 if missing
$platform36 = "$sdkRoot\platforms\android-36"
if (-not (Test-Path $platform36)) {
    Write-Host "`n=== Installing Android SDK Platform 36 ===" -ForegroundColor Yellow
    & $sdkMgr --install "platforms;android-36" --sdk_root="$sdkRoot"
} else {
    Write-Host "Android SDK Platform 36 already installed." -ForegroundColor Green
}

# Step 3: Set up local.properties
$localProps = "sdk.dir=$($sdkRoot -replace '\\', '\\\\')"
Set-Content -Path "$projectDir\local.properties" -Value $localProps -Encoding Ascii

# Step 4: Build the debug APK
Write-Host "`n=== Building debug APK (this may take several minutes on first run) ===" -ForegroundColor Cyan
$env:ANDROID_HOME = $sdkRoot
Push-Location $projectDir
try {
    java -cp "gradle/wrapper/gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain assembleDebug
    if ($LASTEXITCODE -ne 0) { throw "Gradle build failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}

if (-not (Test-Path $apkPath)) {
    Write-Error "APK not found at $apkPath - build may have failed."
    exit 1
}
Write-Host "APK built: $apkPath" -ForegroundColor Green

# Step 5: Install APK on device
Write-Host "`n=== Installing APK on device ===" -ForegroundColor Cyan
& $adb install -r $apkPath
if ($LASTEXITCODE -ne 0) {
    Write-Error "adb install failed."
    exit 1
}
Write-Host "APK installed." -ForegroundColor Green

# Step 6: Push model to device
Write-Host "`n=== Pushing model (~1.12 GB) to device ===" -ForegroundColor Cyan
$existingModel = & $adb shell "ls -l $modelDst 2>/dev/null"
if ($existingModel -match "qwen2.5") {
    Write-Host "Model already exists on device - skipping push." -ForegroundColor Green
} else {
    if (-not (Test-Path $modelSrc)) {
        Write-Error "Model file not found at $modelSrc. Run 'python download_model.py' first."
        exit 1
    }
    & $adb push $modelSrc $modelDst
    if ($LASTEXITCODE -ne 0) {
        Write-Error "adb push failed."
        exit 1
    }
    Write-Host "Model pushed to $modelDst" -ForegroundColor Green
}

# Step 7: Launch the app
Write-Host "`n=== Launching app on device ===" -ForegroundColor Cyan
& $adb shell am start -n "com.example.llama.aichat/com.example.llama.MainActivity"

Write-Host "`n====================================================" -ForegroundColor Magenta
Write-Host "  Done! The app is now running on your phone."        -ForegroundColor Magenta
Write-Host "  Tap the button -> select the GGUF model -> chat!"   -ForegroundColor Magenta
Write-Host "====================================================" -ForegroundColor Magenta
