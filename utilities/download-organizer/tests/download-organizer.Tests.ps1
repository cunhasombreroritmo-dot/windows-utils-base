Describe 'download-organizer' {
  It 'passa no smoke test existente' {
    $output = & (Join-Path $PSScriptRoot 'download-organizer-smoke.ps1')
    @($output) | Should -Contain 'DOWNLOAD_ORGANIZER_SMOKE_OK'
  }
}
