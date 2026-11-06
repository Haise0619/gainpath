$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$taskRepo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$taskOut=Join-Path $taskRepo 'build/unified-admin-20261104'
$taskStage=Join-Path $taskOut 'command-ready'
if(Test-Path -LiteralPath $taskStage){throw 'Staged package already exists; preserve it and inspect before preparing another version.'}
$taskBefore=Join-Path $taskOut 'fyp-before.zip'
if((Get-FileHash -LiteralPath $taskBefore -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'd535052a81a759ed352a60576910fbaac94a7851aa778d6df3c8e23ccf539b24'){throw 'Approved existing command archive changed.'}
[IO.Compression.ZipFile]::ExtractToDirectory($taskBefore,$taskStage)
$taskNames=@('fyp-release-index','modules/dataset/fyp-backend','modules/dataset/fyp-scope','modules/dataset/fyp-module-services','modules/dataset/unified-admin-scope','modules/dataset/unified-admin-reader','modules/dataset/unified-admin-reporting','modules/dataset/unified-admin-backend','modules/dataset/unified-business-reader','modules/dataset/unified-sample-business')
foreach($taskName in $taskNames){foreach($taskSuffix in @('.js','.js.map')){
 $taskSource=Join-Path $taskOut ('compiled/'+$taskName+$taskSuffix)
 $taskTarget=Join-Path $taskStage ('lib/'+$taskName+$taskSuffix)
 if(!(Test-Path -LiteralPath $taskSource)){throw "Missing compiled artifact: $taskName$taskSuffix"}
 [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($taskTarget)) | Out-Null
 [IO.File]::Copy($taskSource,$taskTarget,$false -or (Test-Path -LiteralPath $taskTarget))
}}
$taskArchive=Join-Path $taskOut 'command-ready.zip'
if(Test-Path -LiteralPath $taskArchive){throw 'Archive exists; preserve it.'}
[IO.Compression.ZipFile]::CreateFromDirectory($taskStage,$taskArchive,[IO.Compression.CompressionLevel]::Optimal,$false)
$taskInventory=@{}
$taskZip=[IO.Compression.ZipFile]::OpenRead($taskArchive)
try{foreach($taskEntry in $taskZip.Entries){
 $taskKey=$taskEntry.FullName.Replace('\','/')
 if($taskKey.EndsWith('/')){continue}
 if($taskKey.StartsWith('/') -or $taskKey.Split('/') -contains '..' -or $taskInventory.ContainsKey($taskKey)){throw 'Invalid archive entry.'}
 $taskStream=$taskEntry.Open();$taskHasher=[Security.Cryptography.SHA256]::Create()
 try{$taskInventory[$taskKey]=[BitConverter]::ToString($taskHasher.ComputeHash($taskStream)).Replace('-','').ToLowerInvariant()}finally{$taskStream.Dispose();$taskHasher.Dispose()}
}}finally{$taskZip.Dispose()}
@{archiveSha256=(Get-FileHash -LiteralPath $taskArchive -Algorithm SHA256).Hash.ToLowerInvariant();files=$taskInventory} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $taskOut 'archive-inventory.json') -Encoding utf8NoBOM
Write-Output 'Prepared exact existing command archive with bounded unified read modules; no deployment.'
