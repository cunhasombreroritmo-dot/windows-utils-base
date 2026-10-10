BeforeAll {
  $utilityRoot = Split-Path -Parent $PSScriptRoot
  Import-Module (Join-Path $utilityRoot 'src/DownloadOrganizer.psm1') -Force
  $script:entryPoint = Join-Path $utilityRoot 'download-organizer.ps1'

  function New-TestDownload {
    param([string]$Name = 'report.pdf', [string]$Value = 'original')
    $path = Join-Path $downloadsPath $Name
    [IO.File]::WriteAllText($path, $Value, [Text.UTF8Encoding]::new($false))
    return $path
  }

  function Save-TestManifest {
    param($Manifest)
    [IO.File]::WriteAllText($manifestPath, ($Manifest | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
  }
}

Describe 'download-organizer safety and recovery' {
  BeforeEach {
    $caseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $downloadsPath = Join-Path $caseRoot 'Downloads [set]'
    $script:manifestPath = Join-Path $caseRoot 'manifest [run].json'
    $null = [IO.Directory]::CreateDirectory($downloadsPath)
  }

  It 'preserves the existing integration smoke test' {
    $output = & (Join-Path $PSScriptRoot 'download-organizer-smoke.ps1')
    @($output) | Should -Contain 'DOWNLOAD_ORGANIZER_SMOKE_OK'
  }

  It 'previews without creating folders, manifests, or moving files' {
    $source = New-TestDownload
    $preview = @(Get-DownloadOrganizationPreview -SourcePath $downloadsPath)
    $preview.Count | Should -Be 1
    $preview[0].Category | Should -Be 'Documents'
    Test-Path -LiteralPath $source | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $downloadsPath 'Documents') | Should -BeFalse
    Test-Path -LiteralPath $manifestPath | Should -BeFalse
  }

  It 'round trips literal brackets and Unicode names and preserves file contents' {
    $name = 'report [1] ' + [char]0x4E2D + [char]0x6587 + '.pdf'
    $source = New-TestDownload -Name $name -Value ('content ' + [char]0x4E2D)
    $hash = (Get-FileHash -LiteralPath $source).Hash
    (Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath).Count | Should -Be 1
    (Undo-DownloadOrganization -ManifestPath $manifestPath).Count | Should -Be 1
    (Get-FileHash -LiteralPath $source).Hash | Should -Be $hash
    (Read-DownloadManifest -ManifestPath $manifestPath).Entries[0].State | Should -Be 'restored'
  }

  It 'ignores subdirectory contents' {
    $nested = Join-Path $downloadsPath 'nested'
    $null = [IO.Directory]::CreateDirectory($nested)
    [IO.File]::WriteAllText((Join-Path $nested 'keep.pdf'), 'keep')
    @(Get-DownloadOrganizationPreview -SourcePath $downloadsPath).Count | Should -Be 0
  }

  It 'reserves unique destinations for names already containing collision suffixes' {
    $null = New-TestDownload -Name 'report.pdf' -Value 'a'
    $null = New-TestDownload -Name 'report (1).pdf' -Value 'b'
    $category = Join-Path $downloadsPath 'Documents'
    $null = [IO.Directory]::CreateDirectory($category)
    [IO.File]::WriteAllText((Join-Path $category 'report.pdf'), 'existing')
    $preview = @(Get-DownloadOrganizationPreview -SourcePath $downloadsPath)
    @($preview.TargetPath | Sort-Object -Unique).Count | Should -Be 2
    (Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath).Count | Should -Be 2
    [IO.File]::ReadAllText((Join-Path $category 'report.pdf')) | Should -Be 'existing'
    (Undo-DownloadOrganization -ManifestPath $manifestPath).Count | Should -Be 2
    [IO.File]::ReadAllText((Join-Path $downloadsPath 'report.pdf')) | Should -Be 'a'
    [IO.File]::ReadAllText((Join-Path $downloadsPath 'report (1).pdf')) | Should -Be 'b'
  }

  It 'does not overwrite a destination created after planning' {
    $source = New-TestDownload
    Mock Move-DownloadFile -ModuleName DownloadOrganizer {
      [IO.File]::WriteAllText($TargetPath, 'foreign')
      [IO.File]::Move($SourcePath, $TargetPath)
    }
    { Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath } | Should -Throw
    Test-Path -LiteralPath $source | Should -BeTrue
    $target = Join-Path $downloadsPath 'Documents/report.pdf'
    [IO.File]::ReadAllText($target) | Should -Be 'foreign'
    $undo = Undo-DownloadOrganization -ManifestPath $manifestPath
    $undo.Count | Should -Be 0
    $undo.SkippedCount | Should -Be 1
    [IO.File]::ReadAllText($target) | Should -Be 'foreign'
  }

  It 'preserves the previous manifest on an empty apply' {
    $null = New-TestDownload
    $null = Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath
    $before = [IO.File]::ReadAllBytes($manifestPath)
    $result = Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath
    $result.Action | Should -Be 'unchanged'
    $result.Count | Should -Be 0
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($manifestPath)) | Should -Be ([Convert]::ToBase64String($before))
    (Undo-DownloadOrganization -ManifestPath $manifestPath).Count | Should -Be 1
  }

  It 'does not create a manifest or lock for an initially empty source' {
    (Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath).Action | Should -Be 'unchanged'
    Test-Path -LiteralPath $manifestPath | Should -BeFalse
    Test-Path -LiteralPath ($manifestPath + '.lock') | Should -BeFalse
  }

  It 'archives a previous nonempty run before replacing the manifest' {
    $null = New-TestDownload -Name 'a.pdf'
    $null = Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath
    $firstRun = (Read-DownloadManifest -ManifestPath $manifestPath).RunId
    $null = New-TestDownload -Name 'b.pdf'
    $null = Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath
    $backups = @(Get-ChildItem -LiteralPath $caseRoot -Filter '*.bak')
    $backups.Count | Should -Be 1
    (Read-DownloadManifest -ManifestPath $backups[0].FullName).RunId | Should -Be $firstRun
    (Undo-DownloadOrganization -ManifestPath $manifestPath).Count | Should -Be 1
    (Undo-DownloadOrganization -ManifestPath $backups[0].FullName).Count | Should -Be 1
  }

  It 'ignores pending entries even if their target is occupied' {
    $source = New-TestDownload
    $manifest = New-DownloadManifest -Preview @(Get-DownloadOrganizationPreview -SourcePath $downloadsPath) -SourcePath $downloadsPath
    $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $manifest.Entries[0].TargetPath))
    [IO.File]::WriteAllText($manifest.Entries[0].TargetPath, 'foreign')
    Save-TestManifest -Manifest $manifest
    (Undo-DownloadOrganization -ManifestPath $manifestPath).Count | Should -Be 0
    [IO.File]::ReadAllText($source) | Should -Be 'original'
    [IO.File]::ReadAllText($manifest.Entries[0].TargetPath) | Should -Be 'foreign'
  }

  It 'never moves a replacement file on a repeated undo' {
    $source = New-TestDownload
    $null = Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath
    $target = (Read-DownloadManifest -ManifestPath $manifestPath).Entries[0].TargetPath
    (Undo-DownloadOrganization -ManifestPath $manifestPath).Count | Should -Be 1
    [IO.File]::WriteAllText($target, 'replacement')
    (Undo-DownloadOrganization -ManifestPath $manifestPath).Count | Should -Be 0
    [IO.File]::ReadAllText($target) | Should -Be 'replacement'
    [IO.File]::ReadAllText($source) | Should -Be 'original'
  }

  It 'skips a changed target and reports the actual restored count' {
    $null = New-TestDownload -Name 'a.pdf'
    $null = New-TestDownload -Name 'b.pdf'
    $null = Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath
    $changed = Join-Path $downloadsPath 'Documents/b.pdf'
    [IO.File]::WriteAllText($changed, 'replacement')
    $result = Undo-DownloadOrganization -ManifestPath $manifestPath
    $result.Action | Should -Be 'undo-partial'
    $result.Count | Should -Be 1
    $result.SkippedCount | Should -Be 1
    [IO.File]::ReadAllText($changed) | Should -Be 'replacement'
    (Read-DownloadManifest -ManifestPath $manifestPath).Entries[0].State | Should -Be 'restored'
  }

  It 'skips a missing target without counting it as restored' {
    $null = New-TestDownload
    $null = Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath
    $manifest = Read-DownloadManifest -ManifestPath $manifestPath
    [IO.File]::Delete($manifest.Entries[0].TargetPath)
    $result = Undo-DownloadOrganization -ManifestPath $manifestPath
    $result.Count | Should -Be 0
    $result.SkippedCount | Should -Be 1
  }

  It 'restores without overwriting a newly created source file' {
    $source = New-TestDownload
    $null = Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath
    [IO.File]::WriteAllText($source, 'new source')
    (Undo-DownloadOrganization -ManifestPath $manifestPath).Count | Should -Be 1
    [IO.File]::ReadAllText($source) | Should -Be 'new source'
    [IO.File]::ReadAllText((Join-Path $downloadsPath 'report (1).pdf')) | Should -Be 'original'
    (Read-DownloadManifest -ManifestPath $manifestPath).Entries[0].RestorePath | Should -Be (Join-Path $downloadsPath 'report (1).pdf')
  }

  It 'recovers a partial apply and leaves the failed source untouched' {
    $null = New-TestDownload -Name 'a.pdf'
    $failedSource = New-TestDownload -Name 'b.pdf'
    Mock Move-DownloadFile -ModuleName DownloadOrganizer { throw 'simulated move failure' } -ParameterFilter { [IO.Path]::GetFileName($SourcePath) -eq 'b.pdf' }
    { Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath } | Should -Throw '*simulated move failure*'
    (Read-DownloadManifest -ManifestPath $manifestPath).Status | Should -Be 'partial'
    (Undo-DownloadOrganization -ManifestPath $manifestPath).Count | Should -Be 1
    Test-Path -LiteralPath $failedSource | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $downloadsPath 'a.pdf') | Should -BeTrue
  }

  It 'recovers the journal when a move completed before its checkpoint' {
    $source = New-TestDownload
    $manifest = New-DownloadManifest -Preview @(Get-DownloadOrganizationPreview -SourcePath $downloadsPath) -SourcePath $downloadsPath
    $entry = $manifest.Entries[0]
    $entry.State = 'moving'
    $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $entry.TargetPath))
    [IO.File]::Move($source, $entry.TargetPath)
    Save-TestManifest -Manifest $manifest
    (Undo-DownloadOrganization -ManifestPath $manifestPath).Count | Should -Be 1
    Test-Path -LiteralPath $source | Should -BeTrue
  }

  It 'recovers a restore completed before its checkpoint without moving twice' {
    $source = New-TestDownload
    $null = Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath
    $manifest = Read-DownloadManifest -ManifestPath $manifestPath
    $entry = $manifest.Entries[0]
    $entry.State = 'restoring'
    $entry.RestorePath = $source
    [IO.File]::Move($entry.TargetPath, $source)
    Save-TestManifest -Manifest $manifest
    (Undo-DownloadOrganization -ManifestPath $manifestPath).Count | Should -Be 0
    (Read-DownloadManifest -ManifestPath $manifestPath).Entries[0].State | Should -Be 'restored'
    Test-Path -LiteralPath $source | Should -BeTrue
  }

  It 'does not guess ownership when both restore and target paths are occupied' {
    $source = New-TestDownload
    $null = Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath
    $manifest = Read-DownloadManifest -ManifestPath $manifestPath
    $manifest.Entries[0].State = 'restoring'
    $manifest.Entries[0].RestorePath = $source
    [IO.File]::WriteAllText($source, 'foreign')
    Save-TestManifest -Manifest $manifest
    $result = Undo-DownloadOrganization -ManifestPath $manifestPath
    $result.Count | Should -Be 0
    $result.SkippedCount | Should -Be 1
    [IO.File]::ReadAllText($source) | Should -Be 'foreign'
  }

  It 'propagates a real filesystem move failure when the module caller uses Continue' {
    $source = New-TestDownload
    Mock Move-DownloadFile -ModuleName DownloadOrganizer {
      $lock = [IO.File]::Open($SourcePath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
      try { [IO.File]::Move($SourcePath, $TargetPath) } finally { $lock.Dispose() }
    }
    $ErrorActionPreference = 'Continue'
    { Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath } | Should -Throw
    (Read-DownloadManifest -ManifestPath $manifestPath).Entries[0].State | Should -Be 'moving'
    (Read-DownloadManifest -ManifestPath $manifestPath).Status | Should -Be 'partial'
    Test-Path -LiteralPath $source | Should -BeTrue
  }

  It 'does not move anything when the initial manifest write fails' {
    $source = New-TestDownload
    Mock Write-DownloadManifest -ModuleName DownloadOrganizer { throw 'manifest unavailable' }
    { Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath } | Should -Throw '*manifest unavailable*'
    Test-Path -LiteralPath $source | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $downloadsPath 'Documents') | Should -BeFalse
  }

  It 'does not record a silent no-op as a successful move' {
    $source = New-TestDownload
    Mock Move-DownloadFile -ModuleName DownloadOrganizer { }
    { Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath } | Should -Throw '*Movimento nao confirmado*'
    Test-Path -LiteralPath $source | Should -BeTrue
    (Read-DownloadManifest -ManifestPath $manifestPath).Status | Should -Be 'partial'
  }

  It 'recovers a real move when all subsequent checkpoint writes fail' {
    $source = New-TestDownload
    Mock Write-DownloadManifest -ModuleName DownloadOrganizer { throw 'checkpoint unavailable' } -ParameterFilter { $Manifest.Entries[0].State -eq 'moved' }
    { Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath } | Should -Throw '*checkpoint unavailable*'
    Test-Path -LiteralPath $source | Should -BeFalse
    (Read-DownloadManifest -ManifestPath $manifestPath).Entries[0].State | Should -Be 'moving'
    (Undo-DownloadOrganization -ManifestPath $manifestPath).Count | Should -Be 1
    [IO.File]::ReadAllText($source) | Should -Be 'original'
  }

  It 'does not move anything when the manifest path is a directory' {
    $source = New-TestDownload
    $null = [IO.Directory]::CreateDirectory($manifestPath)
    { Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath } | Should -Throw
    Test-Path -LiteralPath $source | Should -BeTrue
  }

  It 'preserves the prior checkpoint if an atomic write cannot replace a locked manifest' {
    $source = New-TestDownload
    $null = Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath
    $before = [IO.File]::ReadAllBytes($manifestPath)
    $lock = [IO.File]::Open($manifestPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
      { Undo-DownloadOrganization -ManifestPath $manifestPath } | Should -Throw
      Test-Path -LiteralPath $source | Should -BeFalse
      [Convert]::ToBase64String([IO.File]::ReadAllBytes($manifestPath)) | Should -Be ([Convert]::ToBase64String($before))
    } finally { $lock.Dispose() }
    @(Get-ChildItem -LiteralPath $caseRoot -Filter '*.tmp').Count | Should -Be 0
    (Undo-DownloadOrganization -ManifestPath $manifestPath).Count | Should -Be 1
  }

  It 'rejects concurrent operations on the same manifest without moving files' {
    $source = New-TestDownload
    $lock = [IO.File]::Open(($manifestPath + '.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
      { Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath } | Should -Throw '*bloquear o manifesto*'
      Test-Path -LiteralPath $source | Should -BeTrue
      Test-Path -LiteralPath $manifestPath | Should -BeFalse
    } finally { $lock.Dispose() }
  }

  It 'rejects a manifest inside the source before overwriting user data' {
    $source = New-TestDownload -Name 'manifest.json' -Value 'user data'
    { Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $source } | Should -Throw '*fora da pasta*'
    [IO.File]::ReadAllText($source) | Should -Be 'user data'
  }

  It 'rejects files and non-filesystem providers as sources' {
    $source = New-TestDownload
    { Get-DownloadOrganizationPreview -SourcePath $source } | Should -Throw '*pasta existente*'
    { Get-DownloadOrganizationPreview -SourcePath 'Env:PATH' } | Should -Throw '*sistema de arquivos*'
  }

  It 'rejects a category occupied by a file before moving anything' {
    $source = New-TestDownload
    [IO.File]::WriteAllText((Join-Path $downloadsPath 'Documents'), 'keep')
    { Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath } | Should -Throw '*categoria*'
    Test-Path -LiteralPath $source | Should -BeTrue
    Test-Path -LiteralPath $manifestPath | Should -BeFalse
  }

  It 'rejects category junctions that would move files outside the source' {
    $source = New-TestDownload
    $outside = Join-Path $caseRoot 'outside'
    $null = [IO.Directory]::CreateDirectory($outside)
    $junction = Join-Path $downloadsPath 'Documents'
    $null = New-Item -ItemType Junction -Path $junction -Target $outside -ErrorAction Stop
    try {
      { Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath } | Should -Throw '*reparse points*'
      Test-Path -LiteralPath $source | Should -BeTrue
      @(Get-ChildItem -LiteralPath $outside).Count | Should -Be 0
    } finally {
      [IO.Directory]::Delete($junction)
    }
  }

  It 'rejects legacy manifests lacking fingerprints before touching files' {
    [IO.File]::WriteAllText($manifestPath, '{"SourcePath":"C:\\Downloads","Entries":[]}')
    { Undo-DownloadOrganization -ManifestPath $manifestPath } | Should -Throw '*versao 2*'
  }

  It 'rejects corrupt JSON before touching files' {
    [IO.File]::WriteAllText($manifestPath, 'not json')
    { Undo-DownloadOrganization -ManifestPath $manifestPath } | Should -Throw
    Test-Path -LiteralPath ($manifestPath + '.lock') | Should -BeFalse
  }

  It 'rejects a manifest entry pointing outside its declared source' {
    $null = New-TestDownload
    $null = Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath
    $manifest = Read-DownloadManifest -ManifestPath $manifestPath
    $outside = Join-Path $caseRoot 'outside.pdf'
    [IO.File]::WriteAllText($outside, 'keep')
    $manifest.Entries[0].TargetPath = $outside
    Save-TestManifest -Manifest $manifest
    { Undo-DownloadOrganization -ManifestPath $manifestPath } | Should -Throw '*fora da origem*'
    [IO.File]::ReadAllText($outside) | Should -Be 'keep'
  }

  It 'supports apply and undo WhatIf without filesystem changes' {
    $source = New-TestDownload
    $null = Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath -WhatIf
    Test-Path -LiteralPath $source | Should -BeTrue
    Test-Path -LiteralPath $manifestPath | Should -BeFalse
    $null = Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath $manifestPath
    $before = [IO.File]::ReadAllText($manifestPath)
    $null = Undo-DownloadOrganization -ManifestPath $manifestPath -WhatIf
    Test-Path -LiteralPath $source | Should -BeFalse
    [IO.File]::ReadAllText($manifestPath) | Should -Be $before
  }

  It 'normalizes a source with a trailing separator' {
    $null = New-TestDownload
    (Invoke-DownloadOrganization -SourcePath ($downloadsPath + '\') -ManifestPath $manifestPath).Count | Should -Be 1
    (Undo-DownloadOrganization -ManifestPath $manifestPath).Count | Should -Be 1
  }

  It 'executes the CLI preview apply path and undo commands with explicit paths' {
    $source = New-TestDownload
    @(& $entryPoint preview -SourcePath $downloadsPath).Count | Should -Be 1
    (& $entryPoint path -ManifestPath $manifestPath) | Should -Be $manifestPath
    (& $entryPoint apply -SourcePath $downloadsPath -ManifestPath $manifestPath).Count | Should -Be 1
    (& $entryPoint undo -ManifestPath $manifestPath).Count | Should -Be 1
    Test-Path -LiteralPath $source | Should -BeTrue
  }

  It 'does not emit a blank result object or change files for CLI WhatIf' {
    $source = New-TestDownload
    @(& $entryPoint apply -SourcePath $downloadsPath -ManifestPath $manifestPath -WhatIf).Count | Should -Be 0
    Test-Path -LiteralPath $source | Should -BeTrue
    Test-Path -LiteralPath $manifestPath | Should -BeFalse
    $null = & $entryPoint apply -SourcePath $downloadsPath -ManifestPath $manifestPath
    $before = [IO.File]::ReadAllText($manifestPath)
    @(& $entryPoint undo -ManifestPath $manifestPath -WhatIf).Count | Should -Be 0
    Test-Path -LiteralPath $source | Should -BeFalse
    [IO.File]::ReadAllText($manifestPath) | Should -Be $before
  }

  It 'normalizes a relative manifest path with no explicit parent' {
    $null = New-TestDownload
    Push-Location $caseRoot
    try {
      $result = Invoke-DownloadOrganization -SourcePath $downloadsPath -ManifestPath 'relative.json'
      $result.ManifestPath | Should -Be (Join-Path $caseRoot 'relative.json')
      (Undo-DownloadOrganization -ManifestPath 'relative.json').Count | Should -Be 1
    } finally { Pop-Location }
  }
}

Describe 'download categories' {
  It 'classifies <Extension> as <Category>' -ForEach @(
    @{ Extension = '.PDF'; Category = 'Documents' }
    @{ Extension = '.jpg'; Category = 'Images' }
    @{ Extension = '.zip'; Category = 'Archives' }
    @{ Extension = '.msi'; Category = 'Installers' }
    @{ Extension = '.mp3'; Category = 'Audio' }
    @{ Extension = '.mp4'; Category = 'Video' }
    @{ Extension = '.ps1'; Category = 'Code' }
    @{ Extension = ''; Category = 'Other' }
    @{ Extension = '.unknown'; Category = 'Other' }
  ) {
    Get-DownloadCategoryForExtension -Extension $Extension | Should -Be $Category
  }
}
