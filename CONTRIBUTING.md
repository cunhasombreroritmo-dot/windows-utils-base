# Contributing

## Branches

Use branches curtas e descritivas:

- `feature/...` para funcionalidade nova
- `fix/...` para correcao
- `docs/...` para documentacao
- `chore/...` para manutencao
- `codex/...` quando a mudanca for conduzida pelo Codex

Quando um novo utilitario for comecar, gere a base com:

```powershell
./scripts/bootstrap-dev.ps1
./scripts/new-utility.ps1 -Name nome-do-utilitario
```

## Commits

- Use mensagens curtas, no imperativo.
- Evite misturar limpeza geral com mudanca funcional no mesmo commit.

## Pull requests

- Abra como draft quando a mudanca ainda estiver em andamento.
- Explique o que mudou, por que mudou e como foi validado.
- Mantenha o PR pequeno o suficiente para uma revisao rapida.

## Arquivos locais

- Nao versione logs, configuracoes locais, binarios gerados ou artefatos de build.
- Atualize `.gitignore` quando surgir uma nova classe de arquivo local.

## Validacao

Antes de abrir PR, rode:

```powershell
./scripts/lint.ps1
./scripts/test.ps1
```

Os workflows `Repo Hygiene` e `PowerShell Quality` rodam no GitHub para garantir a presenca dos arquivos-base, impedir a volta dos artefatos legados removidos nesta limpeza e validar lint/testes.
