# download-organizer

Utilitario para organizar os arquivos da raiz de Downloads em `Documents`, `Images`, `Installers`, `Archives`, `Audio`, `Video`, `Code` e `Other`, com previsao e reversao registrada.

## Requisitos

Windows PowerShell 5.1 ou PowerShell 7 no Windows. Os testes usam arquivos reais em pastas temporarias e sao executados nos dois ambientes pelo CI. A persistencia atomica foi validada em disco local NTFS. Links simbolicos, junctions e outros reparse points, inclusive nos caminhos ancestrais, sao recusados; isso inclui algumas pastas gerenciadas por provedores de nuvem.

## Uso

Execute os exemplos abaixo dentro de `utilities/download-organizer`:

```powershell
# Planejar sem criar pastas ou mover arquivos
.\download-organizer.ps1 preview

# Organizar a Downloads padrao (incluindo redirecionamentos da Known Folder)
.\download-organizer.ps1 apply

# Escolher outra origem e outro manifesto; o manifesto deve ficar fora da origem
.\download-organizer.ps1 preview -SourcePath 'C:\Users\Usuario\Downloads'
.\download-organizer.ps1 apply -SourcePath 'C:\Users\Usuario\Downloads' -ManifestPath 'C:\OrganizerState\last-run.json'

# Desfazer a execucao registrada
.\download-organizer.ps1 undo

# Simular apply ou undo sem gravar ou mover arquivos
.\download-organizer.ps1 apply -WhatIf
.\download-organizer.ps1 undo -WhatIf

# Mostrar o caminho absoluto do manifesto
.\download-organizer.ps1 path
```

Somente arquivos visiveis na raiz da origem sao organizados. Subpastas e arquivos ocultos nao entram no plano. Extensoes desconhecidas ou ausentes ficam em `Other`. Arquivos em uso podem causar uma falha parcial; encerre os programas que os usam antes de organizar a pasta.

Os destinos sao reservados no plano, sem diferenciar maiusculas/minusculas. Colisoes recebem sufixos como `report (1).pdf`. Uma colisao surgida depois do planejamento interrompe a execucao sem sobrescrever o destino. O preview e uma previsao: `apply` recalcula o plano antes de executar.

## Manifesto e recuperacao

O caminho padrao e `%LOCALAPPDATA%\WindowsUtilsBase\download-organizer\last-run.json`. A versao 2 do manifesto guarda tamanho e SHA-256 dos arquivos, estados por entrada e caminhos efetivos de restauracao. A gravacao usa UTF-8 e substituicao atomica; a operacao e registrada antes de cada movimento, permitindo recuperar um movimento concluido mesmo se a gravacao seguinte falhar.

Um `apply` sem arquivos retorna `Action = unchanged`, `Count = 0` e preserva o manifesto anterior. Antes de uma nova execucao com arquivos, o manifesto existente e copiado para `<ManifestPath>.<id>.bak`. Para desfazer uma execucao anterior:

```powershell
.\download-organizer.ps1 undo -ManifestPath 'C:\OrganizerState\last-run.json.<id>.bak'
```

`undo` ignora entradas pendentes e ja restauradas. Ele compara tamanho e hash antes de mover o destino e nunca sobrescreve uma nova origem: usa um nome livre e registra esse nome em `RestorePath`. Repetir `undo` nao move arquivos novos colocados nos destinos de entradas ja restauradas.

O retorno informa `Count` (arquivos realmente restaurados nesta chamada), `SkippedCount` e `Skipped` (caminho e motivo). `Action = undo-partial` indica arquivos ausentes, alterados ou um estado ambiguo. Esses arquivos permanecem onde estao; confira os motivos e o manifesto antes de tentar novamente. Estados de movimento interrompido so sao recuperados quando o arquivo e os caminhos permitem confirmar a operacao.

Uma chave de bloqueio em `<ManifestPath>.lock` impede operacoes simultaneas no mesmo manifesto. O arquivo vazio permanece depois da execucao e pode ser reutilizado; nao o remova durante uma operacao. Backups nao sao removidos automaticamente.

Manifestos antigos, sem fingerprints, sao preservados em backup quando substituidos, mas a reversao automatica os recusa. Use seus caminhos como referencia para recuperacao manual. Nao edite manifestos durante uma operacao nem execute organizadores concorrentes com manifestos diferentes sobre a mesma origem. Hashes confirmam o conteudo registrado, nao a identidade fisica de um arquivo substituido por outro identico.

## Validacao

Na raiz do repositorio:

```powershell
.\scripts\bootstrap-dev.ps1
.\scripts\lint.ps1
.\scripts\test.ps1
```

Para executar apenas este utilitario ou gravar resultados NUnit:

```powershell
.\scripts\test.ps1 -Path .\utilities\download-organizer\tests
.\scripts\test.ps1 -ResultPath test-results.xml
```

O teste de integracao independente continua disponivel:

```powershell
.\utilities\download-organizer\tests\download-organizer-smoke.ps1
```

A suite cobre o fluxo completo, nomes Unicode e colchetes, colisoes, repeticao e falhas parciais, checkpoints, bloqueios reais de arquivos, manifesto invalido, junctions e comandos da interface.
