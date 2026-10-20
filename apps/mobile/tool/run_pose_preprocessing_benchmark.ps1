param(
  [string]$DartExecutable = 'dart',
  [switch]$VerifySpeedup,
  [string]$ResultName = 'preprocessing-host-aot',
  [string]$BenchmarkSource = 'benchmark_pose_preprocessing.dart'
)
$ErrorActionPreference = 'Stop'
if ($ResultName -notmatch '^[a-zA-Z0-9_-]+$') {
  throw 'ResultName must be a filename stem without path separators.'
}
if ($BenchmarkSource -notin @('benchmark_pose_preprocessing.dart', 'benchmark_pose_sampler.dart')) {
  throw 'Select a supported local preprocessing benchmark.'
}
$mobileRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspaceRoot = (Resolve-Path (Join-Path $mobileRoot '../..')).Path
$originalConfig = Join-Path $workspaceRoot '.dart_tool/package_config.json'
$configUri = [Uri]::new($originalConfig)
$config = Get-Content -Raw -LiteralPath $originalConfig | ConvertFrom-Json
$needed = @('gainpath_mobile', 'gainpath_pose', 'crypto', 'typed_data', 'collection')
$projected = @($config.packages | Where-Object { $_.name -in $needed })
if ($projected.Count -ne $needed.Count) { throw 'Resolve workspace packages first.' }
foreach ($package in $projected) {
  $package.rootUri = [Uri]::new($configUri, [string]$package.rootUri).AbsoluteUri
}
# A standalone pure-Dart harness prevents the unrelated Flutter/TFLite native
# build hooks from blocking `dart compile exe`; workspace files stay unchanged.
$harness = Join-Path $mobileRoot 'build/pose-quality/preprocessing-aot'
$localConfigDir = Join-Path $harness '.dart_tool'
New-Item -ItemType Directory -Force -Path $localConfigDir | Out-Null
@{configVersion = 2; packages = $projected} | ConvertTo-Json -Depth 8 |
  Set-Content -LiteralPath (Join-Path $localConfigDir 'package_config.json') -Encoding utf8
"name: gainpath_preprocessing_benchmark`nenvironment:`n  sdk: '>=3.6.0 <4.0.0'" |
  Set-Content -LiteralPath (Join-Path $harness 'pubspec.yaml') -Encoding utf8
# The generated entry point is a copy, not a second product source directory.
"analyzer:`n  exclude:`n    - '**'" |
  Set-Content -LiteralPath (Join-Path $harness 'analysis_options.yaml') -Encoding utf8
$source = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot $BenchmarkSource)
foreach ($support in @('preprocessing_baseline.dart', 'preprocessing_fixture.dart', 'preprocessing_step2c_control.dart')) {
  $supportPath = Join-Path $mobileRoot "test/support/$support"
  $source = $source.Replace("../test/support/$support", [Uri]::new($supportPath).AbsoluteUri)
}
Set-Content -LiteralPath (Join-Path $harness 'main.dart') -Value $source -Encoding utf8
$executable = Join-Path $harness "$ResultName.exe"
$output = Join-Path $harness "$ResultName.json"
Push-Location $harness
try {
  & $DartExecutable compile exe main.dart -o $executable
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  if ($VerifySpeedup) {
    & $executable --verify-speedup | Tee-Object -FilePath $output
  } else {
    & $executable | Tee-Object -FilePath $output
  }
  $benchmarkExit = $LASTEXITCODE
} finally {
  Pop-Location
}
exit $benchmarkExit
