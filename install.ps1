# Sets up Piper TTS + the F1 read-aloud hotkey on Windows.
# Usage (PowerShell, from this folder):
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -Voice en_GB-alba-medium -NoStartup

param(
    [string]$Voice = "en_GB-cori-high",
    [string]$InstallDir = "$HOME\piper",
    [switch]$NoStartup
)

$ErrorActionPreference = "Stop"

function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

# 1. Python 3.9+
Step "Checking for Python"
$python = $null
foreach ($cmd in @("py", "python")) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    # skip the Microsoft Store stub in WindowsApps
    if ($found -and $found.Source -notlike "*WindowsApps*") { $python = $found.Source; break }
}
if (-not $python) {
    Step "Installing Python 3.12 with winget"
    winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements
    Write-Host "Python installed. Open a NEW PowerShell window and run this script again." -ForegroundColor Yellow
    exit 1
}
& $python --version

# 2. Folder + virtual environment + Piper
Step "Installing Piper into $InstallDir"
New-Item -ItemType Directory -Force $InstallDir | Out-Null
$venvPython = Join-Path $InstallDir ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) { & $python -m venv (Join-Path $InstallDir ".venv") }
& $venvPython -m pip install --quiet --upgrade pip
& $venvPython -m pip install --quiet piper-tts

# 3. Voice
if (Test-Path (Join-Path $InstallDir "$Voice.onnx")) {
    Step "Voice $Voice already downloaded"
} else {
    Step "Downloading voice $Voice"
    & $venvPython -m piper.download_voices $Voice --data-dir $InstallDir
}

# 4. Quick test
Step "Generating test.wav"
$testWav = Join-Path $InstallDir "test.wav"
& $venvPython -m piper -m $Voice --data-dir $InstallDir -f $testWav -- "Hello, Piper is working."
if (-not (Test-Path $testWav)) { throw "Piper did not produce test.wav" }

# 5. AutoHotkey v2
Step "Installing AutoHotkey v2 (skipped if already installed)"
winget install --id AutoHotkey.AutoHotkey -e --accept-source-agreements --accept-package-agreements
# winget returns non-zero when the package is already installed; that's fine
$global:LASTEXITCODE = 0

# 6. Hotkey script (with the chosen voice)
Step "Copying speak.ahk"
$ahkSource = Join-Path $PSScriptRoot "speak.ahk"
$ahkTarget = Join-Path $InstallDir "speak.ahk"
$script = Get-Content $ahkSource -Raw
$script = $script -replace '(?m)^Voice\s*:=\s*".*?"', "Voice    := `"$Voice`""
if ($InstallDir -ne "$HOME\piper") {
    $escaped = $InstallDir.Replace('"', '""')
    $script = $script -replace '(?m)^PiperDir\s*:=.*$', "PiperDir := `"$escaped`""
}
Set-Content -Path $ahkTarget -Value $script -Encoding UTF8 -NoNewline

# 7. Start with Windows
if (-not $NoStartup) {
    Step "Adding to Windows startup"
    $lnk = Join-Path ([Environment]::GetFolderPath("Startup")) "speak.lnk"
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
    $shortcut.TargetPath = $ahkTarget
    $shortcut.WorkingDirectory = $InstallDir
    $shortcut.Save()
}

# 8. Launch (#SingleInstance Force replaces any running copy)
Step "Starting the hotkey"
Start-Process $ahkTarget

Write-Host ""
Write-Host "Done. Highlight text anywhere and press F1 to hear it; F2 stops." -ForegroundColor Green
