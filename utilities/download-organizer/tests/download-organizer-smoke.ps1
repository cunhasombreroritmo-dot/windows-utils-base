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

  $manifest = Read-DownloadManifest -ManifestPath $manifestPath
  if ($manifest.Status -ne 'applied') {
    throw "Esperava manifesto com status 'applied', encontrei '$($manifest.Status)'."
  }

  if ((@($manifest.Entries | Where-Object { $_.State -eq 'moved' })).Count -ne 5) {
    throw 'Nem todos os itens foram registrados como movidos no manifesto.'
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

  $blockedDownloadsPath = Join-Path $tempRoot 'BlockedDownloads'
  $blockedManifestPath = Join-Path $tempRoot 'blocked-manifest'
  $null = New-Item -ItemType Directory -Path $blockedDownloadsPath -Force
  $null = New-Item -ItemType Directory -Path $blockedManifestPath -Force
  Set-Content -LiteralPath (Join-Path $blockedDownloadsPath 'keep.pdf') -Value 'pdf'

  try {
    Invoke-DownloadOrganization -SourcePath $blockedDownloadsPath -ManifestPath $blockedManifestPath | Out-Null
    throw 'Esperava falha ao gravar manifesto em um caminho que aponta para diretorio.'
  } catch {
    if (-not (Test-Path (Join-Path $blockedDownloadsPath 'keep.pdf'))) {
      throw 'O arquivo foi movido mesmo com falha na gravacao inicial do manifesto.'
    }

    if (Test-Path (Join-Path $blockedDownloadsPath 'Documents\keep.pdf')) {
      throw 'O arquivo nao deveria ter sido organizado quando o manifesto inicial falha.'
    }
  }

  Write-Output 'DOWNLOAD_ORGANIZER_SMOKE_OK'
} finally {
  if (Test-Path $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}
