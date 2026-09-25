# Otimizador-valorant

Script PowerShell para Windows, com painel gráfico, que aplica ajustes de sistema para o VALORANT rodar com menos interferência do Windows. Faz backup do registro antes de alterar qualquer coisa e tem opção de reverter. Também traz um botão pra aplicar ajustes rápidos no meio de uma partida e um botão de status.

O script só altera configurações do Windows. Não interage com o processo do jogo.

## Arquivo

Um único arquivo: `valorant_otimizador.ps1`. Ele mesmo verifica se está rodando como administrador, pede a permissão (UAC) e abre um painel — sem terminal visível, sem `.bat` ou instalador separado.

### Sobre o UAC

O painel sempre precisa rodar como administrador (mexe em `HKLM`), então abrir o `.ps1` direto pede UAC toda vez — é assim que o Windows garante que nenhum programa vira admin sem você confirmar.

Se isso incomoda, dentro do próprio painel tem o botão **CRIAR ATALHO**: como o painel já está rodando elevado nesse momento, ele aproveita e cria uma tarefa agendada (privilégio máximo) e um atalho "Valorant Otimizador" na área de trabalho, sem pedir UAC de novo pra isso. Da próxima vez, clicar nesse atalho abre o painel direto como admin, sem popup — quem inicia o processo é o Agendador de Tarefas do Windows (que já roda com privilégio total), não o pedido normal de elevação. O botão vira **REMOVER ATALHO** pra desfazer.

## Painel

- **Título** — VALORANT / OTIMIZADOR, com botões de minimizar e fechar.
- **Ações rápidas** (esquerda) — quatro botões:
  - **BOOST AGORA** — pra usar com o jogo já aberto, quando o FPS cai no meio de uma partida.
  - **STATUS** — abre uma tela separada com cada ajuste marcado ATIVO/INATIVO, plano de energia, se o VALORANT foi encontrado, se a pasta está excluída no Defender e se o atalho sem UAC está instalado.
  - **REVERTER** — desfaz os ajustes (duas formas, ver abaixo).
  - **CRIAR ATALHO / REMOVER ATALHO** — ver seção acima.
- **Ajustes** (direita) — um checkbox por ajuste, já vem marcado se o ajuste correspondente estiver ativo. Marque o que quiser e clique em **APLICAR SELECIONADOS**.

### O que cada ajuste faz

| Ajuste | Motivo |
| --- | --- |
| Desativar Game DVR | Grava em segundo plano e gasta GPU |
| Ativar Game Mode | Segura atualização de driver e aviso de reinicialização durante a partida |
| Fullscreen exclusivo clássico | Modo exclusivo clássico no lugar do modo otimizado do Windows, e otimizações de janela do DirectX desativadas para o executável do jogo — menos camadas entre o jogo e a tela |
| Ajustar MMCSS (rede/CPU p/ jogos) | Tira o limite de rede e reduz a reserva de CPU para tarefas de fundo |
| Prioridade alta de CPU (VALORANT) | Aplicada pelo kernel na criação do processo, via Image File Execution Options, sem depender de handle externo (o Vanguard restringe isso) |
| Excluir pasta da Riot do Defender | Menos I/O durante o jogo, reduzindo a proteção do antivírus só naquela pasta |
| Bloquear apps UWP em 2º plano | Economiza RAM e CPU |
| Ultimate Performance (energia) | Ativa o plano oculto "Ultimate Performance", evitando que o Windows reduza o desempenho da CPU pra economizar energia |
| GPU Scheduling (HAGS) | Pode reduzir latência de entrada em GPUs e drivers compatíveis. Só faz efeito depois de reiniciar o PC |
| Desativar Nagle (rede) | Reduz pequenos atrasos de rede causados pelo agrupamento de pacotes, nos adaptadores ativos no momento |

### Boost agora

Pensado pra ser usado com o VALORANT já aberto, no meio de uma partida com FPS ruim ou travando:

- Eleva a prioridade do processo do VALORANT para Alta.
- Troca o plano de energia para Alto desempenho.
- Lista processos comuns que consomem recursos em segundo plano (Discord, Chrome, Spotify, launchers, etc.) e pergunta quais fechar.
- Limpa o cache de DNS.

## Como usar

1. Baixe o `valorant_otimizador.ps1` e coloque numa pasta só dele — os arquivos de backup e configuração vão ser criados ao lado.
2. Clique com o botão direito no arquivo e escolha **Executar com PowerShell**. Um duplo clique normal só abre o arquivo pra edição — é o comportamento padrão do Windows para `.ps1`.
3. Aceite a janela do Controle de Conta de Usuário (UAC). O script pede isso sozinho.
4. Na primeira vez, se o VALORANT não estiver em `C:\Riot Games`, o painel abre uma janela pra você escolher a pasta certa, e salva em `config.json` pras próximas execuções.
5. Marque os ajustes desejados e clique em **APLICAR SELECIONADOS**.
6. Reinicie o PC.

Se o executável do jogo não for encontrado, o ajuste de tela cheia é pulado — os outros aplicam normalmente.

## Backup e reversão

Antes de aplicar qualquer ajuste, o script exporta a chave do registro que vai alterar para a pasta `valorant_backup`, um `.reg` por chave:

- `gameconfigstore.reg`, `gamedvr.reg`, `layers.reg`, `bgapps.reg`, `systemprofile.reg`, `ifeo.reg` — ajustes principais
- `graphicsdrivers.reg` e `nagle_<guid-do-adaptador>.reg` — GPU Scheduling e Nagle
- `power_plan_anterior.txt` — guarda qual plano de energia estava ativo antes de trocar (Ultimate Performance ou Boost agora)

O backup é feito só na primeira vez que cada chave é alterada e não é sobrescrito depois, então guarda o estado original. No botão **REVERTER**, escolha:

- **Sim** — restaura o backup exato de antes (ou dê dois cliques num `.reg` específico, na pasta `valorant_backup`).
- **Não** — reseta pro padrão aproximado do Windows, não necessariamente pro que estava antes de aplicar. Também remove a chave de prioridade de CPU, o GPU Scheduling, a exclusão da pasta da Riot no Defender e o ajuste de Nagle. Se você já tinha a pasta da Riot nas exclusões do Defender antes de usar o script, ela some junto.

## Cuidados

- A exclusão no Defender reduz a proteção daquela pasta. Avalie se faz sentido pra você.
- O script altera chaves em `HKLM`, então precisa rodar como administrador.
- O GPU Scheduling só tem efeito em placas de vídeo e drivers compatíveis, e só depois de reiniciar.
- O ajuste de Nagle é aplicado só nos adaptadores de rede que estavam ativos no momento em que o ajuste foi marcado.
- O ganho varia de máquina para máquina.

## Licença

MIT.
