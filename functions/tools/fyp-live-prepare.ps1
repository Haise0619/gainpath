$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$taskRepo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$taskOut=Join-Path $taskRepo 'build/fyp-live-20261104'
$taskNode=Join-Path $taskOut 'toolchain/v22.23.4/node.exe'
$taskBefore=Get-Content -LiteralPath (Join-Path $taskOut 'preflight.json') -Raw|ConvertFrom-Json
if(-not $taskBefore.allReadOnlyChecksPass){throw 'Passing live preflight required'}
$taskArchivePath=Join-Path $taskOut 'provisionMemberRegistration-before.zip'
if((Get-FileHash -LiteralPath $taskArchivePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskBefore.gates.registrationRollback.archiveSha256){throw 'Rollback archive mismatch'}
$taskGuard=Join-Path $taskOut 'registration-ready'
if(Test-Path -LiteralPath $taskGuard){throw 'Fresh preparation directory required; inspect prior artifacts'}
[IO.Directory]::CreateDirectory($taskGuard)|Out-Null
$taskZip=[IO.Compression.ZipFile]::OpenRead($taskArchivePath)
try{foreach($taskEntry in $taskZip.Entries){$taskTarget=[IO.Path]::GetFullPath((Join-Path $taskGuard $taskEntry.FullName));if(-not $taskTarget.StartsWith($taskGuard+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Archive path escape'};if($taskEntry.Length -gt 4194304){throw 'Oversized source entry'};if($taskEntry.FullName.EndsWith('/')){[IO.Directory]::CreateDirectory($taskTarget)|Out-Null;continue};[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($taskTarget))|Out-Null;[IO.Compression.ZipFileExtensions]::ExtractToFile($taskEntry,$taskTarget,$false)}}finally{$taskZip.Dispose()}
$taskUtf8=New-Object Text.UTF8Encoding($false)
$taskTs=Join-Path $taskGuard 'src/modules/identity/member-provisioning.ts'
$taskJs=Join-Path $taskGuard 'lib/modules/identity/member-provisioning.js'
foreach($taskFile in @($taskTs,$taskJs)){
 $taskContent=[IO.File]::ReadAllText($taskFile)
 $taskNeedle=if($taskFile.EndsWith('.ts')){'    const organization = await transaction.get(organizationPath);'}else{'        const organization = await transaction.get(organizationPath);'}
 $taskGuardText=if($taskFile.EndsWith('.ts')){@'
    // Server-owned assignment includes disabled reservations/tombstones.
    if (await transaction.get(`datasetAssignments/${input.userId}`)) {
      throw new DomainError('permission-denied', 'This account requires its assigned dataset session.');
    }
'@}else{@'
        // Server-owned assignment includes disabled reservations/tombstones.
        if (await transaction.get(`datasetAssignments/${input.userId}`)) {
            throw new errors_1.DomainError('permission-denied', 'This account requires its assigned dataset session.');
        }
'@}
 if(($taskContent.Split(@($taskNeedle),[StringSplitOptions]::None).Count -ne 2)-or $taskContent.Contains('datasetAssignments/')){throw 'Exact current provisioning source shape changed'}
 [IO.File]::WriteAllText($taskFile,$taskContent.Replace($taskNeedle,$taskGuardText.Replace("`r`n","`n")+"`n"+$taskNeedle),$taskUtf8)
}
# Only TS/JS insertion; existing package/config/exports and all other files persist.
[IO.Compression.ZipFile]::CreateFromDirectory($taskGuard,(Join-Path $taskOut 'registration-ready.zip'))
Push-Location (Join-Path $taskRepo 'functions')
try{& $taskNode 'node_modules/typescript/bin/tsc' '-p' 'tsconfig.fyp-release.json';if($LASTEXITCODE -ne 0){throw 'Release compilation failed'}}finally{Pop-Location}
$taskRelease=Join-Path $taskOut 'fyp-ready'
if(Test-Path -LiteralPath $taskRelease){throw 'Fresh FYP package directory required'}
[IO.Directory]::CreateDirectory($taskRelease)|Out-Null
Copy-Item -LiteralPath (Join-Path $taskOut 'release-compiled') -Destination (Join-Path $taskRelease 'lib') -Recurse
Copy-Item -LiteralPath (Join-Path $taskRepo 'functions/fyp-release.package.json') -Destination (Join-Path $taskRelease 'package.json')
[IO.Compression.ZipFile]::CreateFromDirectory($taskRelease,(Join-Path $taskOut 'fyp-ready.zip'))
Write-Output 'Prepared exact source-only registration guard and isolated two-callable package. No deployment performed.'
