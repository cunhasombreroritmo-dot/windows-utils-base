Describe 'disposable CI environment guards' {
  It 'refuses <Script> outside a hosted runner before changing the machine' -ForEach @(
    @{ Script = 'prepare-bootstrap.ps1' },
    @{ Script = 'verify-first-use.ps1' },
    @{ Script = 'invoke-allusers-consumer.ps1' }
  ) {
    $previousActions = $env:GITHUB_ACTIONS
    $previousEnvironment = $env:RUNNER_ENVIRONMENT
    try {
      $env:GITHUB_ACTIONS = ''
      $env:RUNNER_ENVIRONMENT = ''
      $path = Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'ci') $Script
      { & $path } | Should -Throw '*runner*'
    } finally {
      $env:GITHUB_ACTIONS = $previousActions
      $env:RUNNER_ENVIRONMENT = $previousEnvironment
    }
  }
}
