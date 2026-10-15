Set-StrictMode -Version Latest

function Get-ClipboardHelperStorePath {
  [CmdletBinding()]
  param(
    [string]$StorePath
  )

  if ($StorePath) {
    return $StorePath
  }

  $basePath = if ($env:LOCALAPPDATA) {
    $env:LOCALAPPDATA
  } else {
    Join-Path $HOME 'AppData\Local'
  }

  return Join-Path $basePath 'WindowsUtilsBase\clipboard-helper\history.json'
}

function Initialize-ClipboardHelperDirectory {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $parent = Split-Path -Parent $Path
  if (-not (Test-Path $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
}

function Read-ClipboardHistory {
  [CmdletBinding()]
  param(
    [string]$StorePath
  )

  $resolvedStorePath = Get-ClipboardHelperStorePath -StorePath $StorePath
  if (-not (Test-Path $resolvedStorePath)) {
    return @()
  }

  $raw = Get-Content -LiteralPath $resolvedStorePath -Raw
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return @()
  }

  $parsed = $raw | ConvertFrom-Json
  if ($parsed -is [System.Array]) {
    return @($parsed)
  }

  return @($parsed)
}

function Write-ClipboardHistory {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [System.Collections.IEnumerable]$History,

    [string]$StorePath
  )

  $resolvedStorePath = Get-ClipboardHelperStorePath -StorePath $StorePath
  Initialize-ClipboardHelperDirectory -Path $resolvedStorePath

  $historyItems = @($History)
  $json = if ($historyItems.Count -eq 0) {
    '[]'
  } else {
    $historyItems | ConvertTo-Json -Depth 4
  }

  Set-Content -LiteralPath $resolvedStorePath -Value $json

  return $resolvedStorePath
}

function Get-ClipboardTextFromSystem {
  [CmdletBinding()]
  param()

  if (-not (Get-Command Get-Clipboard -ErrorAction SilentlyContinue)) {
    throw 'Get-Clipboard nao esta disponivel neste ambiente.'
  }

  $clipboardText = Get-Clipboard -Raw
  if ([string]::IsNullOrWhiteSpace($clipboardText)) {
    throw 'A area de transferencia esta vazia ou nao contem texto.'
  }

  return [string]$clipboardText
}

function Get-ClipboardPreview {
  [CmdletBinding()]
  param(
    [AllowEmptyString()]
    [string]$Text,

    [int]$MaxLength = 72
  )

  $normalized = ($Text -replace '\s+', ' ').Trim()
  if ($normalized.Length -le $MaxLength) {
    return $normalized
  }

  return $normalized.Substring(0, $MaxLength - 3) + '...'
}

function New-ClipboardEntry {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Text,

    [string]$Label
  )

  return [pscustomobject]@{
    Id = [guid]::NewGuid().ToString('N').Substring(0, 12)
    SavedAt = [DateTimeOffset]::Now.ToString('o')
    Label = $Label
    Text = $Text
  }
}

function Save-ClipboardEntry {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Text,

    [string]$Label,
    [string]$StorePath,
    [int]$MaxEntries = 100
  )

  if ([string]::IsNullOrWhiteSpace($Text)) {
    throw 'Nao e possivel salvar um texto vazio.'
  }

  if ($MaxEntries -lt 1) {
    throw 'MaxEntries precisa ser pelo menos 1.'
  }

  $history = @(Read-ClipboardHistory -StorePath $StorePath)
  $resolvedStorePath = Get-ClipboardHelperStorePath -StorePath $StorePath

  if ($history.Count -gt 0 -and $history[0].Text -eq $Text) {
    return [pscustomobject]@{
      Action = 'unchanged'
      Entry = $history[0]
      StorePath = $resolvedStorePath
      Count = $history.Count
    }
  }

  $entry = New-ClipboardEntry -Text $Text -Label $Label
  $updatedHistory = @($entry) + $history

  if ($updatedHistory.Count -gt $MaxEntries) {
    $updatedHistory = $updatedHistory[0..($MaxEntries - 1)]
  }

  $writtenPath = Write-ClipboardHistory -History $updatedHistory -StorePath $StorePath
  return [pscustomobject]@{
    Action = 'saved'
    Entry = $entry
    StorePath = $writtenPath
    Count = $updatedHistory.Count
  }
}

function Get-ClipboardHistoryView {
  [CmdletBinding()]
  param(
    [string]$StorePath
  )

  $history = @(Read-ClipboardHistory -StorePath $StorePath)
  foreach ($entry in $history) {
    [pscustomobject]@{
      Id = $entry.Id
      SavedAt = $entry.SavedAt
      Label = $entry.Label
      Length = $entry.Text.Length
      Preview = Get-ClipboardPreview -Text $entry.Text
    }
  }
}

function Find-ClipboardEntry {
  [CmdletBinding()]
  param(
    [string]$Id,
    [string]$StorePath
  )

  $history = @(Read-ClipboardHistory -StorePath $StorePath)
  if ($history.Count -eq 0) {
    return $null
  }

  if (-not $Id) {
    return $history[0]
  }

  foreach ($entry in $history) {
    if ($entry.Id -eq $Id) {
      return $entry
    }
  }

  return $null
}

function Copy-ClipboardEntry {
  [CmdletBinding()]
  param(
    [string]$Id,
    [string]$StorePath
  )

  if (-not (Get-Command Set-Clipboard -ErrorAction SilentlyContinue)) {
    throw 'Set-Clipboard nao esta disponivel neste ambiente.'
  }

  $entry = Find-ClipboardEntry -Id $Id -StorePath $StorePath
  if (-not $entry) {
    throw 'Nenhum item correspondente foi encontrado no historico.'
  }

  Set-Clipboard -Value $entry.Text
  return [pscustomobject]@{
    Action = 'copied'
    Entry = $entry
  }
}

function Remove-ClipboardEntry {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Id,

    [string]$StorePath
  )

  $history = @(Read-ClipboardHistory -StorePath $StorePath)
  $remaining = @($history | Where-Object { $_.Id -ne $Id })

  if ($remaining.Count -eq $history.Count) {
    throw 'Nenhum item correspondente foi encontrado para remocao.'
  }

  $writtenPath = Write-ClipboardHistory -History $remaining -StorePath $StorePath
  return [pscustomobject]@{
    Action = 'removed'
    RemovedId = $Id
    Count = $remaining.Count
    StorePath = $writtenPath
  }
}

function Clear-ClipboardHistory {
  [CmdletBinding()]
  param(
    [string]$StorePath
  )

  $writtenPath = Write-ClipboardHistory -History @() -StorePath $StorePath
  return [pscustomobject]@{
    Action = 'cleared'
    Count = 0
    StorePath = $writtenPath
  }
}

Export-ModuleMember -Function @(
  'Clear-ClipboardHistory',
  'Copy-ClipboardEntry',
  'Find-ClipboardEntry',
  'Get-ClipboardHelperStorePath',
  'Get-ClipboardHistoryView',
  'Get-ClipboardPreview',
  'Get-ClipboardTextFromSystem',
  'Read-ClipboardHistory',
  'Remove-ClipboardEntry',
  'Save-ClipboardEntry'
)
