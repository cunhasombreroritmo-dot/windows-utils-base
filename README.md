# windows-utils-base

Base para futuros utilitarios e automacoes desktop no Windows.

## Status

O bot legado de Capybara Clicker foi removido do codigo principal. O repositorio agora funciona como uma base organizada para trabalho futuro, com convencoes de colaboracao e fluxo Git/GitHub ja preparadas.

## Estrutura

- `.github/`: templates de issue e PR, dono padrao e workflow de higiene do repositorio.
- `.editorconfig`: convencoes de edicao compartilhadas.
- `.gitattributes`: normalizacao de finais de linha para Windows e Markdown.
- `PSScriptAnalyzerSettings.psd1`: configuracao compartilhada de lint para scripts PowerShell.
- `CONTRIBUTING.md`: regras curtas para branch, commit e pull request.
- `scripts/bootstrap-dev.ps1`: instala os modulos recomendados de desenvolvimento.
- `scripts/lint.ps1`: executa o lint da base com PSScriptAnalyzer.
- `scripts/new-utility.ps1`: cria a estrutura padrao para um novo utilitario.
- `scripts/test.ps1`: roda a suite Pester da base.
- `utilities/`: area onde cada novo utilitario entra com `src/`, `tests/` e `README.md`.

## Fluxo recomendado

1. Crie uma branch curta a partir de `main`.
2. Prepare o ambiente com `./scripts/bootstrap-dev.ps1`.
3. Gere a base de um novo utilitario com `./scripts/new-utility.ps1 -Name <nome>`.
4. Rode `./scripts/lint.ps1` e `./scripts/test.ps1` antes de abrir PR.
5. Abra um draft PR cedo, mesmo antes de terminar a implementacao.
6. Mantenha cada PR focado em uma unica mudanca.
7. So faca merge depois que a revisao e os checks do GitHub passarem.

## Estado atual

Os utilitarios ativos desta base sao `clipboard-helper`, para historico de clipboard, e `download-organizer`, para organizar a pasta Downloads por categoria. Novos utilitarios entram pela pasta `utilities/` usando o mesmo padrao.

## Como iniciar um utilitario

Exemplo:

```powershell
./scripts/new-utility.ps1 -Name clipboard-helper
```

Isso cria:

- `utilities/clipboard-helper/README.md`
- `utilities/clipboard-helper/src/`
- `utilities/clipboard-helper/tests/`

## Utilitario atual

Utilitarios atuais:

- `utilities/clipboard-helper`: historico local de clipboard com comandos `save`, `list`, `copy`, `remove`, `clear` e `path`
- `utilities/download-organizer`: organizacao da pasta Downloads com comandos `preview`, `apply`, `undo` e `path`

## Qualidade local

Use estes comandos na raiz:

```powershell
./scripts/bootstrap-dev.ps1
./scripts/lint.ps1
./scripts/test.ps1
```

## Licenca

Este projeto esta licenciado sob a licenca MIT. Veja o arquivo `LICENSE`.
