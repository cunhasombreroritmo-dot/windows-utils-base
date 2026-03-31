param(
  [Parameter(Mandatory = $true)]
  [string]$Name
)

$ErrorActionPreference = 'Stop'

if ($Name -notmatch '^[a-z0-9][a-z0-9-]*$') {
  throw "Use apenas letras minusculas, numeros e hifens no nome do utilitario."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$utilityRoot = Join-Path $repoRoot "utilities\$Name"

if (Test-Path $utilityRoot) {
  throw "O utilitario '$Name' ja existe em $utilityRoot."
}

$paths = @(
  $utilityRoot,
  (Join-Path $utilityRoot 'src'),
  (Join-Path $utilityRoot 'tests')
)

foreach ($path in $paths) {
  New-Item -ItemType Directory -Path $path -Force | Out-Null
}

$readmePath = Join-Path $utilityRoot 'README.md'
$readme = @"
# $Name

Resumo curto do utilitario.

## Objetivo

Descreva o problema que este utilitario resolve.

## Uso

Documente aqui como executar, testar e empacotar.

## Estrutura

- `src/`: codigo principal
- `tests/`: testes e validacoes
"@

Set-Content -LiteralPath $readmePath -Value $readme
Set-Content -LiteralPath (Join-Path $utilityRoot 'src\.gitkeep') -Value ''
Set-Content -LiteralPath (Join-Path $utilityRoot 'tests\.gitkeep') -Value ''

Write-Output "Utility scaffold created at $utilityRoot"
