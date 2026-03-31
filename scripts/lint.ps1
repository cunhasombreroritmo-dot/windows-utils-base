[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$settingsPath = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'
$lintPaths = @(
  (Join-Path $repoRoot 'scripts'),
  (Join-Path $repoRoot 'utilities')
)

Import-Module PSScriptAnalyzer -MinimumVersion 1.21.0 -ErrorAction Stop

$issues = @(
  foreach ($path in $lintPaths) {
    Invoke-ScriptAnalyzer -Path $path -Settings $settingsPath -Recurse
  }
)

if ($issues.Count -gt 0) {
  $issues |
    Select-Object ScriptName, Line, RuleName, Message |
    Format-Table -AutoSize |
    Out-String |
    Write-Output

  throw "PSScriptAnalyzer encontrou $($issues.Count) problema(s)."
}

Write-Output 'PSSCRIPTANALYZER_OK'
