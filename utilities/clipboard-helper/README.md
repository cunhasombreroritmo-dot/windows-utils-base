# clipboard-helper

Utilitario PowerShell para salvar, listar, restaurar e limpar itens de texto da area de transferencia no Windows.

## Objetivo

Guardar trechos de texto copiados com rapidez e permitir reaproveitamento sem depender de procurar manualmente em varias fontes.

## Uso

Salvar o texto atual da area de transferencia:

```powershell
.\clipboard-helper.ps1 save
```

Salvar texto explicito sem depender do clipboard atual:

```powershell
.\clipboard-helper.ps1 save -Text "exemplo" -Label "nota"
```

Listar o historico salvo:

```powershell
.\clipboard-helper.ps1 list
```

Copiar de volta o item mais recente:

```powershell
.\clipboard-helper.ps1 copy
```

Copiar um item especifico pelo `Id`:

```powershell
.\clipboard-helper.ps1 copy -Id abc123def456
```

Remover um item:

```powershell
.\clipboard-helper.ps1 remove -Id abc123def456
```

Limpar todo o historico:

```powershell
.\clipboard-helper.ps1 clear
```

Ver o caminho do arquivo de persistencia:

```powershell
.\clipboard-helper.ps1 path
```

Por padrao o historico fica em:

`%LOCALAPPDATA%\WindowsUtilsBase\clipboard-helper\history.json`

## Validacao

Rode o smoke test local:

```powershell
.\tests\clipboard-helper-smoke.ps1
```

## Estrutura

- `clipboard-helper.ps1`: ponto de entrada do utilitario
- `src/ClipboardHelper.psm1`: funcoes de persistencia e manipulacao do historico
- `tests/clipboard-helper-smoke.ps1`: validacao rapida do fluxo principal
