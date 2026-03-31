Set-StrictMode -Version Latest

if (-not ([System.Management.Automation.PSTypeName]'WindowsUtilsBase.KnownFolders').Type) {
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace WindowsUtilsBase {
  public static class KnownFolders {
    [DllImport("shell32.dll")]
    private static extern int SHGetKnownFolderPath(
      [MarshalAs(UnmanagedType.LPStruct)] Guid rfid,
      uint dwFlags,
      IntPtr hToken,
      out IntPtr ppszPath);

    public static string GetPath(Guid folderId) {
      IntPtr pathPtr;
      int hr = SHGetKnownFolderPath(folderId, 0, IntPtr.Zero, out pathPtr);
      if (hr != 0) {
        Marshal.ThrowExceptionForHR(hr);
      }

      try {
        return Marshal.PtrToStringUni(pathPtr);
      } finally {
        if (pathPtr != IntPtr.Zero) {
          Marshal.FreeCoTaskMem(pathPtr);
        }
      }
    }
  }
}
"@
}

$script:DownloadCategoryMap = @{
  '.7z' = 'Archives'
  '.avi' = 'Video'
  '.bat' = 'Code'
  '.bmp' = 'Images'
  '.cmd' = 'Code'
  '.csv' = 'Documents'
  '.doc' = 'Documents'
  '.docx' = 'Documents'
  '.epub' = 'Documents'
  '.exe' = 'Installers'
  '.gif' = 'Images'
  '.gz' = 'Archives'
  '.heic' = 'Images'
  '.iso' = 'Installers'
  '.jpeg' = 'Images'
  '.jpg' = 'Images'
  '.js' = 'Code'
  '.json' = 'Code'
  '.m4a' = 'Audio'
  '.mkv' = 'Video'
  '.mov' = 'Video'
  '.mp3' = 'Audio'
  '.mp4' = 'Video'
  '.msi' = 'Installers'
  '.pdf' = 'Documents'
  '.png' = 'Images'
  '.ppt' = 'Documents'
  '.pptx' = 'Documents'
  '.ps1' = 'Code'
  '.py' = 'Code'
  '.rar' = 'Archives'
  '.tar' = 'Archives'
  '.txt' = 'Documents'
  '.wav' = 'Audio'
  '.webm' = 'Video'
  '.webp' = 'Images'
  '.xlsx' = 'Documents'
  '.xml' = 'Code'
  '.zip' = 'Archives'
}

function Get-DefaultDownloadsPath {
  [CmdletBinding()]
  param()

  $downloadsFolderId = [guid]'374DE290-123F-4565-9164-39C4925E467B'

  try {
    $knownFolderPath = [WindowsUtilsBase.KnownFolders]::GetPath($downloadsFolderId)
    if (-not [string]::IsNullOrWhiteSpace($knownFolderPath)) {
      return $knownFolderPath
    }
  } catch {
    Write-Verbose "Falha ao resolver a Known Folder de Downloads. Usando caminho padrao. $($_.Exception.Message)"
  }

  $userProfile = [Environment]::GetFolderPath('UserProfile')
  return Join-Path $userProfile 'Downloads'
}

function Get-DownloadOrganizerManifestPath {
  [CmdletBinding()]
  param(
    [string]$ManifestPath
  )

  if ($ManifestPath) {
    return $ManifestPath
  }

  $basePath = if ($env:LOCALAPPDATA) {
    $env:LOCALAPPDATA
  } else {
    Join-Path $HOME 'AppData\Local'
  }

  return Join-Path $basePath 'WindowsUtilsBase\download-organizer\last-run.json'
}

function Initialize-DownloadOrganizerDirectory {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $parent = Split-Path -Parent $Path
  if (-not (Test-Path $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
}

function Resolve-DownloadSourcePath {
  [CmdletBinding()]
  param(
    [string]$SourcePath
  )

  $resolvedPath = if ($SourcePath) {
    $SourcePath
  } else {
    Get-DefaultDownloadsPath
  }

  if (-not (Test-Path $resolvedPath)) {
    throw "A pasta de origem nao existe: $resolvedPath"
  }

  return (Resolve-Path $resolvedPath).Path
}

function Get-DownloadCategoryForExtension {
  [CmdletBinding()]
  param(
    [string]$Extension
  )

  $normalizedExtension = if ($Extension) { $Extension.ToLowerInvariant() } else { '' }
  if ($script:DownloadCategoryMap.ContainsKey($normalizedExtension)) {
    return $script:DownloadCategoryMap[$normalizedExtension]
  }

  return 'Other'
}

function Get-UniqueTargetPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if (-not (Test-Path $Path)) {
    return $Path
  }

  $directory = Split-Path -Parent $Path
  $extension = [IO.Path]::GetExtension($Path)
  $fileNameWithoutExtension = [IO.Path]::GetFileNameWithoutExtension($Path)

  $index = 1
  do {
    $candidateName = '{0} ({1}){2}' -f $fileNameWithoutExtension, $index, $extension
    $candidatePath = Join-Path $directory $candidateName
    $index += 1
  } while (Test-Path $candidatePath)

  return $candidatePath
}

function Get-DownloadOrganizationPreview {
  [CmdletBinding()]
  param(
    [string]$SourcePath
  )

  $resolvedSourcePath = Resolve-DownloadSourcePath -SourcePath $SourcePath
  $files = Get-ChildItem -LiteralPath $resolvedSourcePath -File | Sort-Object Name

  foreach ($file in $files) {
    $category = Get-DownloadCategoryForExtension -Extension $file.Extension
    $categoryPath = Join-Path $resolvedSourcePath $category
    $targetPath = Get-UniqueTargetPath -Path (Join-Path $categoryPath $file.Name)

    [pscustomobject]@{
      Name = $file.Name
      Extension = $file.Extension
      Category = $category
      SourcePath = $file.FullName
      TargetPath = $targetPath
    }
  }
}

function Write-DownloadManifest {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [pscustomobject]$Manifest,

    [string]$ManifestPath
  )

  $resolvedManifestPath = Get-DownloadOrganizerManifestPath -ManifestPath $ManifestPath
  Initialize-DownloadOrganizerDirectory -Path $resolvedManifestPath

  $Manifest |
    ConvertTo-Json -Depth 6 |
    Set-Content -LiteralPath $resolvedManifestPath

  return $resolvedManifestPath
}

function Read-DownloadManifest {
  [CmdletBinding()]
  param(
    [string]$ManifestPath
  )

  $resolvedManifestPath = Get-DownloadOrganizerManifestPath -ManifestPath $ManifestPath
  if (-not (Test-Path $resolvedManifestPath)) {
    throw "Manifesto nao encontrado em $resolvedManifestPath"
  }

  return Get-Content -LiteralPath $resolvedManifestPath -Raw | ConvertFrom-Json
}

function New-DownloadManifest {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [System.Collections.IEnumerable]$Preview,

    [Parameter(Mandatory = $true)]
    [string]$SourcePath
  )

  $timestamp = [DateTimeOffset]::Now.ToString('o')

  return [pscustomobject]@{
    CreatedAt = $timestamp
    UpdatedAt = $timestamp
    CompletedAt = $null
    FailedAt = $null
    FailureMessage = $null
    Status = 'planned'
    SourcePath = $SourcePath
    Entries = @(
      foreach ($entry in $Preview) {
        [pscustomobject]@{
          Name = $entry.Name
          Category = $entry.Category
          SourcePath = $entry.SourcePath
          TargetPath = $entry.TargetPath
          State = 'pending'
          MovedAt = $null
        }
      }
    )
  }
}

function Invoke-DownloadOrganization {
  [CmdletBinding()]
  param(
    [string]$SourcePath,
    [string]$ManifestPath
  )

  $resolvedSourcePath = Resolve-DownloadSourcePath -SourcePath $SourcePath
  $preview = @(Get-DownloadOrganizationPreview -SourcePath $resolvedSourcePath)

  $manifest = New-DownloadManifest -Preview $preview -SourcePath $resolvedSourcePath
  $resolvedManifestPath = Write-DownloadManifest -Manifest $manifest -ManifestPath $ManifestPath

  try {
    foreach ($entry in $manifest.Entries) {
      $targetDirectory = Split-Path -Parent $entry.TargetPath
      if (-not (Test-Path $targetDirectory)) {
        New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
      }

      Move-Item -LiteralPath $entry.SourcePath -Destination $entry.TargetPath
      $entry.State = 'moved'
      $entry.MovedAt = [DateTimeOffset]::Now.ToString('o')
      $manifest.Status = 'in-progress'
      $manifest.UpdatedAt = $entry.MovedAt
      $resolvedManifestPath = Write-DownloadManifest -Manifest $manifest -ManifestPath $ManifestPath
    }
  } catch {
    $manifest.Status = 'partial'
    $manifest.FailedAt = [DateTimeOffset]::Now.ToString('o')
    $manifest.UpdatedAt = $manifest.FailedAt
    $manifest.FailureMessage = $_.Exception.Message

    try {
      $resolvedManifestPath = Write-DownloadManifest -Manifest $manifest -ManifestPath $ManifestPath
    } catch {
      Write-Verbose "Falha ao atualizar o manifesto apos erro de organizacao. $($_.Exception.Message)"
    }

    throw
  }

  $manifest.Status = 'applied'
  $manifest.CompletedAt = [DateTimeOffset]::Now.ToString('o')
  $manifest.UpdatedAt = $manifest.CompletedAt
  $manifest.FailureMessage = $null
  $resolvedManifestPath = Write-DownloadManifest -Manifest $manifest -ManifestPath $ManifestPath

  return [pscustomobject]@{
    Action = 'applied'
    SourcePath = $resolvedSourcePath
    ManifestPath = $resolvedManifestPath
    Count = $preview.Count
  }
}

function Undo-DownloadOrganization {
  [CmdletBinding()]
  param(
    [string]$ManifestPath
  )

  $manifest = Read-DownloadManifest -ManifestPath $ManifestPath
  $entries = @($manifest.Entries)

  foreach ($entry in $entries) {
    if (-not (Test-Path $entry.TargetPath)) {
      continue
    }

    $restoreDirectory = Split-Path -Parent $entry.SourcePath
    if (-not (Test-Path $restoreDirectory)) {
      New-Item -ItemType Directory -Path $restoreDirectory -Force | Out-Null
    }

    $restorePath = Get-UniqueTargetPath -Path $entry.SourcePath
    Move-Item -LiteralPath $entry.TargetPath -Destination $restorePath
  }

  return [pscustomobject]@{
    Action = 'undone'
    SourcePath = $manifest.SourcePath
    ManifestPath = Get-DownloadOrganizerManifestPath -ManifestPath $ManifestPath
    Count = $entries.Count
  }
}

Export-ModuleMember -Function @(
  'Get-DefaultDownloadsPath',
  'Get-DownloadCategoryForExtension',
  'Get-DownloadOrganizationPreview',
  'Get-DownloadOrganizerManifestPath',
  'Invoke-DownloadOrganization',
  'New-DownloadManifest',
  'Read-DownloadManifest',
  'Undo-DownloadOrganization'
)
