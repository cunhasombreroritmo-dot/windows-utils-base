# AGENTS.md

## Objetivo do projeto

AIgram e um monorepo full-stack para uma rede social estilo Instagram com usuario humano e personas de IA. O app combina frontend Next.js, APIs, persistencia Prisma/PostgreSQL, simulacao social, notificacoes, chat, upload local de midia e provedor de IA com fallback mock.

## Estrutura do repositorio

- `apps/web/`: aplicacao Next.js 16, rotas App Router, componentes React, APIs e servicos server-side.
- `apps/web/src/app/`: rotas de UI e handlers de API.
- `apps/web/src/components/`: componentes de interface por dominio e componentes de UI compartilhados.
- `apps/web/src/modules/`: contratos e tipos por dominio.
- `apps/web/src/server/`: data access, repositorios, servicos, storage e regras server-only.
- `packages/ai/`: contratos e provedores de IA mock/OpenAI.
- `packages/config/`: configuracoes compartilhadas.
- `packages/database/`: Prisma 7, schema, seed, cliente e dados demo.
- `packages/simulation/`: motor e runner da simulacao social.
- `scripts/`: utilitarios de manutencao do repositorio.
- `utilities/`: utilitarios independentes com README, `src/` e `tests/`.
- `.github/workflows/`: validacoes de CI e higiene do repositorio.

## Ambiente principal

- Ambiente principal deste projeto nesta maquina: Windows, com PowerShell ou `cmd.exe`.
- Para comandos npm no Windows, prefira `npm.cmd` quando estiver executando via `cmd.exe`/automacao, por exemplo: `cmd.exe /c npm.cmd run check`.
- Nao use WSL para validar este projeto enquanto `node` e `npm` nao estiverem disponiveis nele.
- O repositorio fica dentro do OneDrive; builds, typecheck e operacoes com muitos arquivos podem ficar lentos ou travar se a sincronizacao estiver ocupada.

## Comandos principais

- Instalar dependencias para desenvolvimento: `npm install`
- Instalar dependencias em CI/reproducao limpa: `npm ci`
- Rodar localmente: `npm run dev`
- Build: `npm run build`
- Lint: `npm run lint`
- Typecheck: `npm run typecheck`
- Check combinado: `npm run check`
- Teste automatizado top-level: nao encontrado
- Teste de integracao Studio: `npm run studio:test:integration`
- Smoke staging Studio: `npm run studio:smoke:staging` somente com segredos Redis configurados
- Formatacao/check de formato: nao encontrado; melhoria sugerida: adicionar `format` e `format:check` se o projeto adotar Prettier ou Biome
- Prisma generate: `npm run db:generate`
- Prisma migrate local: `npm run db:migrate`
- Prisma push local: `npm run db:push`
- Seed: `npm run db:seed`
- Simulacao demo: `npm run simulation:demo`

## Padrões de código

- Use TypeScript estrito; preserve `strict`, `noUncheckedIndexedAccess` e `exactOptionalPropertyTypes`.
- Preserve a separacao por dominios em `apps/web/src/modules/*/contracts.ts`.
- Mantenha regras de servidor em `apps/web/src/server/` e evite importar codigo server-only em componentes client.
- Reutilize pacotes internos pelos aliases `@aigram/ai`, `@aigram/config`, `@aigram/database` e `@aigram/simulation`.
- Prefira servicos e repositorios existentes antes de criar novas camadas.
- Mantenha fluxo de dados persistente como fonte da verdade; realtime deve refletir efeitos ja persistidos.
- Trate modos `demo`, `auto` e `database` explicitamente, sem fallback silencioso quando o modo exigir persistencia estrita.
- Ao lidar com IA real, preserve o fallback mock explicito e registre metadados de provider/model/fallback quando o fluxo existente fizer isso.
- Nao grave uploads fora de `apps/web/public/uploads` sem decisao arquitetural documentada.
- Siga `.editorconfig`: UTF-8, LF, 2 espacos e newline final.

## Regras para o Codex

- Antes de editar, leia os arquivos diretamente relacionados ao fluxo afetado.
- Planeje antes de mudancas grandes, multi-pacote ou que alterem comportamento publico.
- Faca mudancas pequenas, coesas e reversiveis.
- Nao altere contratos publicos, schema Prisma, rotas API ou comportamento de persistencia sem teste/check proporcional.
- Nao adicione dependencias sem necessidade clara e sem explicar impacto.
- Nao toque em `.env`, segredos, tokens, certificados, chaves ou credenciais.
- Nao execute comandos destrutivos nem limpezas em massa sem aprovacao explicita.
- Nao ignore falhas de teste, lint, typecheck ou build; diagnostique a causa ou documente a limitacao.
- Explique trade-offs quando houver mais de uma solucao viavel.
- Revise `git diff` antes de concluir e destaque riscos restantes.

## Critérios de conclusão

Uma tarefa so esta pronta quando:

- a mudanca resolve o pedido principal;
- os arquivos alterados foram revisados no diff;
- `npm run check` foi executado no Windows, preferencialmente via `npm.cmd`, ou a impossibilidade foi explicada;
- `npm run build` foi executado quando a mudanca afetar app, config, rotas, pacotes compartilhados ou dependencias;
- testes especificos, como `npm run studio:test:integration` ou `npm run simulation:demo`, foram executados quando o fluxo afetado exigir;
- riscos, limitacoes e proximos passos foram documentados.

## Segurança

- Nunca exponha, copie, mova ou imprima valores de `.env`, tokens, API keys, URLs com credenciais ou certificados.
- Use modo mock por padrao para IA quando a tarefa nao exigir provedor real.
- Nao use rede, instalacao de pacotes ou servicos externos sem necessidade e justificativa.
- Nao rode `git reset --hard`, `git clean -fd`, force push, remocao recursiva ou comandos equivalentes sem aprovacao explicita.
- Operacoes com banco devem deixar claro se afetam banco local, staging ou producao.
- `studio:smoke:staging` depende de segredos Redis e deve ser tratado como validacao de ambiente, nao como teste local padrao.

## Revisão

- Revise se a mudanca respeita os modos `demo`, `auto` e `database`.
- Procure vazamento de server-only para client components.
- Verifique impactos em schema Prisma, seeds, uploads locais, realtime e simulacao.
- Confirme que novas APIs validam entrada, tratam erros e preservam autorizacao/sessao.
- Para PRs, preencha resumo, motivo, validacao e riscos conforme `.github/PULL_REQUEST_TEMPLATE.md`.
