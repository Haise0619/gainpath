param([Parameter(Mandatory=$true)][ValidateSet('demo-m13-admin','demo-m13-member-01')][string]$Uid,[switch]$CopyPassword)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Security
$taskVault=Join-Path $env:LOCALAPPDATA 'GainPath/Module13Presentation/login.dpapi'
if((Get-Item -LiteralPath $taskVault).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Vault reparse point refused'}
$taskEncrypted=[Convert]::FromBase64String([IO.File]::ReadAllText($taskVault))
$taskPlain=[Security.Cryptography.ProtectedData]::Unprotect($taskEncrypted,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
try {
  $taskState=[Text.Encoding]::UTF8.GetString($taskPlain)|ConvertFrom-Json
  if($taskState.projectId -ne 'gainpath-0619' -or $taskState.schemaVersion -ne 1){throw 'Fixed project mismatch'}
  $taskEntry=$taskState.entries.PSObject.Properties[$Uid].Value
  if(-not $taskEntry -or -not $taskEntry.resetComplete){throw 'Account reset not complete'}
  if($CopyPassword){Set-Clipboard -Value $taskEntry.password;Write-Output "Password copied for $Uid. Paste into GainPath login, then clear the clipboard."}
  else {[PSCredential]::new($taskEntry.email,(ConvertTo-SecureString $taskEntry.password -AsPlainText -Force))}
} finally {[Array]::Clear($taskPlain,0,$taskPlain.Length)}
