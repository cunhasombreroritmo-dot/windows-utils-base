Describe 'clipboard-helper' {
  It 'passa no smoke test existente' {
    $output = & (Join-Path $PSScriptRoot 'clipboard-helper-smoke.ps1')
    @($output) | Should -Contain 'CLIPBOARD_HELPER_SMOKE_OK'
  }
}
