# Otimizador-valorant

Script `.bat` para Windows que aplica ajustes de sistema para o Valorant rodar com menos interferência do Windows. Faz backup do registro antes de alterar qualquer coisa e tem opção de reverter.

O script só altera configurações do Windows. Não interage com o processo do jogo.

## O que altera

| Área | Ajuste | Motivo |
| --- | --- | --- |
| Game DVR | Desligado | Grava em segundo plano e gasta GPU |
| Game Mode | Ligado | Segura atualização de driver e aviso de reinicialização durante a partida |
| Tela cheia | Modo exclusivo clássico no lugar do modo otimizado do Windows, e otimizações de janela do DirectX desativadas para o executável do jogo | Menos camadas entre o jogo e a tela |
| MMCSS | Limite de rede desligado, `SystemResponsiveness` em 0 e tarefa `Games` com prioridade alta | Tira o limite de rede e reduz a reserva de CPU para tarefas de fundo |
| Prioridade de CPU | Alta, via Image File Execution Options | O kernel aplica na criação do processo, sem depender de handle externo (o Vanguard restringe isso) |
| Windows Defender | Pasta da Riot excluída do scan em tempo real | Menos I/O durante o jogo |
| Apps em segundo plano | Apps UWP em segundo plano desativados | Economiza RAM e CPU |

## Como usar

1. Baixe o `valorant_otimizar.bat`.
2. Se o Valorant não estiver em `C:\Riot Games`, edite a variável `RIOT_DIR` no topo do script.
3. Clique com o botão direito no arquivo e execute como administrador. Sem administrador o script avisa e encerra, porque as chaves em `HKLM` exigem.
4. Escolha `[1] aplicar`.
5. Reinicie o PC.

Se o executável do jogo não for encontrado, o script avisa e pula só o ajuste de tela cheia.

## Backup e reversão

Antes de aplicar, o script exporta os ramos do registro que vai alterar para a pasta `valorant_backup`, um `.reg` por ramo:

- `gameconfigstore.reg`
- `gamedvr.reg`
- `layers.reg`
- `bgapps.reg`
- `systemprofile.reg`

O backup é feito só na primeira execução e não é sobrescrito depois, então guarda o estado original. Para voltar exatamente ao que estava antes, dê dois cliques no `.reg` correspondente.

A opção `[2] reverter` volta os valores para o padrão do Windows, não para o que estava antes de aplicar. Ela também remove a chave de prioridade de CPU e a exclusão da pasta da Riot no Defender. Se você já tinha essa pasta nas exclusões, ela some junto.

## Cuidados

- A exclusão no Defender reduz a proteção daquela pasta. Avalie se faz sentido para você.
- O script altera chaves em `HKLM`. Use o backup se quiser garantia de retorno.
- O ganho varia de máquina para máquina.

## Licença

MIT.
