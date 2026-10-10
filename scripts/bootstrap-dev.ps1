#Requires -Version 5.1
[CmdletBinding()]
param(
  [ValidateSet('CurrentUser', 'AllUsers')]
  [string]$Scope = 'CurrentUser'
)

$ErrorActionPreference = 'Stop'

$requiredModules = @(
  @{
    Name = 'Pester'
    RequiredVersion = [version]'5.7.1'
  },
  @{
    Name = 'PSScriptAnalyzer'
    RequiredVersion = [version]'1.24.0'
  }
)

function Get-RequiredInstalledModule {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [version]$Version
  )

  return Get-Module -ListAvailable $Name |
    Where-Object { $_.Version -eq $Version } |
    Select-Object -First 1
}

function Install-RequiredModule {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Module,

    [Parameter(Mandatory = $true)]
    [string]$Scope
  )

  $installed = Get-RequiredInstalledModule -Name $Module.Name -Version $Module.RequiredVersion
  if ($installed) {
    return [pscustomobject]@{
      Name = $Module.Name
      Version = $installed.Version.ToString()
      Source = 'existing'
    }
  }

  if (Get-Command Install-PSResource -ErrorAction SilentlyContinue) {
    Install-PSResource -Name $Module.Name -Version $Module.RequiredVersion.ToString() -Repository PSGallery -Scope $Scope -TrustRepository -Quiet -ErrorAction Stop
  } elseif (Get-Command Install-Module -ErrorAction SilentlyContinue) {
    # Pester 3.4 bundled with Windows uses a different publisher certificate.
    # Scope this compatibility exception to Pester; repository trust stays unchanged.
    $installParameters = @{
      Name = $Module.Name
      RequiredVersion = $Module.RequiredVersion
      Repository = 'PSGallery'
      Scope = $Scope
      Force = $true
      ErrorAction = 'Stop'
    }
    if ($Module.Name -eq 'Pester') { $installParameters.SkipPublisherCheck = $true }
    Install-Module @installParameters
  } else {
    throw 'Nenhum gerenciador de modulos PowerShell disponivel para instalar dependencias.'
  }

  $resolved = Get-RequiredInstalledModule -Name $Module.Name -Version $Module.RequiredVersion
  if (-not $resolved) {
    throw "Falha ao instalar o modulo $($Module.Name)."
  }

  return [pscustomobject]@{
    Name = $Module.Name
    Version = $resolved.Version.ToString()
    Source = 'installed'
  }
}

$results = foreach ($module in $requiredModules) {
  Install-RequiredModule -Module $module -Scope $Scope
}

$results | Format-Table -AutoSize | Out-String | Write-Output
