#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
try {
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Consumidor deve ser um usuario comum.' }
} finally { $identity.Dispose() }
$edition = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'WindowsPowerShell' } else { 'PowerShell' }
$root = Join-Path (Join-Path ([Environment]::GetFolderPath('ProgramFiles')) $edition) 'Modules'
foreach ($dependency in @(@{ Name = 'Pester'; Version = '5.7.1' }, @{ Name = 'PSScriptAnalyzer'; Version = '1.24.0' })) {
  $module = Import-Module -Name $dependency.Name -RequiredVersion $dependency.Version -Force -PassThru -ErrorAction Stop
  $expected = Join-Path (Join-Path $root $dependency.Name) $dependency.Version
  if (-not [string]::Equals($module.ModuleBase, $expected, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Modulo resolvido fora de AllUsers: $($module.ModuleBase)."
  }
  Write-Output "CONSUMER_MODULE: $($module.Name) $($module.Version) $($module.ModuleBase)"
}
Write-Output 'ALLUSERS_CONSUMER_OK (usuario comum; importacao por nome)'
