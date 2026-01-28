# name2port installer (Windows PowerShell)
# - Ensures Python is available (prefers "py" launcher)
# - Installs name2port via pip (user install)
# - Optional: creates a command shim in a chosen folder and can add it to PATH
# - Supports -y to auto-accept prompts

param(
  [switch]$y,
  [ValidateSet("ask","never","always")]
  [string]$Link = "ask",
  [ValidateSet("user","system")]
  [string]$LinkTarget = "user"
)

$App = "name2port"

function Write-Ok($msg) { Write-Host "==> $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "==> $msg" -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

function Prompt-YesNo($q, $defaultYes=$true) {
  if ($y) { return $true }
  $suffix = $(if ($defaultYes) {"[Y/n]"} else {"[y/N]"})
  $ans = Read-Host "$q $suffix"
  if ([string]::IsNullOrWhiteSpace($ans)) { return $defaultYes }
  return $ans.ToLower().StartsWith("y")
}

function Has-Cmd($cmd) {
  return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

Write-Ok "Starting $App installer..."

if (-not (Has-Cmd "py") -and -not (Has-Cmd "python")) {
  Write-Warn "Python not found."
  Write-Warn "Install Python from the Microsoft Store or https://www.python.org/downloads/windows/"
  Write-Err "Python is required."
}

$Python = $(if (Has-Cmd "py") { "py" } else { "python" })

Write-Ok "Installing $App via pip (user)..."
& $Python -m pip install --user --upgrade $App | Out-Host

$userBase = & $Python -c "import site; print(site.getuserbase())"
$ScriptsDir = Join-Path $userBase "Scripts"
$Exe = Join-Path $ScriptsDir "$App.exe"

if (-not (Test-Path $Exe)) {
  Write-Warn "Installed, but couldn't locate $Exe."
  Write-Warn "Try closing/reopening PowerShell, or ensure '$ScriptsDir' is on PATH."
} else {
  Write-Ok "Installed executable: $Exe"
}

if ($Link -eq "never") {
  Write-Ok "Skipping linking (-Link never)."
  exit 0
}

if (-not (Test-Path $Exe)) {
  Write-Warn "Skipping linking: executable not found."
  exit 0
}

$TargetDir = $(if ($LinkTarget -eq "system") { "C:\Program Files\name2port\bin" } else { "$env:USERPROFILE\bin" })
$Shim = Join-Path $TargetDir "name2port.cmd"

if ($Link -eq "ask") {
  if (-not (Prompt-YesNo "Create a command shim so 'name2port' is ready to run?" $true)) {
    Write-Ok "No shim created."
    exit 0
  }
  if (-not $y) {
    $choice = Read-Host "Install shim to (u)ser bin or (s)ystem bin? [u/s]"
    if ($choice.ToLower().StartsWith("s")) { $TargetDir = "C:\Program Files\name2port\bin" }
  }
}

if (-not (Test-Path $TargetDir)) {
  New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

$cmdContent = "@echo off`r`n`"$Exe`" %*`r`n"
Set-Content -Path $Shim -Value $cmdContent -Encoding ASCII
Write-Ok "Created shim: $Shim"

if ($TargetDir -notin ($env:Path -split ';')) {
  if ($Link -eq "always" -or (Prompt-YesNo "Add '$TargetDir' to your user PATH?" $true)) {
    $newPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ([string]::IsNullOrEmpty($newPath)) { $newPath = "" }
    if (-not ($newPath -split ';' | Where-Object { $_ -eq $TargetDir })) {
      $newPath = ($newPath.TrimEnd(';') + ";" + $TargetDir).TrimStart(';')
      [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
      Write-Ok "Added to user PATH. Restart your terminal to take effect."
    }
  }
}

Write-Ok "Done. Try: name2port bento-pdf"
