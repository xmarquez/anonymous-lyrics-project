param(
  [string]$PythonExe = "python",
  [bool]$UpdateRenviron = $true
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$venvPath = Join-Path $root ".venv\\empath"
$reqFile = Join-Path $root "requirements-empath.txt"

if (-not (Get-Command $PythonExe -ErrorAction SilentlyContinue)) {
  throw "Python executable not found: $PythonExe"
}

if (-not (Test-Path $reqFile)) {
  throw "requirements-empath.txt not found at $reqFile"
}

& $PythonExe -m venv $venvPath

$pythonVenv = Join-Path $venvPath "Scripts\\python.exe"
& $pythonVenv -m pip install --upgrade pip
& $pythonVenv -m pip install -r $reqFile

Write-Host "Created venv at $venvPath"
$pythonVenvEnv = $pythonVenv -replace '\\','/'
Write-Host "Set RETICULATE_PYTHON=$pythonVenvEnv (or add to .Renviron)"

if ($UpdateRenviron) {
  $renvFile = Join-Path $root ".Renviron"
  if (-not (Test-Path $renvFile)) {
    New-Item -ItemType File -Path $renvFile | Out-Null
  }

  $existing = Get-Content $renvFile -Raw
  if ($existing -notmatch '(^|`r?`n)RETICULATE_PYTHON=') {
    Add-Content -Path $renvFile -Value "`n# Empath Python venv`nRETICULATE_PYTHON=$pythonVenvEnv"
    Write-Host "Updated .Renviron with RETICULATE_PYTHON"
  } else {
    Write-Host "RETICULATE_PYTHON already set in .Renviron"
  }
}
