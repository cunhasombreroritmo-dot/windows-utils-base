#Requires -Version 5.1
[CmdletBinding()]
param(
  [ValidateSet('CurrentUser', 'AllUsers')]
  [string]$Scope = 'CurrentUser',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DevelopmentDependencies.psm1') -Force -ErrorAction Stop
$results = @(Initialize-DevelopmentEnvironment -Scope $Scope)
if ($PassThru) {
  $results
} else {
  $results | Format-Table Name, Version, Source, Scope, ModuleBase -AutoSize | Out-String | Write-Output
}
