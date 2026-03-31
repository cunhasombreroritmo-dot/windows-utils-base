$ErrorActionPreference = 'Stop'

$utilityRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $utilityRoot 'src\DownloadOrganizer.psm1') -Force

$tempRoot = Join-Path $env:TEMP ("download-organizer-test-" + [guid]::NewGuid().ToString('N'))
$downloadsPath = Join-Path $tempRoot 'Downloads'
$manifestPath = Join-Path $tempRoot 'manifest.json'

try {
  $null = New-Item -ItemType Directory -Path $downloadsPath -Force

  Set-Content -LiteralPath (Join-Path $downloadsPath 'invoice.pdf') -Value 'pdf'
  Set-Content -LiteralPath (Join-Path $downloadsPath 'photo.jpg') -Value 'jpg'
  Set-Content -LiteralPath (Join-Path $downloadsPath 'archive.zip') -Value 'zip'
  Set-Content -LiteralPath (Join-Path $downloadsPath 'script.ps1') -Value 'ps1'
  Set-Content -LiteralPath (Join-Path $downloadsPath 'installer.msi') -Value 'msi'

  $preview = @(Get-DownloadOrganizationPreview -SourcePath $downloadsPath)
  if ($preview.Count -ne 5) {
    throw "Esperava 5 itens no preview, encontrei $($preview.Count)."
  }

  $categories = @($preview.Category | Sort-Object -Unique)
  $expected = @('Archives', 'Code', 'Documents', 'Images', 'Installers')
  if ((Compare-Object -ReferenceObject $expected -DifferenceObject $categories).Count -ne 0) {
    throw "Categorias inesperadas no preview: $($categories -join ', ')."
  }

  $apply = Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath
  if ($apply.Count -ne 5) {
    throw "Esperava 5 itens movidos, encontrei $($apply.Count)."
  }

  if (-not (Test-Path (Join-Path $downloadsPath 'Documents\invoice.pdf'))) {
    throw 'invoice.pdf nao foi movido para Documents.'
  }

  if (-not (Test-Path (Join-Path $downloadsPath 'Images\photo.jpg'))) {
    throw 'photo.jpg nao foi movido para Images.'
  }

  if (-not (Test-Path $manifestPath)) {
    throw 'Manifesto nao foi gravado.'
  }

  $undo = Undo-DownloadOrganization -ManifestPath $manifestPath
  if ($undo.Count -ne 5) {
    throw "Esperava 5 itens restaurados, encontrei $($undo.Count)."
  }

  if (-not (Test-Path (Join-Path $downloadsPath 'invoice.pdf'))) {
    throw 'invoice.pdf nao voltou para a raiz.'
  }

  if (-not (Test-Path (Join-Path $downloadsPath 'photo.jpg'))) {
    throw 'photo.jpg nao voltou para a raiz.'
  }

  Write-Output 'DOWNLOAD_ORGANIZER_SMOKE_OK'
} finally {
  if (Test-Path $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}
