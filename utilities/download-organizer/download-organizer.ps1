#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Position = 0)]
  [ValidateSet('preview', 'apply', 'undo', 'path')]
  [string]$Command = 'preview',

  [string]$SourcePath,
  [string]$ManifestPath
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'src\DownloadOrganizer.psm1') -Force
$operationParameters = @{ WhatIf = $WhatIfPreference }
if ($PSBoundParameters.ContainsKey('Confirm')) {
  $operationParameters.Confirm = $PSBoundParameters['Confirm']
}

switch ($Command) {
  'preview' {
    Get-DownloadOrganizationPreview -SourcePath $SourcePath
  }

  'apply' {
    Invoke-DownloadOrganization -SourcePath $SourcePath -ManifestPath $ManifestPath @operationParameters
  }

  'undo' {
    Undo-DownloadOrganization -ManifestPath $ManifestPath @operationParameters
  }

  'path' {
    Get-DownloadOrganizerManifestPath -ManifestPath $ManifestPath
  }
}
