BeforeAll {
  $script:verificationPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'verify-bootstrap.ps1'
  Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'DevelopmentDependencies.psm1') -Force
  function Get-PSResourceRepository {
    [CmdletBinding()]
    param([string]$Name)
    throw "Real repository access is forbidden in unit tests: $Name"
  }
  function Get-PSRepository {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Test-only guard prevents real repository access and supports isolated execution.')]
    [CmdletBinding()]
    param([string]$Name)
    throw "Real repository access is forbidden in unit tests: $Name"
  }
}

Describe 'bootstrap integration verification guard' {
  BeforeEach {
    $repositoryState = @{ Reads = 0; Change = ''; ResourceGet = $false; ResourceReads = 0; ResourceChange = '' }
    $fixture = Join-Path $TestDrive 'bootstrap-fixture.ps1'
    $script:fixtureRoot = Join-Path $TestDrive 'modules'
    $script:fixtureState = @{ Calls = 0; Root = $script:fixtureRoot }
    $fixtureContent = @'
param([string]$Scope, [switch]$PassThru)
if (-not $PassThru) { throw 'incorrect invocation' }
$fixtureState.Calls++
$source = if ($fixtureState.Calls -eq 1) { 'installed' } else { 'existing' }
[pscustomobject]@{ Name = 'Pester'; Version = '5.7.1'; Scope = $Scope; Source = $source; ModuleBase = Join-Path $fixtureState.Root 'Pester/5.7.1' }
[pscustomobject]@{ Name = 'PSScriptAnalyzer'; Version = '1.24.0'; Scope = $Scope; Source = $source; ModuleBase = Join-Path $fixtureState.Root 'PSScriptAnalyzer/1.24.0' }
'@
    [IO.File]::WriteAllText($fixture, $fixtureContent, [Text.UTF8Encoding]::new($false))
    Mock Join-Path { $fixture } -ParameterFilter { $ChildPath -eq 'bootstrap-dev.ps1' }
    Mock Get-DevelopmentModuleRoot { $fixtureState.Root }
    Mock Import-Module {
      if ($Name -like '*DevelopmentDependencies.psm1') { return }
      $base = Split-Path -Parent $Name
      [pscustomobject]@{ Name = [IO.Path]::GetFileNameWithoutExtension($Name); Version = [version](Split-Path -Leaf $base); ModuleBase = $base }
    }
    Mock Get-Command {
      if ($Name -eq 'Get-PSRepository' -or ($Name -eq 'Get-PSResourceRepository' -and $repositoryState.ResourceGet)) {
        [pscustomobject]@{ Name = $Name }
      }
    }
    Mock Get-PSResourceRepository {
      $repositoryState.ResourceReads++
      $trusted = $repositoryState.ResourceReads -gt 1 -and $repositoryState.ResourceChange -eq 'trust'
      $uri = if ($repositoryState.ResourceReads -gt 1 -and $repositoryState.ResourceChange -eq 'uri') { 'https://invalid.example/api/v2' } else { 'https://www.powershellgallery.com/api/v2' }
      [pscustomobject]@{ Uri = $uri; Trusted = $trusted }
    }
    Mock Get-PSRepository {
      $repositoryState.Reads++
      $policy = if ($repositoryState.Reads -gt 1 -and $repositoryState.Change -eq 'trust') { 'Trusted' } else { 'Untrusted' }
      $uri = if ($repositoryState.Reads -gt 1 -and $repositoryState.Change -eq 'uri') { 'https://invalid.example/api/v2' } else { 'https://www.powershellgallery.com/api/v2' }
      [pscustomobject]@{ SourceLocation = $uri; InstallationPolicy = $policy }
    }
  }

  It 'accepts an unchanged repository after a successful bootstrap' {
    & $script:verificationPath -RequireInstallation | Should -Contain 'BOOTSTRAP_OK (CurrentUser; confianca do PSGallery preservada; importacao e reutilizacao verificadas)'
    $script:fixtureState.Calls | Should -Be 2
    Should -Invoke Get-PSRepository -Times 2 -Exactly -ParameterFilter { $Name -eq 'PSGallery' -and $ErrorAction -eq 'Stop' }
  }

  It 'rejects a change to <Change>' -ForEach @(@{ Change = 'trust' }, @{ Change = 'uri' }) {
    $repositoryState.Change = $Change
    { & $script:verificationPath } | Should -Throw '*alterou a confianca ou o endereco*'
  }

  It 'does not claim verification when no repository manager is available' {
    Mock Get-Command {}
    { & $script:verificationPath } | Should -Throw '*Nenhuma politica de confianca*'
  }

  It 'compares both independent repository stores when both managers are available' {
    $repositoryState.ResourceGet = $true
    & $script:verificationPath | Should -Contain 'BOOTSTRAP_OK (CurrentUser; confianca do PSGallery preservada; importacao e reutilizacao verificadas)'
    Should -Invoke Get-PSResourceRepository -Times 2 -Exactly -ParameterFilter { $Name -eq 'PSGallery' -and $ErrorAction -eq 'Stop' }
    Should -Invoke Get-PSRepository -Times 2 -Exactly
  }

  It 'rejects a PSResourceGet change to <Change>' -ForEach @(@{ Change = 'trust' }, @{ Change = 'uri' }) {
    $repositoryState.ResourceGet = $true
    $repositoryState.ResourceChange = $Change
    { & $script:verificationPath } | Should -Throw '*alterou a confianca ou o endereco*'
  }

  It 'checks repository trust even when bootstrap fails and preserves the original error' {
    [IO.File]::WriteAllText($fixture, "throw 'bootstrap sentinel'", [Text.UTF8Encoding]::new($false))
    { & $script:verificationPath } | Should -Throw '*bootstrap sentinel*'
    Should -Invoke Get-PSRepository -Times 2 -Exactly
  }

  It 'verifies installation and reuse in AllUsers' {
    & $script:verificationPath -Scope AllUsers -RequireInstallation | Should -Contain 'BOOTSTRAP_OK (AllUsers; confianca do PSGallery preservada; importacao e reutilizacao verificadas)'
    $script:fixtureState.Calls | Should -Be 2
    Should -Invoke Get-DevelopmentModuleRoot -Times 2 -Exactly -ParameterFilter { $Scope -eq 'AllUsers' }
  }

  It 'rejects incomplete or incorrect results: <Mutation>' -ForEach @(
    @{ Mutation = 'duplicate'; Replacement = "Name = 'Pester'; Version = '1.24.0'" },
    @{ Mutation = 'version'; Replacement = "Name = 'PSScriptAnalyzer'; Version = '9.0.0'" },
    @{ Mutation = 'scope'; Replacement = "Name = 'PSScriptAnalyzer'; Version = '1.24.0'; Wrong = 1" }
  ) {
    if ($Mutation -eq 'scope') {
      $badFixture = $fixtureContent.Replace('Scope = $Scope', "Scope = 'AllUsers'")
    } else {
      $badFixture = $fixtureContent.Replace("Name = 'PSScriptAnalyzer'; Version = '1.24.0'", $Replacement)
    }
    [IO.File]::WriteAllText($fixture, $badFixture, [Text.UTF8Encoding]::new($false))
    { & $script:verificationPath } | Should -Throw '*Resultado do bootstrap invalido*'
    Should -Invoke Get-PSRepository -Times 2 -Exactly
  }

  It 'rejects a destination outside the requested scope' {
    Mock Get-DevelopmentModuleRoot { Join-Path $TestDrive 'other' }
    { & $script:verificationPath } | Should -Throw '*Destino incorreto*'
  }

  It 'rejects an import failure' {
    Mock Import-Module { throw 'dependency import failure' } -ParameterFilter { $Name -like '*Pester.psd1' }
    { & $script:verificationPath } | Should -Throw '*dependency import failure*'
    Should -Invoke Get-PSRepository -Times 2 -Exactly
  }

  It 'rejects reused modules when a clean installation is required' {
    $script:fixtureState.Calls = 1
    { & $script:verificationPath -RequireInstallation } | Should -Throw '*Esperado Source=installed*'
  }

  It 'rejects a repeated bootstrap that installs again' {
    [IO.File]::WriteAllText($fixture, $fixtureContent.Replace("{ 'installed' } else { 'existing' }", "{ 'installed' } else { 'installed' }"), [Text.UTF8Encoding]::new($false))
    { & $script:verificationPath } | Should -Throw '*Esperado Source=existing*'
  }

  It 'rejects an imported module with incorrect <Property>' -ForEach @(
    @{ Property = 'Name'; Value = 'Other' },
    @{ Property = 'Version'; Value = [version]'9.0.0' },
    @{ Property = 'ModuleBase'; Value = 'C:\wrong-module' }
  ) {
    Mock Import-Module {
      $base = Split-Path -Parent $Name
      $module = [pscustomobject]@{ Name = 'Pester'; Version = [version]'5.7.1'; ModuleBase = $base }
      $module.$Property = $Value
      $module
    } -ParameterFilter { $Name -like '*Pester.psd1' }
    { & $script:verificationPath } | Should -Throw '*Nao foi possivel importar*'
    Should -Invoke Get-PSRepository -Times 2 -Exactly
  }

  It 'rejects a bootstrap that returns only one dependency' {
    $singleFixture = ($fixtureContent -split '\r?\n' | Where-Object { $_ -notlike "*Name = 'PSScriptAnalyzer'*" }) -join [Environment]::NewLine
    [IO.File]::WriteAllText($fixture, $singleFixture, [Text.UTF8Encoding]::new($false))
    { & $script:verificationPath } | Should -Throw '*duas dependencias*'
  }

  It 'enables TLS for the stock repository read and restores it before bootstrap' {
    $previousProtocol = [Net.ServicePointManager]::SecurityProtocol
    try {
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls11
      Mock Get-PSRepository {
        if ($PSVersionTable.PSEdition -eq 'Desktop') {
          ([Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls12) | Should -Be ([Net.SecurityProtocolType]::Tls12)
        }
        [pscustomobject]@{ SourceLocation = 'https://www.powershellgallery.com/api/v2'; InstallationPolicy = 'Untrusted' }
      }
      # Make the fixture reject leaked TLS state before it returns any dependencies.
      $checkedFixture = $fixtureContent.Replace('if (-not $PassThru)', "if ([Net.ServicePointManager]::SecurityProtocol -ne [Net.SecurityProtocolType]::Tls11) { throw 'snapshot changed TLS' }; if (-not $" + 'PassThru)')
      [IO.File]::WriteAllText($fixture, $checkedFixture, [Text.UTF8Encoding]::new($false))
      $null = & $script:verificationPath
      [Net.ServicePointManager]::SecurityProtocol | Should -Be ([Net.SecurityProtocolType]::Tls11)
    } finally { [Net.ServicePointManager]::SecurityProtocol = $previousProtocol }
  }
}
