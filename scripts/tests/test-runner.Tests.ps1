BeforeAll {
  $runnerPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'test.ps1'
  $enginePath = (Get-Process -Id $PID).Path

  function Invoke-TestRunnerFixture {
    param([string]$Content)
    $fixture = Join-Path $TestDrive (([guid]::NewGuid().ToString('N')) + '.Tests.ps1')
    [IO.File]::WriteAllText($fixture, $Content, [Text.UTF8Encoding]::new($false))
    # Capture failed child processes without stopping the parent Pester test.
    $ErrorActionPreference = 'Continue'
    $output = @(& $enginePath -NoProfile -NonInteractive -File $runnerPath -Path $fixture 2>&1)
    $code = $LASTEXITCODE
    return [pscustomobject]@{ ExitCode = $code; Output = ($output -join [Environment]::NewLine) }
  }
}

Describe 'test runner exit contract' {
  It 'returns nonzero on a failed test' {
    $result = Invoke-TestRunnerFixture -Content "Describe 'fixture' { It 'fails' { 1 | Should -Be 2 } }"
    $result.ExitCode | Should -Not -Be 0
    $result.Output | Should -Not -Match 'PESTER_OK'
  }

  It 'returns nonzero on a discovery failure with zero failed tests' {
    $result = Invoke-TestRunnerFixture -Content "throw 'discovery sentinel'"
    $result.ExitCode | Should -Not -Be 0
    $result.Output | Should -Match 'discovery sentinel'
    $result.Output | Should -Not -Match 'PESTER_OK'
  }

  It 'returns nonzero on a failed BeforeAll block' {
    $result = Invoke-TestRunnerFixture -Content "Describe 'fixture' { BeforeAll { throw 'setup sentinel' }; It 'never runs' { 1 | Should -Be 1 } }"
    $result.ExitCode | Should -Not -Be 0
    $result.Output | Should -Match 'setup sentinel'
    $result.Output | Should -Not -Match 'PESTER_OK'
  }

  It 'rejects a suite consisting only of skipped scaffold tests' {
    $result = Invoke-TestRunnerFixture -Content "Describe 'fixture' { It 'placeholder' { Set-ItResult -Skipped -Because 'pending' } }"
    $result.ExitCode | Should -Not -Be 0
    $result.Output | Should -Not -Match 'PESTER_OK'
  }

  It 'rejects an empty test file' {
    $result = Invoke-TestRunnerFixture -Content ''
    $result.ExitCode | Should -Not -Be 0
    $result.Output | Should -Not -Match 'PESTER_OK'
  }

  It 'rejects skipped placeholders even when another test passes' {
    $result = Invoke-TestRunnerFixture -Content "Describe 'fixture' { It 'passes' { 1 | Should -Be 1 }; It 'placeholder' { Set-ItResult -Skipped -Because 'pending' } }"
    $result.ExitCode | Should -Not -Be 0
    $result.Output | Should -Not -Match 'PESTER_OK'
  }

  It 'returns zero only after running passing tests' {
    $result = Invoke-TestRunnerFixture -Content "Describe 'fixture' { It 'passes' { 1 | Should -Be 1 } }"
    $result.ExitCode | Should -Be 0
    $result.Output | Should -Match 'PESTER_OK \(1 testes aprovados\)'
  }
}
