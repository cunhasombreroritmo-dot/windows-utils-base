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

O workflow de qualidade valida Windows PowerShell 5.1 e PowerShell 7 com as mesmas versoes de dependencias. Implemente o teste ignorado gerado pelo scaffold: suites vazias, com placeholders ignorados ou falhas de descoberta/setup sao reprovadas. Novas operacoes que movem dados precisam de testes para colisoes, falhas parciais e repeticao da reversao, alem do fluxo de sucesso.

Para mudancas no bootstrap, mantenha os testes de ambos os gerenciadores e escopos em `scripts/tests/`. Use modulos ficticios e instaladores simulados nos testes unitarios; eles nao devem instalar pacotes no perfil do desenvolvedor. A etapa de integracao do CI executa `scripts/verify-bootstrap.ps1` e deve preservar a confianca e o endereco registrado do PSGallery.

O CI deve validar instalacao real e reutilizacao nos dois motores e escopos, importacao `AllUsers` por outro usuario comum, e primeiro uso dos componentes Windows 5.1 originais com NuGet ausente. Registre as limitacoes da imagem hospedada; nao declare uma VM Windows cliente limpa como validada a partir desses jobs. Scripts em `scripts/ci/` que preparam o ambiente ou criam usuarios sao restritos a runners descartaveis hospedados pelo GitHub.

Antes de retirar o draft, revise o diff, conclua a implementacao e confirme os checks do head atual, incluindo as integracoes exigidas para bootstrap. Atualize a descricao com evidencias e riscos. O merge continua dependendo tambem de revisao aprovada.
