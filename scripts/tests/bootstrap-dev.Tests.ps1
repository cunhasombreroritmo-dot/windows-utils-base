BeforeDiscovery {
  Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'DevelopmentDependencies.psm1') -Force
}

Describe 'bootstrap installation destinations' {
  It 'uses the redirected Documents folder and the current engine directory' {
    $directory = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'WindowsPowerShell' } else { 'PowerShell' }
    Get-DevelopmentModuleRoot -Scope CurrentUser | Should -Be (Join-Path (Join-Path ([Environment]::GetFolderPath('MyDocuments')) $directory) 'Modules')
    Get-DevelopmentModuleRoot -Scope AllUsers | Should -Be (Join-Path (Join-Path ([Environment]::GetFolderPath('ProgramFiles')) $directory) 'Modules')
  }

  InModuleScope DevelopmentDependencies {
    BeforeAll {
      # Define guarded commands so the same mocks work even on stock PowerShell 5.1.
      function Install-PSResource {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Test-only guard mirrors installer parameters for mock binding.')]
        [CmdletBinding()]
        param([string]$Name, [string]$Version, [string]$Repository, [string]$Scope, [switch]$TrustRepository, [switch]$Quiet)
        throw 'Real installation is forbidden in unit tests.'
      }
      function Install-Module {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Test-only guard prevents real installation on both engines.')]
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Test-only guard mirrors installer parameters for mock binding.')]
        [CmdletBinding()]
        param([string]$Name, [version]$RequiredVersion, [string]$Repository, [string]$Scope, [switch]$Force, [switch]$SkipPublisherCheck)
        throw 'Real installation is forbidden in unit tests.'
      }
      function New-FixtureModule {
        param([string]$Name, [version]$Version, [string]$Root)
        $directory = Join-Path (Join-Path $Root $Name) $Version.ToString()
        $null = [IO.Directory]::CreateDirectory($directory)
        $content = "@{ ModuleVersion = '$Version'; GUID = '8ec3c68f-716b-4caf-8e7c-008434c54863' }"
        [IO.File]::WriteAllText((Join-Path $directory "$Name.psd1"), $content, [Text.UTF8Encoding]::new($false))
      }
    }

    BeforeEach {
      $fixtureDrive = (Get-PSDrive TestDrive).Root
      $script:roots = @{
        CurrentUser = Join-Path $fixtureDrive ([guid]::NewGuid().ToString('N') + '-[user]')
        AllUsers = Join-Path $fixtureDrive ([guid]::NewGuid().ToString('N') + '-[all]')
      }
      $script:manager = 'Install-PSResource'
      Mock Get-DevelopmentModuleRoot { $script:roots[$Scope] }
      Mock Get-Command {
        if ($Name -eq $script:manager -or $script:manager -eq 'both') { [pscustomobject]@{ Name = $Name } }
      }
      Mock Install-PSResource { New-FixtureModule -Name $Name -Version $Version -Root $script:roots[$Scope] }
      Mock Install-Module { New-FixtureModule -Name $Name -Version $RequiredVersion -Root $script:roots[$Scope] }
      Mock Test-DevelopmentElevation { $true }
      Mock Initialize-DevelopmentPackageProvider {}
    }

    It 'installs exact versions through <Manager> in <Scope>' -ForEach @(
      @{ Manager = 'Install-PSResource'; Scope = 'CurrentUser' },
      @{ Manager = 'Install-PSResource'; Scope = 'AllUsers' },
      @{ Manager = 'Install-Module'; Scope = 'CurrentUser' },
      @{ Manager = 'Install-Module'; Scope = 'AllUsers' }
    ) {
      $script:manager = $Manager
      $result = @(Initialize-DevelopmentEnvironment -Scope $Scope)
      $result.Count | Should -Be 2
      $result[0].Version | Should -Be '5.7.1'
      $result[1].Version | Should -Be '1.24.0'
      foreach ($item in $result) {
        $item.Source | Should -Be 'installed'
        $item.Scope | Should -Be $Scope
        $item.ModuleBase.StartsWith($script:roots[$Scope] + [IO.Path]::DirectorySeparatorChar) | Should -BeTrue
      }
      if ($Manager -eq 'Install-PSResource') {
        Should -Invoke Install-PSResource -Times 2 -Exactly -ParameterFilter { $Repository -eq 'PSGallery' -and $TrustRepository -and $Quiet -and $ErrorAction -eq 'Stop' }
        Should -Invoke Install-PSResource -Times 1 -Exactly -ParameterFilter { $Name -eq 'Pester' -and $Version -eq '5.7.1' }
        Should -Invoke Install-PSResource -Times 1 -Exactly -ParameterFilter { $Name -eq 'PSScriptAnalyzer' -and $Version -eq '1.24.0' }
        Should -Invoke Install-Module -Times 0 -Exactly
      } else {
        Should -Invoke Install-Module -Times 2 -Exactly -ParameterFilter { $Repository -eq 'PSGallery' -and $Force -and $ErrorAction -eq 'Stop' }
        Should -Invoke Install-Module -Times 1 -Exactly -ParameterFilter { $Name -eq 'Pester' -and $RequiredVersion -eq '5.7.1' -and $SkipPublisherCheck }
        Should -Invoke Install-Module -Times 1 -Exactly -ParameterFilter { $Name -eq 'PSScriptAnalyzer' -and $RequiredVersion -eq '1.24.0' -and -not $SkipPublisherCheck }
        Should -Invoke Install-PSResource -Times 0 -Exactly
      }
    }

    It 'reuses only the correct version in <Scope>' -ForEach @(
      @{ Scope = 'CurrentUser' }, @{ Scope = 'AllUsers' }
    ) {
      New-FixtureModule -Name Pester -Version 5.7.1 -Root $script:roots[$Scope]
      New-FixtureModule -Name PSScriptAnalyzer -Version 1.24.0 -Root $script:roots[$Scope]
      $result = @(Initialize-DevelopmentEnvironment -Scope $Scope)
      @($result | Where-Object Source -eq 'existing').Count | Should -Be 2
      Should -Invoke Install-PSResource -Times 0 -Exactly
      Should -Invoke Install-Module -Times 0 -Exactly
      Should -Invoke Get-Command -Times 0 -Exactly
    }

    It 'does not reuse modules from the opposite scope when requesting <Scope>' -ForEach @(
      @{ Scope = 'CurrentUser'; Other = 'AllUsers' }, @{ Scope = 'AllUsers'; Other = 'CurrentUser' }
    ) {
      New-FixtureModule -Name Pester -Version 5.7.1 -Root $script:roots[$Other]
      New-FixtureModule -Name PSScriptAnalyzer -Version 1.24.0 -Root $script:roots[$Other]
      $oldPath = $env:PSModulePath
      try {
        $env:PSModulePath = $script:roots[$Other] + [IO.Path]::PathSeparator + $oldPath
        $result = @(Initialize-DevelopmentEnvironment -Scope $Scope)
        @($result | Where-Object Source -eq 'installed').Count | Should -Be 2
        Should -Invoke Install-PSResource -Times 2 -Exactly
      } finally { $env:PSModulePath = $oldPath }
    }

    It 'installs the pinned version even when an older or newer version exists' {
      New-FixtureModule -Name Pester -Version 3.4.0 -Root $script:roots.CurrentUser
      New-FixtureModule -Name PSScriptAnalyzer -Version 9.0.0 -Root $script:roots.CurrentUser
      $result = @(Initialize-DevelopmentEnvironment)
      @($result | Where-Object Source -eq 'installed').Count | Should -Be 2
      Should -Invoke Install-PSResource -Times 2 -Exactly
    }

    It 'prefers PSResourceGet when both managers exist' {
      $script:manager = 'both'
      $null = Initialize-DevelopmentEnvironment
      Should -Invoke Install-PSResource -Times 2 -Exactly
      Should -Invoke Install-Module -Times 0 -Exactly
    }

    It 'fails when neither manager exists' {
      $script:manager = 'none'
      { Initialize-DevelopmentEnvironment } | Should -Throw '*Nenhum gerenciador*'
      Should -Invoke Install-PSResource -Times 0 -Exactly
      Should -Invoke Install-Module -Times 0 -Exactly
    }

    It 'propagates installation errors without falling back to another manager' {
      $script:manager = 'both'
      Mock Install-PSResource { throw 'installation sentinel' }
      { Initialize-DevelopmentEnvironment } | Should -Throw '*installation sentinel*'
      Should -Invoke Install-PSResource -Times 1 -Exactly
      Should -Invoke Install-Module -Times 0 -Exactly
    }

    It 'rejects a silent installer no-op' {
      Mock Install-PSResource {}
      { Initialize-DevelopmentEnvironment } | Should -Throw '*Falha ao instalar*CurrentUser*'
    }

    It 'rejects an installer that puts modules in the wrong scope' {
      Mock Install-PSResource { New-FixtureModule -Name $Name -Version $Version -Root $script:roots.CurrentUser }
      { Initialize-DevelopmentEnvironment -Scope AllUsers } | Should -Throw '*Falha ao instalar*AllUsers*'
    }

    It 'rejects unelevated AllUsers before contacting either manager' {
      Mock Test-DevelopmentElevation { $false }
      { Initialize-DevelopmentEnvironment -Scope AllUsers } | Should -Throw '*sessao elevada*'
      Should -Invoke Get-Command -Times 0 -Exactly
      Should -Invoke Install-Module -Times 0 -Exactly
      Should -Invoke Install-PSResource -Times 0 -Exactly
      Should -Invoke Initialize-DevelopmentPackageProvider -Times 0 -Exactly
    }

    It 'allows an unelevated user to reuse complete AllUsers dependencies' {
      Mock Test-DevelopmentElevation { $false }
      New-FixtureModule -Name Pester -Version 5.7.1 -Root $script:roots.AllUsers
      New-FixtureModule -Name PSScriptAnalyzer -Version 1.24.0 -Root $script:roots.AllUsers
      @(Initialize-DevelopmentEnvironment -Scope AllUsers | Where-Object Source -eq existing).Count | Should -Be 2
      Should -Invoke Test-DevelopmentElevation -Times 0 -Exactly
    }

    It 'restores process TLS after PowerShellGet <Outcome>' -ForEach @(@{ Outcome = 'success' }, @{ Outcome = 'failure' }) {
      $script:manager = 'Install-Module'
      $previous = [Net.ServicePointManager]::SecurityProtocol
      try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls11
        Mock Initialize-DevelopmentPackageProvider {
          if ($PSVersionTable.PSEdition -eq 'Desktop') {
            ([Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls12) | Should -Be ([Net.SecurityProtocolType]::Tls12)
          }
        }
        if ($Outcome -eq 'failure') {
          Mock Install-Module { throw 'module install failed' }
          { Initialize-DevelopmentEnvironment } | Should -Throw '*module install failed*'
        } else {
          $null = Initialize-DevelopmentEnvironment
        }
        [Net.ServicePointManager]::SecurityProtocol | Should -Be ([Net.SecurityProtocolType]::Tls11)
      } finally { [Net.ServicePointManager]::SecurityProtocol = $previous }
    }

    It 'does not install a module when NuGet preparation fails' {
      $script:manager = 'Install-Module'
      Mock Initialize-DevelopmentPackageProvider { throw 'provider failure' }
      { Initialize-DevelopmentEnvironment } | Should -Throw '*provider failure*'
      Should -Invoke Install-Module -Times 0 -Exactly
    }
  }
}

Describe 'NuGet first-use preparation' {
  InModuleScope DevelopmentDependencies {
    BeforeEach {
      $script:providers = @()
      Mock Get-PackageProvider { $script:providers }
      Mock Install-PackageProvider { $script:providers = @([pscustomobject]@{ Name = 'NuGet'; Version = '2.8.5.216' }) }
    }
    It 'prepares missing NuGet noninteractively in <Scope>' -ForEach @(@{ Scope = 'CurrentUser' }, @{ Scope = 'AllUsers' }) {
      $script:expectedScope = $Scope
      Initialize-DevelopmentPackageProvider -Scope $Scope
      Should -Invoke Install-PackageProvider -Times 1 -Exactly -ParameterFilter {
        $Name -eq 'NuGet' -and $MinimumVersion -eq '2.8.5.201' -and $Force -and $Scope -eq $script:expectedScope -and $ErrorAction -eq 'Stop'
      }
      Should -Invoke Get-PackageProvider -Times 2 -Exactly -ParameterFilter { $ListAvailable -and -not $Name }
    }
    It 'reuses an adequate provider without downloading' {
      $script:providers = @([pscustomobject]@{ Name = 'NuGet'; Version = '2.8.5.201' })
      Initialize-DevelopmentPackageProvider -Scope CurrentUser
      Should -Invoke Install-PackageProvider -Times 0 -Exactly
    }
    It 'updates an inadequate provider' {
      $script:providers = @([pscustomobject]@{ Name = 'NuGet'; Version = '2.8.5.100' })
      Initialize-DevelopmentPackageProvider -Scope CurrentUser
      Should -Invoke Install-PackageProvider -Times 1 -Exactly
    }
    It 'rejects a provider installer no-op' {
      Mock Install-PackageProvider {}
      { Initialize-DevelopmentPackageProvider -Scope CurrentUser } | Should -Throw '*nao disponibilizou*'
    }
    It 'propagates provider installation failures' {
      Mock Install-PackageProvider { throw 'provider download failed' }
      { Initialize-DevelopmentPackageProvider -Scope CurrentUser } | Should -Throw '*provider download failed*'
    }
  }
}
