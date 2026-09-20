param([switch]$BuildApps, [switch]$Backend, [switch]$Emulators)
$ErrorActionPreference = 'Stop'
$workspacePath = Split-Path $PSScriptRoot -Parent
function Invoke-Checked {
  param([string]$Command, [string[]]$Arguments)
  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) { throw "$Command failed ($LASTEXITCODE)" }
}
Push-Location $workspacePath
try {
  Invoke-Checked flutter @('pub', 'get', '--enforce-lockfile')
  Invoke-Checked dart @('run', 'tool/check_architecture.dart')
  Invoke-Checked dart @('analyze', 'apps', 'packages', 'tool', 'test')
  Invoke-Checked flutter @('test', '--no-pub', 'test')
  foreach ($package in Get-ChildItem packages,apps -Directory) {
    if (Test-Path (Join-Path $package.FullName 'test')) {
      Push-Location $package.FullName
      try { Invoke-Checked flutter @('test', '--no-pub') } finally { Pop-Location }
    }
  }
  if ($BuildApps) {
    Push-Location apps/admin_web
    try { Invoke-Checked flutter @('build', 'web', '--debug', '--no-pub', '--dart-define=BACKEND=mock') } finally { Pop-Location }
    Push-Location apps/mobile
    try { Invoke-Checked flutter @('build', 'apk', '--debug', '--no-pub', '--dart-define=BACKEND=mock') } finally { Pop-Location }
  }
  if ($Backend -or $Emulators) {
    Push-Location functions
    try {
      Invoke-Checked pnpm @('install', '--frozen-lockfile')
      Invoke-Checked pnpm @('run', 'build')
      Invoke-Checked pnpm @('run', 'typecheck:tests')
      Invoke-Checked pnpm @('test')
      if ($Emulators) { Invoke-Checked pnpm @('run', 'test:emulator') }
    } finally { Pop-Location }
  }
} finally { Pop-Location }
