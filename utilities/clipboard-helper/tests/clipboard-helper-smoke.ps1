$ErrorActionPreference = 'Stop'

$utilityRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $utilityRoot 'src\ClipboardHelper.psm1') -Force

$tempRoot = Join-Path $env:TEMP ("clipboard-helper-test-" + [guid]::NewGuid().ToString('N'))
$storePath = Join-Path $tempRoot 'history.json'

try {
  $null = New-Item -ItemType Directory -Path $tempRoot -Force

  $first = Save-ClipboardEntry -Text 'primeiro item' -Label 'a' -StorePath $storePath
  $second = Save-ClipboardEntry -Text 'segundo item' -Label 'b' -StorePath $storePath

  $history = @(Get-ClipboardHistoryView -StorePath $storePath)
  if ($history.Count -ne 2) {
    throw "Esperava 2 itens no historico, encontrei $($history.Count)."
  }

  if ($history[0].Id -ne $second.Entry.Id) {
    throw 'O item mais recente nao ficou no topo do historico.'
  }

  $found = Find-ClipboardEntry -Id $first.Entry.Id -StorePath $storePath
  if (-not $found -or $found.Text -ne 'primeiro item') {
    throw 'Falha ao localizar item salvo pelo Id.'
  }

  $null = Remove-ClipboardEntry -Id $first.Entry.Id -StorePath $storePath
  $afterRemove = @(Get-ClipboardHistoryView -StorePath $storePath)
  if ($afterRemove.Count -ne 1) {
    throw "Esperava 1 item apos remocao, encontrei $($afterRemove.Count)."
  }

  $null = Clear-ClipboardHistory -StorePath $storePath
  $afterClear = @(Get-ClipboardHistoryView -StorePath $storePath)
  if ($afterClear.Count -ne 0) {
    throw "Esperava historico vazio apos limpeza, encontrei $($afterClear.Count)."
  }

  Write-Output 'CLIPBOARD_HELPER_SMOKE_OK'
} finally {
  if (Test-Path $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}
