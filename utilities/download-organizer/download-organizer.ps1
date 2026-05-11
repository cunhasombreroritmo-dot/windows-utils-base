[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet('preview', 'apply', 'undo', 'path')]
  [string]$Command = 'preview',

  [string]$SourcePath,
  [string]$ManifestPath
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'src\DownloadOrganizer.psm1') -Force

switch ($Command) {
  'preview' {
    Get-DownloadOrganizationPreview -SourcePath $SourcePath
  }

  'apply' {
    $result = Invoke-DownloadOrganization -SourcePath $SourcePath -ManifestPath $ManifestPath
    [pscustomobject]@{
      Action = $result.Action
      SourcePath = $result.SourcePath
      ManifestPath = $result.ManifestPath
      Count = $result.Count
    }
  }

  'undo' {
    $result = Undo-DownloadOrganization -ManifestPath $ManifestPath
    [pscustomobject]@{
      Action = $result.Action
      SourcePath = $result.SourcePath
      ManifestPath = $result.ManifestPath
      Count = $result.Count
    }
  }

  'path' {
    Get-DownloadOrganizerManifestPath -ManifestPath $ManifestPath
  }
}
