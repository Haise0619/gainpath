# Requires PowerShell 7. Preview is the default, including for explicit selections.
[CmdletBinding()]
param(
    [string[]] $RelativePath,
    [switch] $Apply,
    [string] $ResultFile
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).ProviderPath
$rootPrefix = [IO.Path]::TrimEndingDirectorySeparator($root) + [IO.Path]::DirectorySeparatorChar
$comparison = [StringComparison]::OrdinalIgnoreCase
$reparse = [IO.FileAttributes]::ReparsePoint
$gradleTasks = 'merged_native_libs|incremental|stripped_native_libs|flutter|assets|compressed_assets|dex'
$cachePattern = '^(?:build/(?:[^/]+/)*)?apps/(?:(?:mobile|admin_web)/(?:\.dart_tool/flutter_build|build/(?:test_cache|unit_test_assets))|mobile/build/app/intermediates/(?:' + $gradleTasks + '))$'
$protectedNames = '^(?:\.git|\.env.*|key\.properties|pubspec\.lock|pnpm-lock\.yaml)$|(?:^|[._-])(?:private|rollback|credentials?|secrets?|keystore|service-account|serviceaccount|adminsdk)(?:$|[._-])'
$protectedFileTypes = '\.(?:apk|aab|jks|keystore|p12|pfx|pem|docx|xlsx|pptx|pdf|zip|7z|tar|gz)$'

function Assert-GitSuccess([string] $Description) {
    if ($LASTEXITCODE -ne 0) { throw "$Description failed with exit code $LASTEXITCODE." }
}

function Get-SafeTreeSize([IO.DirectoryInfo] $Directory) {
    $folders = [Collections.Generic.Stack[IO.DirectoryInfo]]::new()
    $folders.Push($Directory)
    [long] $count = 0
    [long] $bytes = 0
    while ($folders.Count) {
        foreach ($entry in $folders.Pop().EnumerateFileSystemInfos()) {
            if (($entry.Attributes -band $reparse) -or $entry.Name -match $protectedNames) {
                throw "Protected, ambiguous, or linked entry in $($Directory.FullName)."
            }
            if ($entry -is [IO.DirectoryInfo]) {
                $folders.Push($entry)
            } elseif ($entry -is [IO.FileInfo] -and $entry.Name -notmatch $protectedFileTypes) {
                $count++
                $bytes += $entry.Length
            } else {
                throw "Unexpected file type in $($Directory.FullName)."
            }
        }
    }
    return @{ Files = $count; Bytes = $bytes }
}

function Assert-IdleToolchain {
    # Conservatively refuse writes when Flutter/Dart is working, or a Gradle or
    # Firebase emulator JVM is present. No processes are stopped by this tool.
    $busy = @(Get-CimInstance Win32_Process -Filter "Name='dart.exe' OR Name='dartvm.exe' OR Name='flutter_tester.exe' OR Name='java.exe' OR Name='javaw.exe'" |
        Where-Object { $_.Name -notlike 'java*' -or $_.CommandLine -match 'GradleDaemon|GradleWrapperMain|firestore-emulator|storage-rules-runtime' })
    if ($busy.Count) {
        throw ('Build or emulator processes are present. Close them before cleanup. Process IDs ' + ($busy.ProcessId -join ', '))
    }
}

if (-not $IsWindows) { throw 'This cleanup tool uses Windows path and reparse-point checks.' }
if ((Get-Item -LiteralPath $root -Force).Attributes -band $reparse) { throw 'The repository root is a linked directory.' }
if ($Apply -and -not $RelativePath.Count) { throw 'Apply requires explicit -RelativePath selections.' }
if ($ResultFile) {
    $ResultFile = [IO.Path]::GetFullPath($ResultFile)
    if (Test-Path -LiteralPath $ResultFile) { throw 'The result file already exists.' }
    if (-not (Test-Path -LiteralPath (Split-Path -Parent $ResultFile) -PathType Container)) {
        throw 'The result directory must exist.'
    }
}

$gitRoot = git -C $root rev-parse --show-toplevel
Assert-GitSuccess 'Resolving the repository root'
if (-not [IO.Path]::GetFullPath($gitRoot).Equals($root, $comparison)) {
    throw 'Run the tool from its original location in the GainPath Git root.'
}

if (-not $RelativePath.Count) {
    $RelativePath = foreach ($app in 'mobile', 'admin_web') {
        foreach ($suffix in '.dart_tool/flutter_build', 'build/test_cache', 'build/unit_test_assets') {
            if (Test-Path -LiteralPath (Join-Path $root "apps/$app/$suffix")) { "apps/$app/$suffix" }
        }
    }
    foreach ($task in ($gradleTasks -split '\|')) {
        $path = "apps/mobile/build/app/intermediates/$task"
        if (Test-Path -LiteralPath (Join-Path $root $path)) { $RelativePath += $path }
    }
}

$tracked = git -C $root -c core.quotePath=false ls-files --cached
Assert-GitSuccess 'Reading tracked paths'
$trackedPrefixes = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($path in $tracked) {
    while ($path) {
        [void] $trackedPrefixes.Add($path)
        $last = $path.LastIndexOf('/')
        if ($last -lt 0) { break }
        $path = $path.Substring(0, $last)
    }
}

$worktreeData = git -C $root worktree list --porcelain
Assert-GitSuccess 'Reading worktree locations'
$nestedWorktrees = @($worktreeData | Where-Object { $_.StartsWith('worktree ') } | ForEach-Object {
    [IO.Path]::GetFullPath($_.Substring(9))
} | Where-Object { -not $_.Equals($root, $comparison) })
$unique = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$targets = foreach ($path in $RelativePath) {
    $relative = $path.Replace('\', '/')
    $segments = $relative -split '/'
    if ($relative -cnotmatch $cachePattern -or $relative -match '[:\x00-\x1f]' -or
        @($segments | Where-Object { $_ -match '^(?:\.+|private|rollback|evidence|admin-before|admin-ready|pose-quality|local-run)$' }).Count) {
        throw "Unsupported or protected cleanup path $path."
    }
    if (-not $unique.Add($relative)) { continue }
    if ($trackedPrefixes.Contains($relative)) { throw "Tracked Git content found at $relative." }
    git -C $root check-ignore -q -- $relative
    Assert-GitSuccess "Checking ignore status of $relative"

    $full = [IO.Path]::GetFullPath((Join-Path $root $relative))
    $item = Get-Item -LiteralPath $full -Force
    if ($item -isnot [IO.DirectoryInfo] -or -not $full.StartsWith($rootPrefix, $comparison) -or
        -not (Resolve-Path -LiteralPath $full).ProviderPath.Equals($full, $comparison)) {
        throw "Cleanup target failed its physical path check at $relative."
    }
    foreach ($worktree in $nestedWorktrees) {
        if ($full.Equals($worktree, $comparison) -or
            $full.StartsWith($worktree + [IO.Path]::DirectorySeparatorChar, $comparison) -or
            $worktree.StartsWith($full + [IO.Path]::DirectorySeparatorChar, $comparison)) {
            throw "Registered worktree overlaps $relative."
        }
    }
    for ($parent = $item; -not $parent.FullName.Equals($root, $comparison); $parent = $parent.Parent) {
        if (($parent.Attributes -band $reparse) -or (Test-Path -LiteralPath (Join-Path $parent.FullName '.git'))) {
            throw "Linked or nested Git directory includes $relative."
        }
    }
    $app = $relative -replace '/(?:\.dart_tool/flutter_build|build/(?:test_cache|unit_test_assets|app/intermediates/[^/]+))$', ''
    if (-not (Test-Path -LiteralPath (Join-Path $root "$app/pubspec.yaml") -PathType Leaf) -or
        -not (Test-Path -LiteralPath (Join-Path $root "$app/lib/main.dart") -PathType Leaf)) {
        throw "Cannot verify parent Flutter app for $relative."
    }
    $measurement = Get-SafeTreeSize $item
    [pscustomobject] @{ Path = $relative; FullPath = $item.FullName; Files = $measurement.Files; Bytes = $measurement.Bytes }
}

$drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($root))
$before = $drive.AvailableFreeSpace
if ($Apply) { Assert-IdleToolchain }
$results = foreach ($target in $targets) {
    $status = 'preview'
    $detail = ''
    if ($Apply) {
        try {
            Remove-Item -LiteralPath $target.FullPath -Recurse -ErrorAction Stop
            if (Test-Path -LiteralPath $target.FullPath) { throw 'Target remains after cleanup.' }
            $status = 'removed'
        } catch {
            $status = 'error'
            $detail = $_.Exception.Message
        }
    }
    [pscustomobject] @{ Path = $target.Path; Files = $target.Files; Bytes = $target.Bytes; Status = $status; Detail = $detail }
}

$report = [pscustomobject] @{
    Repository = $root
    Mode = if ($Apply) { 'apply' } else { 'preview' }
    FreeBefore = $before
    FreeAfter = $drive.AvailableFreeSpace
    LogicalBytesRemoved = [long] (($results | Where-Object Status -EQ 'removed' | Measure-Object Bytes -Sum).Sum)
    Targets = @($results)
}
if ($ResultFile) { $report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ResultFile -Encoding utf8NoBOM }
$report
