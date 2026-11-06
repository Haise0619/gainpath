param([Parameter(Mandatory=$true)][ValidatePattern('^demo-m13-(admin|member-(0[1-9]|1[0-8])|coach-0[1-8])$')][string]$Uid,[switch]$CopyPassword)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Security
$taskVault=Join-Path $env:LOCALAPPDATA 'GainPath/FypDemo/fyp-v1.credential-vault.dpapi'
if((Get-Item -LiteralPath $taskVault).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Vault reparse point refused'}
$taskBytes=[Convert]::FromBase64String([IO.File]::ReadAllText($taskVault))
$taskPlain=[Security.Cryptography.ProtectedData]::Unprotect($taskBytes,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$taskState=[Text.Encoding]::UTF8.GetString($taskPlain)|ConvertFrom-Json
if($taskState.manifestSha256 -ne '8af85d9a07470fe2230f7fc42371d5a64618eca829fee70be1d22b2de247e855'){throw 'Vault manifest mismatch'}
$taskEntry=$taskState.entries.PSObject.Properties[$Uid].Value
if(-not $taskEntry){throw 'Unknown approved fictional identity'}
if($CopyPassword){Set-Clipboard -Value $taskEntry.password;Write-Output "Password copied for $Uid. Paste into the ordinary GainPath login, then clear your clipboard."}
else{[PSCredential]::new($taskEntry.email,(ConvertTo-SecureString $taskEntry.password -AsPlainText -Force))}
[Array]::Clear($taskPlain,0,$taskPlain.Length)
