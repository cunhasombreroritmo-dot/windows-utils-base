# Fluxo de trabalho do Codex no AIgram

Este guia complementa `AGENTS.md` com um fluxo pratico para tarefas futuras neste repositorio.

## Diagnostico inicial

1. Confirme que o diretorio de trabalho e `pc project`, nao apenas `Documentos`.
2. Rode `git status --short` e preserve mudancas existentes que nao forem da tarefa.
3. Leia `README.md`, `package.json` e os manifests dos workspaces afetados.
4. Localize arquivos relacionados com busca textual antes de editar.
5. Nao abra nem copie `.env` ou arquivos com segredos.
6. Use Windows como ambiente principal. Prefira PowerShell ou `cmd.exe`; em automacao, execute npm como `cmd.exe /c npm.cmd run <script>`.
7. Nao use WSL para checks deste projeto enquanto `node` e `npm` nao estiverem instalados e funcionais nele.
8. Considere que o checkout esta dentro do OneDrive; se comandos ficarem lentos ou travarem, verifique sincronizacao e arquivos bloqueados antes de mudar codigo.

## Perfis operacionais sugeridos

### Perfil seguro

Use para tarefas de investigacao, revisao, documentacao e mudancas pequenas.

- Permissao: sandbox com escrita no workspace.
- Aprovacao: pedir aprovacao para rede, instalacao, escrita fora do repo e comandos destrutivos.
- Checks minimos: `npm run check` quando houver qualquer mudanca em codigo/config.

### Perfil desenvolvimento

Use para features e correcoes normais no app.

- Permissao: sandbox com escrita no workspace.
- Aprovacao: manter para rede, instalacao e efeitos fora do repo.
- Checks recomendados: `npm run check`, `npm run build` e teste especifico do dominio alterado.
- Para database: usar banco local ou Prisma Dev; nunca assumir staging/producao.

### Perfil automacao

Use apenas quando a tarefa exigir execucao repetida ou validacao integrada.

- Permissao: manter aprovacao para qualquer acesso externo.
- Logs e artefatos: preferir `.tmp/`, `test-results/` ou caminhos ja ignorados.
- Staging: `npm run studio:smoke:staging` somente com segredos configurados e autorizacao clara.

## Sequencia recomendada por tipo de tarefa

### Mudanca de UI

1. Leia componente, contrato do modulo e rota afetada.
2. Preserve componentes compartilhados em `apps/web/src/components/ui`.
3. Rode `npm run lint` e `npm run typecheck`.
4. Rode `npm run build` se a mudanca afetar rotas, server actions ou imports compartilhados.

### Mudanca server/API

1. Leia contrato em `apps/web/src/modules/*/contracts.ts`.
2. Leia service/repository/data-access relacionado.
3. Verifique autenticacao, autorizacao, validacao e modo de dados.
4. Rode `npm run check` e `npm run build`.

### Mudanca Prisma/database

1. Leia `packages/database/prisma/schema.prisma`, seed e tipos exportados.
2. Explique se a mudanca exige migrate, push ou seed.
3. Rode `npm run db:generate` quando alterar schema.
4. Rode `npm run typecheck` e teste o fluxo que consome o dado.

### Mudanca de simulacao

1. Leia `packages/simulation/src/*` e contratos que chamam a simulacao.
2. Rode `npm run simulation:demo`.
3. Rode `npm run check` se houver alteracao em TypeScript.

### Mudanca de IA

1. Leia `packages/ai/src/*` e `apps/web/src/server/services/ai/provider.ts`.
2. Preserve provider mock como caminho seguro local.
3. Nao exija `OPENAI_API_KEY` para fluxos que devem funcionar em demo.
4. Valide metadados de provider, modelo e fallback quando aplicavel.

## Validacao

Use a menor combinacao suficiente, mas nao substitua erro por silencio.

- Comandos npm no Windows: prefira `npm.cmd`, por exemplo `cmd.exe /c npm.cmd run check`.
- Documentacao apenas: revisar diff e, se possivel, executar checks leves de consistencia.
- Codigo frontend/backend: `npm run check`.
- Mudanca ampla ou em build/runtime: `npm run build`.
- Simulacao: `npm run simulation:demo`.
- Studio media: `npm run studio:test:integration`.
- Staging Redis: `npm run studio:smoke:staging` somente com ambiente autorizado.

## Criterios de revisao

- O diff e pequeno e focado?
- A mudanca respeita arquitetura e nomes existentes?
- Entradas externas sao validadas?
- Erros sao tratados de forma previsivel?
- O fluxo funciona em `demo` quando isso for esperado?
- O modo `database` evita fallback silencioso?
- Nao houve vazamento de segredo, path local sensivel ou artefato gerado?
- Os checks relevantes foram executados e registrados no resumo final?
