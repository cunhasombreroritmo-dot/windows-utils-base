[CmdletBinding()]
param(
  [ValidateSet('CurrentUser', 'AllUsers')]
  [string]$Scope = 'CurrentUser'
)

$ErrorActionPreference = 'Stop'

$requiredModules = @(
  @{
    Name = 'Pester'
    MinimumVersion = [version]'5.0.0'
  },
  @{
    Name = 'PSScriptAnalyzer'
    MinimumVersion = [version]'1.21.0'
  }
)

function Get-LatestInstalledModule {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  return Get-Module -ListAvailable $Name |
    Sort-Object Version -Descending |
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

  $installed = Get-LatestInstalledModule -Name $Module.Name
  if ($installed -and $installed.Version -ge $Module.MinimumVersion) {
    return [pscustomobject]@{
      Name = $Module.Name
      Version = $installed.Version.ToString()
      Source = 'existing'
    }
  }

  if (Get-Command Install-PSResource -ErrorAction SilentlyContinue) {
    if (Get-Command Set-PSResourceRepository -ErrorAction SilentlyContinue) {
      Set-PSResourceRepository -Name PSGallery -Trusted
    }

    Install-PSResource -Name $Module.Name -Repository PSGallery -Scope $Scope -TrustRepository -Quiet
  } elseif (Get-Command Install-Module -ErrorAction SilentlyContinue) {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module -Name $Module.Name -Repository PSGallery -Scope $Scope -Force -AllowClobber
  } else {
    throw 'Nenhum gerenciador de modulos PowerShell disponivel para instalar dependencias.'
  }

  $resolved = Get-LatestInstalledModule -Name $Module.Name
  if (-not $resolved -or $resolved.Version -lt $Module.MinimumVersion) {
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
