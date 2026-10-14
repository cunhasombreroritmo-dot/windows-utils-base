#Requires -Version 5.1
[CmdletBinding()]
param([switch]$FirstUse)

$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted' -or
  [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
  throw 'Preparacao permitida somente em runner descartavel hospedado pelo GitHub.'
}
$backupRoot = Join-Path $env:RUNNER_TEMP ('bootstrap-backup-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $backupRoot

function Move-CIArtifact {
  [CmdletBinding()]
  param([string]$Root, [string]$RelativePath)
  $rootPath = [IO.Path]::GetFullPath($Root).TrimEnd('\')
  $targetPath = [IO.Path]::GetFullPath((Join-Path $rootPath $RelativePath))
  if (-not $targetPath.StartsWith($rootPath + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Destino fora da pasta de preparacao.'
  }
  if (-not (Test-Path -LiteralPath $targetPath)) { return }
  $ancestor = Get-Item -LiteralPath $targetPath -Force
  while ($ancestor) {
    if ($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Preparacao recusa reparse points.' }
    $ancestor = $ancestor.Parent
  }
  # Preserve the runner's preinstalled copy instead of deleting it.
  Move-Item -LiteralPath $targetPath -Destination (Join-Path $backupRoot ([guid]::NewGuid().ToString('N'))) -ErrorAction Stop
  Write-Output "CI_BACKUP: $targetPath"
}

foreach ($base in @([Environment]::GetFolderPath('MyDocuments'), [Environment]::GetFolderPath('ProgramFiles'))) {
  foreach ($edition in @('PowerShell', 'WindowsPowerShell')) {
    $root = Join-Path (Join-Path $base $edition) 'Modules'
    Move-CIArtifact -Root $root -RelativePath 'Pester/5.7.1'
    Move-CIArtifact -Root $root -RelativePath 'PSScriptAnalyzer/1.24.0'
  }
}
if ($FirstUse) {
  foreach ($base in @($env:LOCALAPPDATA, [Environment]::GetFolderPath('ProgramFiles'), [Environment]::GetFolderPath('ProgramFilesX86'))) {
    $root = Join-Path $base 'PackageManagement/ProviderAssemblies'
    Move-CIArtifact -Root $root -RelativePath 'NuGet'
  }
}
