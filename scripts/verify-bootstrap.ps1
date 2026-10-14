#Requires -Version 5.1
[CmdletBinding()]
param(
  [ValidateSet('CurrentUser', 'AllUsers')]
  [string]$Scope = 'CurrentUser',
  [switch]$RequireInstallation
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DevelopmentDependencies.psm1') -Force -ErrorAction Stop

function Test-BootstrapResult {
  [CmdletBinding()]
  param([object[]]$Results, [string]$ExpectedSource)
  $expected = @{ Pester = '5.7.1'; PSScriptAnalyzer = '1.24.0' }
  if ($Results.Count -ne 2) { throw 'O bootstrap nao retornou as duas dependencias.' }
  $root = Get-DevelopmentModuleRoot -Scope $Scope
  $seen = @{}
  foreach ($item in $Results) {
    if (-not $expected.ContainsKey($item.Name) -or $seen.ContainsKey($item.Name) -or
      $item.Version -ne $expected[$item.Name] -or $item.Scope -ne $Scope -or
      $item.Source -notin @('installed', 'existing')) { throw 'Resultado do bootstrap invalido.' }
    $seen[$item.Name] = $true
    if ($ExpectedSource -and $item.Source -ne $ExpectedSource) { throw "Esperado Source=$ExpectedSource para $($item.Name)." }
    $expectedBase = Join-Path (Join-Path $root $item.Name) $item.Version
    if (-not [string]::Equals([IO.Path]::GetFullPath($item.ModuleBase).TrimEnd('\'),
      [IO.Path]::GetFullPath($expectedBase).TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
      throw "Destino incorreto para $($item.Name): $($item.ModuleBase)."
    }
    $manifest = Join-Path $item.ModuleBase ($item.Name + '.psd1')
    $imported = @(Import-Module -Name $manifest -Force -PassThru -ErrorAction Stop)
    if ($imported.Count -ne 1 -or $imported[0].Name -ne $item.Name -or
      $imported[0].Version.ToString() -ne $item.Version -or
      -not [string]::Equals($imported[0].ModuleBase, $item.ModuleBase, [StringComparison]::OrdinalIgnoreCase)) {
      throw "Nao foi possivel importar a dependencia esperada: $($item.Name)."
    }
  }
}

function Get-GalleryTrustSnapshot {
  [CmdletBinding()]
  param()
  $previousProtocol = [Net.ServicePointManager]::SecurityProtocol
  try {
    # Stock PowerShellGet may contact the Gallery while initializing its repository store.
    # Restore the initial protocol before bootstrap so first-use still exercises its own preparation.
    if ($PSVersionTable.PSEdition -eq 'Desktop') {
      [Net.ServicePointManager]::SecurityProtocol = $previousProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    if (Get-Command Get-PSResourceRepository -ErrorAction SilentlyContinue) {
      $repository = Get-PSResourceRepository -Name PSGallery -ErrorAction Stop
      "PSResourceGet|$($repository.Uri)|$($repository.Trusted)"
    }
    if (Get-Command Get-PSRepository -ErrorAction SilentlyContinue) {
      $repository = Get-PSRepository -Name PSGallery -ErrorAction Stop
      "PowerShellGet|$($repository.SourceLocation)|$($repository.InstallationPolicy)"
    }
  } finally { [Net.ServicePointManager]::SecurityProtocol = $previousProtocol }
}

# Initialize repository stores before taking a baseline. Their creation is not a trust change.
$before = @(Get-GalleryTrustSnapshot)
if ($before.Count -eq 0) { throw 'Nenhuma politica de confianca disponivel para verificar.' }
Write-Output "PSGallery antes: $($before -join '; ')"
try {
  $results = @(& (Join-Path $PSScriptRoot 'bootstrap-dev.ps1') -Scope $Scope -PassThru)
  $expectedSource = if ($RequireInstallation) { 'installed' } else { '' }
  Test-BootstrapResult -Results $results -ExpectedSource $expectedSource
  $reused = @(& (Join-Path $PSScriptRoot 'bootstrap-dev.ps1') -Scope $Scope -PassThru)
  Test-BootstrapResult -Results $reused -ExpectedSource existing
} finally {
  $after = @(Get-GalleryTrustSnapshot)
  Write-Output "PSGallery depois: $($after -join '; ')"
  if (($before -join [Environment]::NewLine) -cne ($after -join [Environment]::NewLine)) {
    throw 'O bootstrap alterou a confianca ou o endereco registrado do PSGallery.'
  }
}
$results | Format-Table -AutoSize | Out-String | Write-Output
Write-Output "BOOTSTRAP_OK ($Scope; confianca do PSGallery preservada; importacao e reutilizacao verificadas)"
