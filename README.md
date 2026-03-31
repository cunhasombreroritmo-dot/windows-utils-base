# windows-utils-base

Base para futuros utilitarios e automacoes desktop no Windows.

## Status

O bot legado de Capybara Clicker foi removido do codigo principal. O repositorio agora funciona como uma base organizada para trabalho futuro, com convencoes de colaboracao e fluxo Git/GitHub ja preparadas.

## Estrutura

- `.github/`: templates de issue e PR, dono padrao e workflow de higiene do repositorio.
- `.editorconfig`: convencoes de edicao compartilhadas.
- `.gitattributes`: normalizacao de finais de linha para Windows e Markdown.
- `CONTRIBUTING.md`: regras curtas para branch, commit e pull request.
- `scripts/new-utility.ps1`: cria a estrutura padrao para um novo utilitario.
- `utilities/`: area onde cada novo utilitario entra com `src/`, `tests/` e `README.md`.

## Fluxo recomendado

1. Crie uma branch curta a partir de `main`.
2. Gere a base de um novo utilitario com `./scripts/new-utility.ps1 -Name <nome>`.
3. Abra um draft PR cedo, mesmo antes de terminar a implementacao.
4. Mantenha cada PR focado em uma unica mudanca.
5. So faca merge depois que a revisao e os checks do GitHub passarem.

## Estado atual

O primeiro utilitario ativo desta base e `clipboard-helper`, focado em salvar, listar e restaurar textos da area de transferencia. Novos utilitarios entram pela pasta `utilities/` usando o mesmo padrao.

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

Primeiro utilitario real:

- `utilities/clipboard-helper`: historico local de clipboard com comandos `save`, `list`, `copy`, `remove`, `clear` e `path`

## Licenca

Este projeto esta licenciado sob a licenca MIT. Veja o arquivo `LICENSE`.
