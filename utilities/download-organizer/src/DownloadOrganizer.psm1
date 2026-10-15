#Requires -Version 5.1
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

function ConvertTo-DownloadFileSystemPath {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][string]$Path)

  $provider = $null
  $drive = $null
  $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path, [ref]$provider, [ref]$drive)
  if ($provider.Name -ne 'FileSystem') {
    throw 'O caminho precisa pertencer ao sistema de arquivos.'
  }
  $fullPath = [IO.Path]::GetFullPath($resolved)
  if ($fullPath.Length -gt [IO.Path]::GetPathRoot($fullPath).Length) {
    $fullPath = $fullPath.TrimEnd('\', '/')
  }
  return $fullPath
}

function Assert-DownloadRegularPath {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][string]$Path)

  # Reject junctions/symlinks, including ancestors, before reading or moving files.
  $current = $Path
  while ($current) {
    if (Test-Path -LiteralPath $current -ErrorAction Stop) {
      $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
      if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Links e reparse points nao sao suportados: $current"
      }
    }
    $parent = Split-Path -Parent $current
    if ($parent -eq $current) { break }
    $current = $parent
  }
}

function Get-DownloadOrganizerManifestPath {
  [CmdletBinding()]
  param([string]$ManifestPath)

  if (-not $ManifestPath) {
    $basePath = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $HOME 'AppData\Local' }
    $ManifestPath = Join-Path $basePath 'WindowsUtilsBase\download-organizer\last-run.json'
  }
  return ConvertTo-DownloadFileSystemPath -Path $ManifestPath
}

function Initialize-DownloadOrganizerDirectory {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][string]$Path)

  $parent = Split-Path -Parent $Path
  Assert-DownloadRegularPath -Path $Path
  $null = [IO.Directory]::CreateDirectory($parent)
}

function Resolve-DownloadSourcePath {
  [CmdletBinding()]
  param([string]$SourcePath)

  if (-not $SourcePath) { $SourcePath = Get-DefaultDownloadsPath }
  $resolvedPath = ConvertTo-DownloadFileSystemPath -Path $SourcePath
  if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container -ErrorAction Stop)) {
    throw "A origem precisa ser uma pasta existente: $resolvedPath"
  }
  Assert-DownloadRegularPath -Path $resolvedPath
  return (Resolve-Path -LiteralPath $resolvedPath -ErrorAction Stop).ProviderPath
}

function Get-DownloadCategoryForExtension {
  [CmdletBinding()]
  param([string]$Extension)

  $normalized = if ($Extension) { $Extension.ToLowerInvariant() } else { '' }
  if ($script:DownloadCategoryMap.ContainsKey($normalized)) { return $script:DownloadCategoryMap[$normalized] }
  return 'Other'
}

function Get-UniqueTargetPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [System.Collections.Generic.HashSet[string]]$ReservedPaths
  )

  $directory = Split-Path -Parent $Path
  $extension = [IO.Path]::GetExtension($Path)
  $stem = [IO.Path]::GetFileNameWithoutExtension($Path)
  $candidate = $Path
  $index = 0
  while ((Test-Path -LiteralPath $candidate -ErrorAction Stop) -or
    ($null -ne $ReservedPaths -and $ReservedPaths.Contains($candidate))) {
    $index += 1
    $candidate = Join-Path $directory ('{0} ({1}){2}' -f $stem, $index, $extension)
  }
  if ($null -ne $ReservedPaths) { $null = $ReservedPaths.Add($candidate) }
  return $candidate
}

function Get-DownloadOrganizationPreview {
  [CmdletBinding()]
  param([string]$SourcePath)

  $root = Resolve-DownloadSourcePath -SourcePath $SourcePath
  $reserved = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $files = Get-ChildItem -LiteralPath $root -File -ErrorAction Stop | Sort-Object Name
  foreach ($file in $files) {
    Assert-DownloadRegularPath -Path $file.FullName
    $category = Get-DownloadCategoryForExtension -Extension $file.Extension
    $categoryPath = Join-Path $root $category
    Assert-DownloadRegularPath -Path $categoryPath
    if ((Test-Path -LiteralPath $categoryPath -ErrorAction Stop) -and
      -not (Test-Path -LiteralPath $categoryPath -PathType Container -ErrorAction Stop)) {
      throw "Uma categoria esta ocupada por um arquivo: $categoryPath"
    }
    $target = Get-UniqueTargetPath -Path (Join-Path $categoryPath $file.Name) -ReservedPaths $reserved
    [pscustomobject]@{
      Name = $file.Name
      Extension = $file.Extension
      Category = $category
      SourcePath = $file.FullName
      TargetPath = $target
    }
  }
}

function Get-DownloadFileFingerprint {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][string]$Path)

  Assert-DownloadRegularPath -Path $Path
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  if ($item.PSIsContainer) { throw "Esperava um arquivo: $Path" }
  return [pscustomobject]@{
    Length = $item.Length
    Hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
  }
}

function Test-DownloadFileFingerprint {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][pscustomobject]$Entry
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf -ErrorAction Stop)) { return $false }
  $actual = Get-DownloadFileFingerprint -Path $Path
  return $actual.Length -eq $Entry.Length -and $actual.Hash -eq $Entry.Hash
}

function Enter-DownloadManifestLock {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][string]$ManifestPath)

  Initialize-DownloadOrganizerDirectory -Path $ManifestPath
  $lockPath = $ManifestPath + '.lock'
  Assert-DownloadRegularPath -Path $lockPath
  try {
    return [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
  } catch {
    throw "Nao foi possivel bloquear o manifesto; outra execucao pode estar ativa: $ManifestPath. $($_.Exception.Message)"
  }
}

function Write-DownloadManifest {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][pscustomobject]$Manifest,
    [string]$ManifestPath
  )

  $ErrorActionPreference = 'Stop'
  $path = Get-DownloadOrganizerManifestPath -ManifestPath $ManifestPath
  Initialize-DownloadOrganizerDirectory -Path $path
  $temporaryPath = $path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
  $stream = $null
  try {
    $json = $Manifest | ConvertTo-Json -Depth 8 -ErrorAction Stop
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
    $stream = [IO.File]::Open($temporaryPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush($true)
    $stream.Dispose()
    $stream = $null
    if ([IO.File]::Exists($path)) {
      [IO.File]::Replace($temporaryPath, $path, [System.Management.Automation.Language.NullString]::Value)
    } else {
      [IO.File]::Move($temporaryPath, $path)
    }
  } finally {
    if ($null -ne $stream) { $stream.Dispose() }
    if ([IO.File]::Exists($temporaryPath)) { [IO.File]::Delete($temporaryPath) }
  }
  return $path
}

function Assert-DownloadManifest {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][pscustomobject]$Manifest)

  $required = @('SchemaVersion', 'RunId', 'SourcePath', 'Status', 'Entries', 'UpdatedAt', 'FailedAt', 'FailureMessage', 'UndoCompletedAt')
  foreach ($property in $required) {
    if ($null -eq $Manifest.PSObject.Properties[$property]) {
      throw 'Manifesto antigo ou invalido. A reversao requer um manifesto versao 2 com fingerprints.'
    }
  }
  if ($Manifest.SchemaVersion -ne 2 -or $Manifest.RunId -notmatch '^[a-f0-9]{32}$' -or
    $Manifest.Status -notin @('planned', 'in-progress', 'partial', 'applied', 'undo-partial', 'undone')) {
    throw 'Versao, identificador ou status do manifesto invalido.'
  }
  $root = ConvertTo-DownloadFileSystemPath -Path $Manifest.SourcePath
  if (-not [IO.Path]::IsPathRooted($Manifest.SourcePath) -or $root -ne $Manifest.SourcePath -or $null -eq $Manifest.Entries) {
    throw 'Origem ou entradas do manifesto invalidas.'
  }
  Assert-DownloadRegularPath -Path $root
  $sources = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $targets = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($entry in $Manifest.Entries) {
    foreach ($property in @('Name', 'Category', 'SourcePath', 'TargetPath', 'State', 'Length', 'Hash', 'RestorePath', 'RestoredAt')) {
      if ($null -eq $entry -or $null -eq $entry.PSObject.Properties[$property]) { throw 'Entrada incompleta no manifesto.' }
    }
    if ($entry.State -notin @('pending', 'moving', 'moved', 'restoring', 'restored') -or
      $entry.Hash -notmatch '^[a-fA-F0-9]{64}$' -or $entry.Length -isnot [ValueType] -or $entry.Length -lt 0 -or
      $entry.Category -notin @('Archives', 'Audio', 'Code', 'Documents', 'Images', 'Installers', 'Other', 'Video')) {
      throw 'Estado, fingerprint ou categoria invalida no manifesto.'
    }
    $source = ConvertTo-DownloadFileSystemPath -Path $entry.SourcePath
    $target = ConvertTo-DownloadFileSystemPath -Path $entry.TargetPath
    if ($source -ne $entry.SourcePath -or $target -ne $entry.TargetPath -or
      (Split-Path -Parent $source) -ne $root -or [IO.Path]::GetFileName($source) -ne $entry.Name -or
      (Split-Path -Parent $target) -ne (Join-Path $root $entry.Category) -or
      -not $sources.Add($source) -or -not $targets.Add($target)) {
      throw 'Caminhos duplicados ou fora da origem no manifesto.'
    }
    Assert-DownloadRegularPath -Path $source
    Assert-DownloadRegularPath -Path $target
    if ($entry.RestorePath) {
      $restore = ConvertTo-DownloadFileSystemPath -Path $entry.RestorePath
      if ($restore -ne $entry.RestorePath -or (Split-Path -Parent $restore) -ne $root) {
        throw 'Caminho de restauracao fora da origem.'
      }
      Assert-DownloadRegularPath -Path $restore
    } elseif ($entry.State -in @('restoring', 'restored')) {
      throw 'Entrada restaurada sem caminho de restauracao.'
    }
  }
}

function Read-DownloadManifest {
  [CmdletBinding()]
  param([string]$ManifestPath)

  $path = Get-DownloadOrganizerManifestPath -ManifestPath $ManifestPath
  Assert-DownloadRegularPath -Path $path
  if (-not (Test-Path -LiteralPath $path -PathType Leaf -ErrorAction Stop)) { throw "Manifesto nao encontrado em $path" }
  $manifest = Get-Content -LiteralPath $path -Encoding UTF8 -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
  if ($null -eq $manifest -or $manifest -is [array]) { throw 'Manifesto vazio ou invalido.' }
  Assert-DownloadManifest -Manifest $manifest
  return $manifest
}

function New-DownloadManifest {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.IEnumerable]$Preview,
    [Parameter(Mandatory = $true)][string]$SourcePath
  )

  $timestamp = [DateTimeOffset]::Now.ToString('o')
  return [pscustomobject]@{
    SchemaVersion = 2
    RunId = [guid]::NewGuid().ToString('N')
    CreatedAt = $timestamp
    UpdatedAt = $timestamp
    CompletedAt = $null
    FailedAt = $null
    FailureMessage = $null
    UndoCompletedAt = $null
    Status = 'planned'
    SourcePath = $SourcePath
    Entries = @(
      foreach ($entry in $Preview) {
        $fingerprint = Get-DownloadFileFingerprint -Path $entry.SourcePath
        [pscustomobject]@{
          Name = $entry.Name
          Category = $entry.Category
          SourcePath = $entry.SourcePath
          TargetPath = $entry.TargetPath
          Length = $fingerprint.Length
          Hash = $fingerprint.Hash
          State = 'pending'
          MovedAt = $null
          RestorePath = $null
          RestoredAt = $null
        }
      }
    )
  }
}

function Move-DownloadFile {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$SourcePath,
    [Parameter(Mandatory = $true)][string]$TargetPath
  )

  Assert-DownloadRegularPath -Path $SourcePath
  Assert-DownloadRegularPath -Path $TargetPath
  # File.Move treats paths literally, never overwrites, and throws on failure.
  [IO.File]::Move($SourcePath, $TargetPath)
}

function Assert-DownloadManifestLocation {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][string]$SourcePath
  )

  $prefix = $SourcePath.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  if ($ManifestPath -eq $SourcePath -or $ManifestPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'O manifesto precisa ficar fora da pasta de origem.'
  }
  Assert-DownloadRegularPath -Path $ManifestPath
}

function Invoke-DownloadOrganization {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param([string]$SourcePath, [string]$ManifestPath)

  $ErrorActionPreference = 'Stop'
  $root = Resolve-DownloadSourcePath -SourcePath $SourcePath
  $path = Get-DownloadOrganizerManifestPath -ManifestPath $ManifestPath
  Assert-DownloadManifestLocation -ManifestPath $path -SourcePath $root
  $preview = @(Get-DownloadOrganizationPreview -SourcePath $root)
  if ($preview.Count -eq 0) {
    return [pscustomobject]@{ Action = 'unchanged'; SourcePath = $root; ManifestPath = $path; Count = 0 }
  }
  if (-not $PSCmdlet.ShouldProcess($root, 'Organizar arquivos e gravar manifesto')) { return }

  $lock = Enter-DownloadManifestLock -ManifestPath $path
  try {
    # Rebuild under the lock; another cooperating process may have organized first.
    $preview = @(Get-DownloadOrganizationPreview -SourcePath $root)
    if ($preview.Count -eq 0) {
      return [pscustomobject]@{ Action = 'unchanged'; SourcePath = $root; ManifestPath = $path; Count = 0 }
    }
    $manifest = New-DownloadManifest -Preview $preview -SourcePath $root
    Assert-DownloadManifest -Manifest $manifest
    if (Test-Path -LiteralPath $path -ErrorAction Stop) {
      # Preserve every prior run, including partial and legacy manifests.
      $archivePath = $path + '.' + [guid]::NewGuid().ToString('N') + '.bak'
      [IO.File]::Copy($path, $archivePath, $false)
    }
    $null = Write-DownloadManifest -Manifest $manifest -ManifestPath $path
    try {
      foreach ($entry in $manifest.Entries) {
        if (-not (Test-DownloadFileFingerprint -Path $entry.SourcePath -Entry $entry)) {
          throw "O arquivo mudou desde o planejamento: $($entry.SourcePath)"
        }
        $targetDirectory = Split-Path -Parent $entry.TargetPath
        Assert-DownloadRegularPath -Path $targetDirectory
        $null = [IO.Directory]::CreateDirectory($targetDirectory)
        $entry.State = 'moving'
        $manifest.Status = 'in-progress'
        $manifest.UpdatedAt = [DateTimeOffset]::Now.ToString('o')
        $null = Write-DownloadManifest -Manifest $manifest -ManifestPath $path
        Move-DownloadFile -SourcePath $entry.SourcePath -TargetPath $entry.TargetPath -ErrorAction Stop
        if ((Test-Path -LiteralPath $entry.SourcePath -ErrorAction Stop) -or
          -not (Test-DownloadFileFingerprint -Path $entry.TargetPath -Entry $entry)) {
          throw "Movimento nao confirmado: $($entry.SourcePath)"
        }
        $entry.State = 'moved'
        $entry.MovedAt = [DateTimeOffset]::Now.ToString('o')
        $manifest.UpdatedAt = $entry.MovedAt
        $null = Write-DownloadManifest -Manifest $manifest -ManifestPath $path
      }
      $manifest.Status = 'applied'
      $manifest.CompletedAt = [DateTimeOffset]::Now.ToString('o')
      $manifest.UpdatedAt = $manifest.CompletedAt
      $null = Write-DownloadManifest -Manifest $manifest -ManifestPath $path
    } catch {
      $failure = $_
      $manifest.Status = 'partial'
      $manifest.FailedAt = [DateTimeOffset]::Now.ToString('o')
      $manifest.UpdatedAt = $manifest.FailedAt
      $manifest.FailureMessage = $failure.Exception.Message
      try { $null = Write-DownloadManifest -Manifest $manifest -ManifestPath $path } catch {
        Write-Warning "Falha ao atualizar manifesto; o ultimo checkpoint foi preservado: $($_.Exception.Message)"
      }
      throw $failure
    }
    return [pscustomobject]@{ Action = 'applied'; SourcePath = $root; ManifestPath = $path; Count = $preview.Count }
  } finally {
    $lock.Dispose()
  }
}

function Undo-DownloadOrganization {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param([string]$ManifestPath)

  $ErrorActionPreference = 'Stop'
  $path = Get-DownloadOrganizerManifestPath -ManifestPath $ManifestPath
  $manifest = Read-DownloadManifest -ManifestPath $path
  Assert-DownloadManifestLocation -ManifestPath $path -SourcePath $manifest.SourcePath
  if (-not $PSCmdlet.ShouldProcess($manifest.SourcePath, 'Restaurar arquivos do manifesto')) { return }
  $lock = Enter-DownloadManifestLock -ManifestPath $path
  try {
    $manifest = Read-DownloadManifest -ManifestPath $path
    Assert-DownloadManifestLocation -ManifestPath $path -SourcePath $manifest.SourcePath
    $count = 0
    $skipped = @()
    try {
      foreach ($entry in $manifest.Entries) {
        if ($entry.State -in @('pending', 'restored')) { continue }
        if ($entry.State -eq 'restoring' -and
          -not (Test-Path -LiteralPath $entry.TargetPath -ErrorAction Stop) -and
          (Test-DownloadFileFingerprint -Path $entry.RestorePath -Entry $entry)) {
          # The previous process moved the file but failed to save its checkpoint.
          $entry.State = 'restored'
          $entry.RestoredAt = [DateTimeOffset]::Now.ToString('o')
          $manifest.UpdatedAt = $entry.RestoredAt
          $null = Write-DownloadManifest -Manifest $manifest -ManifestPath $path
          continue
        }
        if ($entry.State -eq 'moving' -and (Test-Path -LiteralPath $entry.SourcePath -ErrorAction Stop)) {
          if (-not (Test-Path -LiteralPath $entry.TargetPath -ErrorAction Stop) -and
            (Test-DownloadFileFingerprint -Path $entry.SourcePath -Entry $entry)) {
            $entry.State = 'pending'
            continue
          }
          # Ambiguous move: never guess ownership of a target while source exists.
          $skipped += [pscustomobject]@{ Path = $entry.TargetPath; Reason = 'Movimento nao confirmado; origem ainda existe.' }
          continue
        }
        if ($entry.State -eq 'restoring' -and (Test-Path -LiteralPath $entry.RestorePath -ErrorAction Stop)) {
          $skipped += [pscustomobject]@{ Path = $entry.TargetPath; Reason = 'Restauracao ambigua; caminho de restauracao ocupado.' }
          continue
        }
        if (-not (Test-DownloadFileFingerprint -Path $entry.TargetPath -Entry $entry)) {
          $skipped += [pscustomobject]@{ Path = $entry.TargetPath; Reason = 'Arquivo ausente ou conteudo alterado.' }
          continue
        }
        $restoreDirectory = Split-Path -Parent $entry.SourcePath
        Assert-DownloadRegularPath -Path $restoreDirectory
        $null = [IO.Directory]::CreateDirectory($restoreDirectory)
        $entry.RestorePath = Get-UniqueTargetPath -Path $entry.SourcePath
        $entry.State = 'restoring'
        $manifest.UpdatedAt = [DateTimeOffset]::Now.ToString('o')
        $null = Write-DownloadManifest -Manifest $manifest -ManifestPath $path
        Move-DownloadFile -SourcePath $entry.TargetPath -TargetPath $entry.RestorePath -ErrorAction Stop
        if ((Test-Path -LiteralPath $entry.TargetPath -ErrorAction Stop) -or
          -not (Test-DownloadFileFingerprint -Path $entry.RestorePath -Entry $entry)) {
          throw "Restauracao nao confirmada: $($entry.TargetPath)"
        }
        $count += 1
        $entry.State = 'restored'
        $entry.RestoredAt = [DateTimeOffset]::Now.ToString('o')
        $manifest.UpdatedAt = $entry.RestoredAt
        $null = Write-DownloadManifest -Manifest $manifest -ManifestPath $path
      }
      $manifest.Status = if ($skipped.Count -gt 0) { 'undo-partial' } else { 'undone' }
      $manifest.UpdatedAt = [DateTimeOffset]::Now.ToString('o')
      $manifest.UndoCompletedAt = if ($skipped.Count -eq 0) { $manifest.UpdatedAt } else { $null }
      $manifest.FailureMessage = $null
      $null = Write-DownloadManifest -Manifest $manifest -ManifestPath $path
    } catch {
      $failure = $_
      $manifest.Status = 'undo-partial'
      $manifest.FailedAt = [DateTimeOffset]::Now.ToString('o')
      $manifest.UpdatedAt = $manifest.FailedAt
      $manifest.FailureMessage = $failure.Exception.Message
      try { $null = Write-DownloadManifest -Manifest $manifest -ManifestPath $path } catch {
        Write-Warning "Falha ao atualizar manifesto; o ultimo checkpoint foi preservado: $($_.Exception.Message)"
      }
      throw $failure
    }
    return [pscustomobject]@{
      Action = $manifest.Status
      SourcePath = $manifest.SourcePath
      ManifestPath = $path
      Count = $count
      SkippedCount = $skipped.Count
      Skipped = @($skipped)
    }
  } finally {
    $lock.Dispose()
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
