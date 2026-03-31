# download-organizer

Utilitario PowerShell para organizar a pasta Downloads por categoria de arquivo com modo de previsao antes de mover.

## Objetivo

Reduzir a desordem da pasta Downloads agrupando arquivos em subpastas previsiveis como `Documents`, `Images`, `Installers`, `Archives`, `Audio`, `Video`, `Code` e `Other`.

## Uso

Prever o que sera movido sem alterar nada:

```powershell
.\download-organizer.ps1 preview
```

Aplicar a organizacao na pasta Downloads padrao:

```powershell
.\download-organizer.ps1 apply
```

Usar uma pasta especifica como origem:

```powershell
.\download-organizer.ps1 preview -SourcePath "C:\Users\Nicolas\Downloads"
```

Desfazer a ultima execucao registrada no manifesto:

```powershell
.\download-organizer.ps1 undo
```

Ver o caminho do manifesto da ultima execucao:

```powershell
.\download-organizer.ps1 path
```

Por padrao o manifesto fica em:

`%LOCALAPPDATA%\WindowsUtilsBase\download-organizer\last-run.json`

## Validacao

Rode o teste de integracao local:

```powershell
.\tests\download-organizer-smoke.ps1
```

## Estrutura

- `download-organizer.ps1`: ponto de entrada com comandos `preview`, `apply`, `undo` e `path`
- `src/DownloadOrganizer.psm1`: regras de categoria, plano de organizacao e reversao
- `tests/download-organizer-smoke.ps1`: validacao do fluxo completo em pasta temporaria
