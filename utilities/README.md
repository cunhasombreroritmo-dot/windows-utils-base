# Utilities

Cada utilitario novo deve viver em uma pasta propria dentro deste diretorio.

Estrutura esperada:

- `utilities/<nome>/README.md`
- `utilities/<nome>/src/`
- `utilities/<nome>/tests/`

Para criar a base automaticamente:

```powershell
./scripts/new-utility.ps1 -Name meu-utilitario
```

Utilitarios ja iniciados:

- `clipboard-helper`: historico simples de textos da area de transferencia com persistencia local
- `download-organizer`: organiza a pasta Downloads por categoria com `preview`, `apply` e `undo`
