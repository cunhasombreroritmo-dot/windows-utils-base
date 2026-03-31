[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$testFiles = Get-ChildItem -Path (Join-Path $repoRoot 'utilities') -Filter '*.Tests.ps1' -Recurse |
  Select-Object -ExpandProperty FullName

if ($testFiles.Count -eq 0) {
  throw 'Nenhum teste Pester foi encontrado.'
}

Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop

$configuration = New-PesterConfiguration
$configuration.Run.Path = $testFiles
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'

$result = Invoke-Pester -Configuration $configuration

if ($result.FailedCount -gt 0) {
  throw "Pester encontrou $($result.FailedCount) falha(s)."
}

Write-Output "PESTER_OK ($($result.PassedCount) testes aprovados)"
