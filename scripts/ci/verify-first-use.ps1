#Requires -Version 5.1
[CmdletBinding()]
param(
  [ValidateSet('CurrentUser', 'AllUsers')]
  [string]$Scope = 'CurrentUser'
)

$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted' -or
  $PSVersionTable.PSEdition -ne 'Desktop') { throw 'Este teste requer Windows PowerShell 5.1 em runner hospedado.' }

$moduleRoot = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'WindowsPowerShell/Modules'
$originalModulePath = $env:PSModulePath
$originalProtocol = [Net.ServicePointManager]::SecurityProtocol
try {
  # Hide prepared modern managers; import the original Windows components by exact path.
  $env:PSModulePath = Join-Path $PSHOME 'Modules'
  foreach ($name in @('PackageManagement', 'PowerShellGet')) {
    $manifest = Join-Path (Join-Path (Join-Path $moduleRoot $name) '1.0.0.1') ($name + '.psd1')
    Import-Module -Name $manifest -Force -ErrorAction Stop
    $loaded = Get-Module $name
    if ($loaded.Version -ne [version]'1.0.0.1') { throw "Componente inicial incorreto: $name." }
    Write-Output "FIRST_USE_MANAGER: $name $($loaded.Version)"
  }
  if (Get-Command Install-PSResource -ErrorAction SilentlyContinue) { throw 'PSResourceGet nao deve estar disponivel neste teste.' }
  if (@(Get-PackageProvider -ListAvailable | Where-Object Name -eq NuGet).Count -ne 0) {
    throw 'O teste requer NuGet realmente ausente antes do bootstrap.'
  }
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls11
  Write-Output 'FIRST_USE_INITIAL: NuGet ausente; TLS 1.2 desabilitado; dependencias limpas'
  & (Join-Path (Split-Path -Parent $PSScriptRoot) 'verify-bootstrap.ps1') -Scope $Scope -RequireInstallation
  if ([Net.ServicePointManager]::SecurityProtocol -ne [Net.SecurityProtocolType]::Tls11) { throw 'TLS da sessao nao foi restaurado.' }
  $provider = @(Get-PackageProvider -ListAvailable | Where-Object { $_.Name -eq 'NuGet' -and [version]$_.Version -ge [version]'2.8.5.201' })
  if ($provider.Count -eq 0) { throw 'NuGet nao foi preparado.' }
  $providerRoot = if ($Scope -eq 'CurrentUser') { $env:LOCALAPPDATA } else { [Environment]::GetFolderPath('ProgramFiles') }
  $providerRoot = [IO.Path]::GetFullPath((Join-Path $providerRoot 'PackageManagement/ProviderAssemblies'))
  foreach ($item in $provider) {
    if (-not $item.ProviderPath.StartsWith($providerRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
      throw "Provedor NuGet fora do escopo escolhido: $($item.ProviderPath)."
    }
    Write-Output "FIRST_USE_PROVIDER: $($item.Version) $($item.ProviderPath)"
  }
  Write-Output "FIRST_USE_OK ($Scope; componentes Windows 1.0.0.1; NuGet e TLS preparados)"
} finally {
  $env:PSModulePath = $originalModulePath
  [Net.ServicePointManager]::SecurityProtocol = $originalProtocol
}
