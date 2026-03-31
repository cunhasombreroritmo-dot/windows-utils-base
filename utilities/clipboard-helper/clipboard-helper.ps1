[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet('save', 'list', 'copy', 'remove', 'clear', 'path')]
  [string]$Command = 'list',

  [string]$Id,
  [string]$Label,
  [string]$Text,
  [string]$StorePath,
  [int]$MaxEntries = 100
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'src\ClipboardHelper.psm1') -Force

switch ($Command) {
  'save' {
    $textToSave = $Text
    if (-not $PSBoundParameters.ContainsKey('Text')) {
      $textToSave = Get-ClipboardTextFromSystem
    }

    $result = Save-ClipboardEntry -Text $textToSave -Label $Label -StorePath $StorePath -MaxEntries $MaxEntries
    [pscustomobject]@{
      Action = $result.Action
      Id = $result.Entry.Id
      SavedAt = $result.Entry.SavedAt
      Label = $result.Entry.Label
      Length = $result.Entry.Text.Length
      Preview = Get-ClipboardPreview -Text $result.Entry.Text
      StorePath = $result.StorePath
      Count = $result.Count
    }
  }

  'list' {
    Get-ClipboardHistoryView -StorePath $StorePath
  }

  'copy' {
    $result = Copy-ClipboardEntry -Id $Id -StorePath $StorePath
    [pscustomobject]@{
      Action = $result.Action
      Id = $result.Entry.Id
      SavedAt = $result.Entry.SavedAt
      Label = $result.Entry.Label
      Length = $result.Entry.Text.Length
      Preview = Get-ClipboardPreview -Text $result.Entry.Text
    }
  }

  'remove' {
    Remove-ClipboardEntry -Id $Id -StorePath $StorePath
  }

  'clear' {
    Clear-ClipboardHistory -StorePath $StorePath
  }

  'path' {
    Get-ClipboardHelperStorePath -StorePath $StorePath
  }
}
