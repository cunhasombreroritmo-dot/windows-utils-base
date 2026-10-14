#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Get-GalleryTrustSnapshot {
  [CmdletBinding()]
  param()
  if (Get-Command Get-PSResourceRepository -ErrorAction SilentlyContinue) {
    $repository = Get-PSResourceRepository -Name PSGallery -ErrorAction Stop
    "PSResourceGet|$($repository.Uri)|$($repository.Trusted)"
  }
  if (Get-Command Get-PSRepository -ErrorAction SilentlyContinue) {
    $repository = Get-PSRepository -Name PSGallery -ErrorAction Stop
    "PowerShellGet|$($repository.SourceLocation)|$($repository.InstallationPolicy)"
  }
}

# Initialize repository stores before taking a baseline. Their creation is not a trust change.
$before = @(Get-GalleryTrustSnapshot)
if ($before.Count -eq 0) { throw 'Nenhuma politica de confianca disponivel para verificar.' }
Write-Output "PSGallery antes: $($before -join '; ')"
try {
  $results = @(& (Join-Path $PSScriptRoot 'bootstrap-dev.ps1') -Scope CurrentUser -PassThru)
} finally {
  $after = @(Get-GalleryTrustSnapshot)
  Write-Output "PSGallery depois: $($after -join '; ')"
  if (($before -join [Environment]::NewLine) -cne ($after -join [Environment]::NewLine)) {
    throw 'O bootstrap alterou a confianca ou o endereco registrado do PSGallery.'
  }
}
if ($results.Count -ne 2) { throw 'O bootstrap nao retornou as duas dependencias.' }
$results | Format-Table -AutoSize | Out-String | Write-Output
Write-Output 'BOOTSTRAP_OK (CurrentUser; confianca do PSGallery preservada)'
