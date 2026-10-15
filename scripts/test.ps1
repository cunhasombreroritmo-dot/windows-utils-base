#Requires -Version 5.1
[CmdletBinding()]
param(
  [string[]]$Path,
  [string]$ResultPath
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$testFiles = @(
  if ($Path) {
    foreach ($testPath in $Path) {
      $item = Get-Item -LiteralPath $testPath -ErrorAction Stop
      if ($item.PSIsContainer) {
        Get-ChildItem -LiteralPath $item.FullName -Filter '*.Tests.ps1' -Recurse -File -ErrorAction Stop |
          Select-Object -ExpandProperty FullName
      } else {
        $item.FullName
      }
    }
  } else {
    foreach ($directory in @('utilities', 'scripts/tests')) {
      Get-ChildItem -LiteralPath (Join-Path $repoRoot $directory) -Filter '*.Tests.ps1' -Recurse -File -ErrorAction Stop |
        Select-Object -ExpandProperty FullName
    }
  }
)

if ($testFiles.Count -eq 0) {
  throw 'Nenhum teste Pester foi encontrado.'
}

Import-Module Pester -RequiredVersion 5.7.1 -ErrorAction Stop

$configuration = New-PesterConfiguration
$configuration.Run.Path = $testFiles
$configuration.Run.PassThru = $true
$configuration.Run.Throw = $true
$configuration.Output.Verbosity = 'Detailed'
if ($ResultPath) {
  $configuration.TestResult.Enabled = $true
  $configuration.TestResult.OutputPath = $ResultPath
  $configuration.TestResult.OutputFormat = 'NUnitXml'
}

$result = Invoke-Pester -Configuration $configuration

if ($result.Result -ne 'Passed' -or $result.PassedCount -eq 0 -or
  $result.SkippedCount -gt 0 -or $result.NotRunCount -gt 0 -or $result.InconclusiveCount -gt 0) {
  throw 'Pester requer testes aprovados, sem testes ignorados, inconclusivos ou nao executados.'
}

Write-Output "PESTER_OK ($($result.PassedCount) testes aprovados)"
