#Requires -Version 5.1
[CmdletBinding()]
param(
  [ValidateSet('pwsh', 'powershell')]
  [string]$Engine
)

$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
  throw 'Criacao de consumidor permitida somente em runner descartavel hospedado.'
}
$name = 'boot-' + [guid]::NewGuid().ToString('N').Substring(0, 12)
$folder = Join-Path ([Environment]::GetFolderPath('CommonDocuments')) $name
$null = New-Item -ItemType Directory -Path $folder
$scriptPath = Join-Path $folder 'consumer.ps1'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'verify-allusers-consumer.ps1') -Destination $scriptPath
$password = [Security.SecureString]::new()
foreach ($character in ('aA1!' + [guid]::NewGuid().ToString('N')).ToCharArray()) { $password.AppendChar($character) }
$password.MakeReadOnly()
$userCreated = $false
try {
  $null = New-LocalUser -Name $name -Password $password -AccountNeverExpires
  $userCreated = $true
  $usersGroup = Get-LocalGroup -SID 'S-1-5-32-545'
  Add-LocalGroupMember -Group $usersGroup -Member $name
  $credential = [pscredential]::new("$env:COMPUTERNAME\$name", $password)
  $executable = (Get-Command $Engine -CommandType Application -ErrorAction Stop).Source
  $stdout = Join-Path $folder 'stdout.txt'
  $stderr = Join-Path $folder 'stderr.txt'
  $process = Start-Process -FilePath $executable -ArgumentList @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $scriptPath + '"')) -Credential $credential -LoadUserProfile -WindowStyle Hidden -WorkingDirectory $folder -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
  if (-not $process.WaitForExit(120000)) { $process.Kill(); throw 'Consumidor excedeu o tempo limite.' }
  $process.Refresh()
  $output = Get-Content -LiteralPath $stdout -Raw
  Write-Output $output
  if ($process.ExitCode -ne 0 -or $output -notmatch 'ALLUSERS_CONSUMER_OK') {
    Write-Output (Get-Content -LiteralPath $stderr -Raw)
    throw 'Falha na importacao por outro usuario comum.'
  }
} finally {
  if ($userCreated) { Remove-LocalUser -Name $name }
  $password.Dispose()
}
