BeforeAll {
  $script:verificationPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'verify-bootstrap.ps1'
  function Get-PSResourceRepository {
    [CmdletBinding()]
    param([string]$Name)
    throw "Real repository access is forbidden in unit tests: $Name"
  }
}

Describe 'bootstrap integration verification guard' {
  BeforeEach {
    $repositoryState = @{ Reads = 0; Change = ''; ResourceGet = $false; ResourceReads = 0; ResourceChange = '' }
    $fixture = Join-Path $TestDrive 'bootstrap-fixture.ps1'
    $fixtureContent = @'
param([string]$Scope, [switch]$PassThru)
if ($Scope -ne 'CurrentUser' -or -not $PassThru) { throw 'incorrect invocation' }
[pscustomobject]@{ Name = 'Pester'; Version = '5.7.1' }
[pscustomobject]@{ Name = 'PSScriptAnalyzer'; Version = '1.24.0' }
'@
    [IO.File]::WriteAllText($fixture, $fixtureContent, [Text.UTF8Encoding]::new($false))
    Mock Join-Path { $fixture } -ParameterFilter { $ChildPath -eq 'bootstrap-dev.ps1' }
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
    & $script:verificationPath | Should -Contain 'BOOTSTRAP_OK (CurrentUser; confianca do PSGallery preservada)'
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
    & $script:verificationPath | Should -Contain 'BOOTSTRAP_OK (CurrentUser; confianca do PSGallery preservada)'
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
}
