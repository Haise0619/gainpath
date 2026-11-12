[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [ValidateRange(0, 10)][int]$StressRuns = 3
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$evidence = Join-Path $repositoryRoot 'build/workout-analytics-verification'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
$flutterCommand = (Get-Command flutter -ErrorAction Stop).Source
$dartCommand = (Get-Command dart -ErrorAction Stop).Source

function Invoke-VerificationGate {
    param([string]$Name, [string]$Directory, [string]$Program, [string[]]$Arguments)
    $log = Join-Path $evidence "$Name.log"
    Push-Location -LiteralPath $Directory
    try {
        & $Program @Arguments *> $log
        $gateExit = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    Get-Content -LiteralPath $log -Tail 3
    if ($gateExit -ne 0) { throw "$Name failed ($gateExit). Full evidence: $log" }
}

$mobile = Join-Path $repositoryRoot 'apps/mobile'
# Render/device-gated cases remain in this list; their existing skips are logged.
$tests = @(git -C $repositoryRoot ls-files apps/mobile/test | Where-Object {
    $_ -match '_test\.dart$' -and
    $_ -match '(workout|routine|progress|pose|floor_push_up|curl|calf_raise|shoulder_press|lateral_raise|between_exercise|program_|goal_comparison_report|exercise_improvement)'
} | ForEach-Object { $_ -replace '^apps/mobile/', '' })
if ($tests.Count -lt 140) { throw 'Expected committed workout test inventory is incomplete.' }
$tests | Set-Content -LiteralPath (Join-Path $evidence 'mobile-test-files.txt')
Invoke-VerificationGate 'mobile' $mobile $flutterCommand (@('test') + $tests + @('--reporter','expanded'))
Invoke-VerificationGate 'domain' (Join-Path $repositoryRoot 'packages/gainpath_domain') $dartCommand @('test','--reporter','expanded')
# CLI tests spawn Platform.resolvedExecutable; use Dart, not flutter_tester.
Invoke-VerificationGate 'pose' (Join-Path $repositoryRoot 'packages/gainpath_pose') $dartCommand @('test','--reporter','expanded')

$sources = @(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'workout-analytics-analysis-files.txt') |
    Where-Object { $_ -match '^apps/mobile/.+\.dart$' } |
    ForEach-Object { $_ -replace '^apps/mobile/', '' })
Invoke-VerificationGate 'analysis-mobile' $mobile $flutterCommand (@('analyze') + $sources)
Invoke-VerificationGate 'analysis-domain' (Join-Path $repositoryRoot 'packages/gainpath_domain') $dartCommand @('analyze','lib/src/analytics/local_member_progress.dart')
for ($run = 1; $run -le $StressRuns; $run++) {
    Invoke-VerificationGate "stress-$run" $mobile $flutterCommand @('test',
        'test/workout_backup_scheduler_test.dart', 'test/workout_cloud_sync_product_test.dart',
        'test/workout_cloud_status_route_test.dart', 'test/routine_journey_controller_test.dart',
        'test/hybrid_routine_journey_test.dart', '--reporter', 'expanded')
}
if (-not $SkipBuild) {
    Invoke-VerificationGate 'android-debug' $mobile $flutterCommand @('build','apk','--debug',
        '--dart-define=WORKOUT_CLOUD_BACKUP_ENABLED=true', '--dart-define=APP_CHECK_IN_ENABLED=true','--no-pub')
    Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $mobile 'build/app/outputs/flutter-apk/app-debug.apk') |
        Format-List | Out-String | Set-Content -LiteralPath (Join-Path $evidence 'android-debug-sha256.txt')
}
Write-Output "Workout analytics verification complete. Logs: $evidence"
