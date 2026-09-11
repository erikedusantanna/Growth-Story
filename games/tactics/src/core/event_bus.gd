extends Node
## Sinais globais do jogo. Sistemas emitem, a interface escuta.
## Mesma regra do Growth-Story: a UI nunca altera o estado diretamente.

## Emitido sempre que algo relevante do estado muda e a UI precisa redesenhar.
signal state_changed
