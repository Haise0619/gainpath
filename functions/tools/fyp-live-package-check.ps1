$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$taskRepo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$taskOut=Join-Path $taskRepo 'build/fyp-live-20261104'
function Get-ArchiveInventory([string]$Archive){
 $taskEntries=@{};$taskZip=[IO.Compression.ZipFile]::OpenRead($Archive)
 try{foreach($taskEntry in $taskZip.Entries){if($taskEntry.FullName.EndsWith('/')){continue};$taskStream=$taskEntry.Open();try{$taskSha=[Security.Cryptography.SHA256]::Create();$taskDigest=([BitConverter]::ToString($taskSha.ComputeHash($taskStream))).Replace('-','').ToLowerInvariant();$taskEntries[$taskEntry.FullName]=$taskDigest}finally{$taskStream.Dispose()}}}finally{$taskZip.Dispose()};return $taskEntries
}
$taskBefore=Get-ArchiveInventory (Join-Path $taskOut 'provisionMemberRegistration-before.zip')
$taskAfter=Get-ArchiveInventory (Join-Path $taskOut 'registration-ready.zip')
if($taskBefore.Count -ne $taskAfter.Count){throw 'Registration package file count changed'}
$taskChanged=@();foreach($taskName in $taskBefore.Keys){if(-not $taskAfter.ContainsKey($taskName)){throw 'Registration package path changed'};if($taskBefore[$taskName] -ne $taskAfter[$taskName]){$taskChanged+=$taskName}}
if(($taskChanged|Sort-Object) -join ',' -ne 'lib/modules/identity/member-provisioning.js,src/modules/identity/member-provisioning.ts'){throw 'Unexpected registration package changes'}
# Prove both changed files become the exact previous source after removing just the guard.
$taskZip=[IO.Compression.ZipFile]::OpenRead((Join-Path $taskOut 'provisionMemberRegistration-before.zip'))
try{foreach($taskName in $taskChanged){$taskReader=New-Object IO.StreamReader($taskZip.GetEntry($taskName).Open());try{$taskOriginal=$taskReader.ReadToEnd()}finally{$taskReader.Dispose()};$taskCurrent=[IO.File]::ReadAllText((Join-Path (Join-Path $taskOut 'registration-ready') $taskName));$taskStripped=[regex]::Replace($taskCurrent,'(?m)^\s*// Server-owned assignment includes disabled reservations/tombstones\.\r?\n[ \t]*if \(await transaction\.get\(`datasetAssignments/\$\{input\.userId\}`\)\) \{\r?\n[ \t]*throw new (errors_1\.)?DomainError\(''permission-denied'', ''This account requires its assigned dataset session\.''\);\r?\n[ \t]*\}\r?\n','');if($taskStripped -cne $taskOriginal){throw 'Registration patch exceeds the assignment guard'}}}finally{$taskZip.Dispose()}
$taskRules=[IO.File]::ReadAllText((Join-Path $taskOut 'firestore-additive.rules'))
$taskBaseline=[IO.File]::ReadAllText((Join-Path $taskOut 'firestore-before.rules'))
$taskStart=$taskRules.IndexOf("`n    // FYP cohort:");$taskEnd=$taskRules.LastIndexOf("`n  }`n}")
if($taskStart -lt 0 -or $taskRules.Remove($taskStart,$taskEnd-$taskStart) -cne $taskBaseline){throw 'Rules change is not the exact additive overlay'}
$taskResult=[ordered]@{passed=$true;guardArchiveSha256=(Get-FileHash (Join-Path $taskOut 'registration-ready.zip')).Hash.ToLowerInvariant();fypArchiveSha256=(Get-FileHash (Join-Path $taskOut 'fyp-ready.zip')).Hash.ToLowerInvariant();rulesSha256=(Get-FileHash (Join-Path $taskOut 'firestore-additive.rules')).Hash.ToLowerInvariant();registrationChangedFiles=$taskChanged;otherRegistrationFilesUnchanged=($taskBefore.Count-2);baselineRulesOutsideOverlayUnchanged=$true;at=[DateTime]::UtcNow.ToString('o')}
$taskResult|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $taskOut 'package-review.json') -Encoding utf8
Write-Output 'Exact archive and additive Rules verification passed; no cloud mutation.'
