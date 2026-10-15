#Requires -Version 5.1
Set-StrictMode -Version Latest

function Get-DevelopmentModuleRoot {
  [CmdletBinding()]
  param(
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser'
  )

  if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'O bootstrap suporta apenas Windows.'
  }
  $folder = if ($Scope -eq 'CurrentUser') { 'MyDocuments' } else { 'ProgramFiles' }
  $basePath = [Environment]::GetFolderPath($folder)
  if ([string]::IsNullOrWhiteSpace($basePath)) {
    throw "Nao foi possivel resolver a pasta de instalacao para $Scope."
  }
  $editionDirectory = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'WindowsPowerShell' } else { 'PowerShell' }
  return Join-Path (Join-Path $basePath $editionDirectory) 'Modules'
}

function Get-DevelopmentDependency {
  [CmdletBinding()]
  param([string]$Name, [version]$Version, [string]$ModuleRoot)

  # Search the requested destination directly, never an arbitrary PSModulePath entry.
  $moduleDirectory = Join-Path $ModuleRoot $Name
  if (-not (Test-Path -LiteralPath $moduleDirectory -PathType Container -ErrorAction Stop)) { return }
  return Get-Module -ListAvailable -Name ([WildcardPattern]::Escape($moduleDirectory)) -ErrorAction Stop |
    Where-Object { $_.Name -eq $Name -and $_.Version -eq $Version } |
    Select-Object -First 1
}

function Install-DevelopmentDependency {
  [CmdletBinding()]
  param([hashtable]$Module, [string]$Scope, [string]$ModuleRoot)

  $resolved = Get-DevelopmentDependency -Name $Module.Name -Version $Module.RequiredVersion -ModuleRoot $ModuleRoot
  $source = 'existing'
  if (-not $resolved) {
    if ($Scope -eq 'AllUsers' -and -not (Test-DevelopmentElevation)) {
      throw 'AllUsers requer uma sessao elevada para instalar dependencias. Use CurrentUser ou execute como administrador.'
    }
    if (Get-Command Install-PSResource -ErrorAction SilentlyContinue) {
      # TrustRepository suppresses this operation's prompt; it does not persist trust.
      Install-PSResource -Name $Module.Name -Version $Module.RequiredVersion.ToString() -Repository PSGallery -Scope $Scope -TrustRepository -Quiet -ErrorAction Stop
    } elseif (Get-Command Install-Module -ErrorAction SilentlyContinue) {
      $installParameters = @{
        Name = $Module.Name
        RequiredVersion = $Module.RequiredVersion
        Repository = 'PSGallery'
        Scope = $Scope
        Force = $true
        ErrorAction = 'Stop'
      }
      # Pester 3.4 bundled with Windows uses a different publisher certificate.
      # Force suppresses repository prompts; neither switch changes repository policy.
      if ($Module.Name -eq 'Pester') { $installParameters.SkipPublisherCheck = $true }
      $previousProtocol = [Net.ServicePointManager]::SecurityProtocol
      try {
        if ($PSVersionTable.PSEdition -eq 'Desktop') {
          [Net.ServicePointManager]::SecurityProtocol = $previousProtocol -bor [Net.SecurityProtocolType]::Tls12
        }
        Initialize-DevelopmentPackageProvider -Scope $Scope
        Install-Module @installParameters
      } finally {
        # TLS is process-local; never change the developer's profile or leave session state changed.
        [Net.ServicePointManager]::SecurityProtocol = $previousProtocol
      }
    } else {
      throw 'Nenhum gerenciador de modulos PowerShell disponivel para instalar dependencias.'
    }

    $resolved = Get-DevelopmentDependency -Name $Module.Name -Version $Module.RequiredVersion -ModuleRoot $ModuleRoot
    if (-not $resolved) {
      throw "Falha ao instalar $($Module.Name) $($Module.RequiredVersion) em $Scope ($ModuleRoot)."
    }
    $source = 'installed'
  }

  return [pscustomobject]@{
    Name = $Module.Name
    Version = $resolved.Version.ToString()
    Source = $source
    Scope = $Scope
    ModuleBase = $resolved.ModuleBase
  }
}

function Test-DevelopmentElevation {
  [CmdletBinding()]
  param()
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  try {
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } finally {
    $identity.Dispose()
  }
}

function Initialize-DevelopmentPackageProvider {
  [CmdletBinding()]
  param([string]$Scope)
  $minimumVersion = [version]'2.8.5.201'
  # Listing all local providers avoids an online search/prompt when NuGet is absent.
  $available = @(Get-PackageProvider -ListAvailable -ErrorAction Stop |
    Where-Object { $_.Name -eq 'NuGet' -and [version]$_.Version -ge $minimumVersion })
  if ($available.Count -eq 0) {
    Write-Verbose "Instalando provedor NuGet em $Scope."
    $null = Install-PackageProvider -Name NuGet -MinimumVersion $minimumVersion.ToString() -Scope $Scope -Force -ErrorAction Stop
    $available = @(Get-PackageProvider -ListAvailable -ErrorAction Stop |
      Where-Object { $_.Name -eq 'NuGet' -and [version]$_.Version -ge $minimumVersion })
    if ($available.Count -eq 0) { throw 'A instalacao do provedor NuGet nao disponibilizou a versao minima 2.8.5.201.' }
  }
}

function Initialize-DevelopmentEnvironment {
  [CmdletBinding()]
  param(
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser'
  )

  $moduleRoot = Get-DevelopmentModuleRoot -Scope $Scope
  foreach ($module in @(
    @{ Name = 'Pester'; RequiredVersion = [version]'5.7.1' },
    @{ Name = 'PSScriptAnalyzer'; RequiredVersion = [version]'1.24.0' }
  )) {
    Install-DevelopmentDependency -Module $module -Scope $Scope -ModuleRoot $moduleRoot
  }
}

Export-ModuleMember -Function Initialize-DevelopmentEnvironment, Get-DevelopmentModuleRoot
