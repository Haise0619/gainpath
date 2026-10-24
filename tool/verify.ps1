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
  # Analyze maintained sources explicitly; ignored build snapshots are evidence,
  # not current sources. They remain on disk and are never deleted by verification.
  $sourcePaths = @('tool', 'test')
  foreach ($package in Get-ChildItem packages,apps -Directory) {
    foreach ($folder in @('lib', 'bin', 'test', 'integration_test', 'tool')) {
      $sourcePath = Join-Path $package.FullName $folder
      if (Test-Path -LiteralPath $sourcePath -PathType Container) { $sourcePaths += $sourcePath }
    }
  }
  Invoke-Checked dart (@('analyze') + $sourcePaths)
  Invoke-Checked dart @('test', 'test')
  foreach ($package in Get-ChildItem packages,apps -Directory) {
    if (Test-Path (Join-Path $package.FullName 'test')) {
      Push-Location $package.FullName
      try {
        if ($package.Name -in @('gainpath_domain', 'gainpath_data', 'gainpath_pose')) {
          Invoke-Checked dart @('test')
        } else {
          Invoke-Checked flutter @('test', '--no-pub')
        }
      } finally { Pop-Location }
    }
  }
  if ($BuildApps) {
    Push-Location apps/admin_web
    try { Invoke-Checked flutter @('build', 'web', '--debug', '--no-pub') } finally { Pop-Location }
    Push-Location apps/mobile
    try { Invoke-Checked flutter @('build', 'apk', '--debug', '--no-pub') } finally { Pop-Location }
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
