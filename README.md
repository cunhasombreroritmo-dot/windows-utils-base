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

Os utilitarios suportam Windows PowerShell 5.1 e PowerShell 7 no Windows. O bootstrap usa versoes fixas de Pester (5.7.1) e PSScriptAnalyzer (1.24.0), sem alterar permanentemente a politica de confianca dos repositorios de modulos.

O escopo padrao e `CurrentUser`. Use `./scripts/bootstrap-dev.ps1 -Scope AllUsers` em uma sessao elevada para instalar para todos os usuarios. O bootstrap reaproveita somente a versao exigida no diretorio do escopo escolhido e verifica esse mesmo destino depois da instalacao. Uma copia em outro escopo ou em uma entrada personalizada de `PSModulePath` nao satisfaz essa verificacao. A saida mostra o escopo e o caminho real; `-PassThru` retorna objetos para automacao.

Os destinos seguem o motor que executa o bootstrap: `Documents/WindowsPowerShell/Modules` e `Program Files/WindowsPowerShell/Modules` no 5.1; `Documents/PowerShell/Modules` e `Program Files/PowerShell/Modules` no 7. A pasta Documentos redirecionada e respeitada. Execute o bootstrap em cada motor que pretende usar.

Quando `Install-PSResource` esta disponivel, ele tem preferencia; caso contrario, o bootstrap usa `Install-Module`. `-TrustRepository` no primeiro caminho e `-Force` no segundo dispensam a confirmacao de confianca apenas para a operacao. `SkipPublisherCheck` e restrito ao Pester no segundo caminho para compatibilidade com o Pester antigo do Windows. Esses parametros nao configuram o PSGallery como permanentemente confiavel. A instalacao deixa os modulos no disco e pode inicializar o armazenamento do gerenciador; a promessa acima se refere a politica de confianca, nao a ausencia de arquivos persistentes.

No Windows PowerShell 5.1, o caminho com PowerShellGet depende de um provedor NuGet disponivel e acesso ao PSGallery por TLS 1.2 ou superior. Falhas de permissao, rede, gerenciador ou instalacao interrompem o bootstrap; ele nao troca silenciosamente de gerenciador depois de uma falha. As versoes das dependencias sao fixas, mas os gerenciadores sao os disponiveis no ambiente.

Use estes comandos na raiz:

```powershell
./scripts/bootstrap-dev.ps1
./scripts/lint.ps1
./scripts/test.ps1
```

O runner inclui `utilities/` e `scripts/tests/`, falha em erros de descoberta/setup e recusa suites vazias ou com testes ignorados, inconclusivos ou nao executados. O scaffold cria um teste ignorado que precisa ser implementado antes de a validacao passar. Use `-Path` para selecionar arquivos/pastas e `-ResultPath test-results.xml` para exportar resultados NUnit. O workflow executa lint e testes nas duas versoes do PowerShell e guarda os resultados como artefatos.

Os testes do bootstrap usam modulos ficticios locais e instaladores simulados para exercitar ambos os gerenciadores, ambos os escopos, reaproveitamento e falhas sem instalar pacotes reais. Separadamente, `scripts/verify-bootstrap.ps1` faz o bootstrap real em `CurrentUser` e compara a confianca e o endereco do PSGallery antes/depois nos gerenciadores disponiveis. O CI executa essa verificacao nos dois motores; esse teste de integracao nao cobre uma instalacao real em `AllUsers` nem todo ambiente inicial de Windows 5.1.

## Licenca

Este projeto esta licenciado sob a licenca MIT. Veja o arquivo `LICENSE`.
