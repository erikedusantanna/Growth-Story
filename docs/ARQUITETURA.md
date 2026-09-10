# Arquitetura e fórmulas

## Visão geral

```
Autoloads
├── EventBus (src/core/event_bus.gd)   sinais globais; sistemas emitem, UI escuta
└── Game     (src/core/game_manager.gd) dono do GameState e dos sistemas; tick diário

GameState (src/core/game_state.gd)     tudo que é salvo: dia, caixa, reputação, listas
Modelos   (src/models/)                Employee, Client, Project (to_dict/from_dict)
Sistemas  (src/systems/)               RefCounted com setup(game); sem dependência de UI
Conteúdo  (data/*.json)                carregado por ContentDB no início
UI        (src/ui/, src/office/)       construída em código a partir de UIKit
```

Regra de ouro: **a UI nunca altera o estado diretamente**. Ela chama métodos dos sistemas
(`Game.projects.create_project(...)`, `Game.employees.hire(...)`), que validam, aplicam e emitem
`EventBus.state_changed`. Isso é o que permite rodar o jogo inteiro sem interface nos testes.

## Ciclo do dia (`Game.on_day`)

1. `employees.on_day` — estresse/motivação, fim de treinamentos, burnout.
2. `projects.on_day` — progresso, indicadores, micro-eventos, conclusão/ciclo de retainer.
3. `clients.on_day` — diagnóstico, decaimento de relação, novos prospects.
4. `events.on_day` — sorteio de evento aleatório (pausa o tempo até ser resolvido).
5. `objectives.check` — avança objetivos concluídos (também roda em `state_changed`).
6. A cada 30 dias `on_month`: custos fixos, lealdade, novos candidatos, autosave.
7. A cada 360 dias `on_year`: resumo no feed.

## Projeto

- **Orçamento**: projeto = `budget_cliente × (1,2 + 0,3 × maturidade)`; retainer = `budget_cliente`/mês.
  O `budget_cliente` é o valor negociado na proposta (60% a 140% da referência).
- **Prazo**: `clamp(18 + orçamento/800, 24, 60)` dias; retainer avalia a cada 30 dias.
- **Esforço**: `12 + orçamento/350` pontos.
- **Produção diária por pessoa**: `(0,5 + habilidade/100 × 1,5) × produtividade`, onde
  `habilidade` = média ponderada dos atributos pelos pesos dos serviços escolhidos e
  `produtividade = base_personalidade × (0,7 + motivação × 0,6) × (1 − estresse/220)`.
- **Alvos dos indicadores** (`compute_targets`):
  - Estratégia = média de Estratégia (+15 se ataca o problema diagnosticado; +7 sem diagnóstico).
  - Criatividade = 60% média + 40% melhor da equipe.
  - Execução = 40% Gestão + 20% Tecnologia + 40% motivação − 15% estresse + bônus de experiência (−10 se uma pessoa só em projeto grande).
  - Performance = 60% média de Performance + 40% melhor habilidade nos serviços.
- **Nota**: média ponderada (0,3/0,25/0,25/0,2) com pesos da personalidade do cliente,
  × multiplicador da combinação (1,35 / 1,12 / 1,0 / 0,75), × `1 − 0,06 × (dificuldade − 1)`,
  − 0,8/dia de atraso (máx. 20). Retainer: × `0,6 + 0,4 × progresso`.
- **Estrelas**: limiares 35/50/65/82 (+3 para expectativa alta, −3 para baixa, +10 × (preço − 1) pelo preço negociado).
- **Pagamento**: orçamento × [0,6; 0,85; 1,0; 1,1; 1,25].
- **Bônus controláveis** (aparecem no detalhamento): entrega no prazo +5; diagnóstico aplicado +8 (+3 se acertou sem
  diagnosticar); especialista na equipe +4 por serviço (máx. +8).
- **Reputação**: `(estrelas − 2) × (0,4 + 0,3 × tier)` (+2 em 5 estrelas com perfect match): 3 estrelas já rende,
  2 é neutro, 1 custa. Ganhos × `1 − rep/90` (mín. 0,1); perdas × `0,3 + 0,7 × rep/100`.
- **Tier dos prospects**: o menor entre o tier por reputação (20/40/60/80) e `1 + equipe/3`.
- **Expectativa**: limiares de estrelas deslocam +3 (alta) / −3 (baixa) e `+10 × (preço_negociado − 1)`.
- **Cliente**: relação `± 15 × (estrelas − 3)`; 1–2 estrelas com paciência < 50 → 50% de cancelar.
- **Equipe**: XP `12 + orçamento/2500`, atributos dos serviços crescem com o potencial.

## Proposta comercial

`proposal_chance(c, price_factor)` = `45 + melhor Comunicação × 0,35 + rep × 0,3 − dificuldade × 8 − tentativas × 12 (+10 com um Vendedor)`
`+ (1 − price_factor) × 60`. O slider vai de 0,6 a 1,4. Ao fechar, `c.budget` passa a ser o valor negociado
e `c.price_factor` desloca os limiares de estrelas (cliente que paga mais espera mais).

## Prospects e custos fixos

- A cada 15 dias, chance `0,15 + rep/160` de chegar um prospect, até 2 simultâneos abaixo de 20 de
  reputação e 3 acima. O tier máximo do prospect segue as faixas de reputação (GDD §27).
- Custos mensais: salários + aluguel do escritório (0 / 2.500 / 8.000 / 20.000) + R$ 250 por pessoa em
  ferramentas. Ampliações custam 8 mil / 45 mil / 150 mil e pedem reputação 8 / 25 / 45.

## Régua de ritmo (GDD §53)

`tests/sim_test.gd` roda 3 anos com uma política automática gananciosa e imprime, por ano, equipe,
clientes, receita, caixa, reputação e escritório. O teste falha se o ano 3 sair da faixa
3–10 pessoas, R$ 120–700 mil de receita e 20–70 de reputação, ou se o ano 1 sair de 2–5 pessoas e 8–35
de reputação. Um jogador real tende a crescer mais devagar que o bot; a faixa é o teto, não a meta.

Última medição: ano 1 = 4 pessoas, R$ 97 mil, rep 24 · ano 3 = 4 pessoas, R$ 289 mil, rep 45.

## Moral, RH, mobília e eventos da agência

- **Moral** é o campo `motivation` do funcionário (0 até o teto). Teto base 85 (`data/furniture.json → base_morale_max`),
  elevado por mobília. Toda alteração passa por `EmployeeSystem.change_morale`, que respeita o teto. Produtividade
  = personalidade × (0,7 + moral × 0,6) × (1 − estresse/220) × buffs do RH × mobília.
- **RH** (`HRSystem`): fechado até contratar a analista (`hr_actions.json → hire`: custo único, `salary` mensal
  somado em `FinanceSystem.monthly_costs().hr`, exige escritório 3 e reputação 30). `state.hr_hired` liga o anexo
  do escritório (`offices.json → hr_room`: divisória, placa, mesa e analista fixa). Cada ação tem custo fixo
  + custo por pessoa, `cooldown_days`, e efeitos: `morale`, `stress`, `loyalty`, `delay_days` (atrasa projetos) e
  `buff` temporário (`productivity`, `stress_rate`, `days`) guardado em `state.buffs`. Ações com `pet` são únicas:
  adicionam o bicho a `state.pets` (o gato exige `requires_pet: dog`) e somam `morale_daily` permanente.
- **Mobília** (`OfficeSystem`): `state.furniture` guarda os ids. `furniture_effects()` agrega `morale_max`,
  `morale_daily` (incluindo pets), `stress_rate` e `productivity`; `attr_bonus` é aplicado a todos na compra e a cada
  contratação. No escritório: `sprite` ocupa os `decor_slots`, `wall_sprite` ocupa os `wall_slots` da parede e
  `visual` troca o sprite de um tipo (`chair → chair_ergo`, `desk → desk_wide`, `coffee → coffee_premium`).
- **Setorização do escritório** (`data/offices.json`): as mesas ficam agrupadas em ilhas em vez de espalhadas em
  grade. Cada layout traz `zones` (tapetes coloridos desenhados sob a mobília, `rect` em tiles + `tint` de
  `OfficeView.ZONE_TINTS`) e `dividers` (`x`, `y0`, `y1` — divisórias verticais montadas com o mesmo par de sprites
  do anexo do RH). Entre as ilhas fica um corredor de piso de madeira, e os níveis 3 e 4 têm ala de convivência
  com mesa de reunião (`meeting_table`), sofá, café e bebedouro.
- **Arte e personagens** (`tools/gen_art.py`): tile de 32 px, contorno escuro, 3 tons por material. O personagem
  (32×48) sai em folhas de 4 poses × 4 direções (`hframes`/`vframes` = 4; quadro = direção × 4 + pose) em camadas:
  `skin.png`, `shirt.png` e `hair_<estilo>[g].png` são cinzas modulados pela cor do funcionário (base 216, brilho
  255, sombra 160), `legs.png` e `outline_<estilo>[g].png` (contorno + rosto + óculos) têm cor fixa. O sufixo `g`
  é a variante de óculos (`Employee.glasses`). `Worker._face()` escolhe a direção pelo eixo dominante do movimento.
- **Escritório interativo** (`OfficeView`): câmera com zoom entre "cabe inteiro" e 2×; arrastar com um dedo, pinça
  com dois (eventos de toque; roda do mouse no desktop); toque curto no avatar emite `worker_tapped`. Cada `Worker`
  desenha a barra de moral sobre a cabeça; `Pet` passeia pelo piso do escritório principal.
- **Cenas de evento** (`EventStage`, `data/scenes.json`): eventos com o campo `scene` (aleatórios e da agência)
  trocam o painel do escritório por um cenário 270×168 em 2× (`assets/art/scenes/<kind>.png`) numa `CanvasLayer`
  acima do escurecimento dos popups. Cada cenário define `marks` (pés, direção e pose de cada pessoa; a primeira é
  a protagonista e recebe `hold`, o troféu), adereços de primeiro plano (`front`) e o fundo. Os atores são `Worker`
  em `static_pose`, montados com as camadas do funcionário real. `Popups._scene_top()` abre a cena e devolve a
  altura em que o painel deve começar (`Main.below_office_y()`); `Popups.close()` esconde a cena. Ao terminar um
  evento promovido, `AgencyEventSystem.on_day()` emite `EventBus.agency_event_finished(ev, people, summary)` e o
  popup de resultado mostra quem foi.
- **Eventos da agência** (`AgencyEventSystem`): abrem com reputação 40. Custam `cost` e `people` por `days`
  (as pessoas ficam com `busy_reason = "Em evento"` e saem pela porta). Ao terminar, aplicam `effects`:
  `reputation`, `prospects` (+`prospect_tier_bonus`), `candidates`, `money` (patrocínio), `morale`, `delay_days`.

## Combinações (`data/services.json → match_table`)

Por segmento há uma lista `best` e uma `poor`. Qualquer serviço em `poor` → *ruim*;
dois ou mais em `best` → *perfect*; um → *boa*; caso contrário *neutra*.

## Eventos (`data/events.json`)

Campos de condição: `min_day`, `min_reputation`, `min_employees`, `min_active_clients`,
`min_running_projects`, `min_cases`, `min_avg_stress`, `min_office_level`,
`requires_personality`, `once`, `cooldown_days` (padrão 120: o mesmo evento não repete antes disso). Placeholders no texto: `{best_employee}`, `{random_client}`,
`{personality_employee}`. Efeitos suportados estão em `EventSystem._apply_effect`.

## Eras históricas (`era_system.gd`, `data/eras.json`)

GDD §23: o calendário do jogo já avança por anos reais (`GameState.year()`, começando em
2010); cada era do `data/eras.json` cobre uma faixa desses anos (`year_start`/`year_end`,
`year_end` nulo = sem fim) e lista `trends`: os serviços "em alta" naquele momento do mercado.
`EraSystem.current()`/`at_year(y)` resolvem a era pura função do ano; `is_trending(id)` e
`trending_services()` consultam a era atual. `ProjectSystem.BONUS_TRENDING` (+3) entra no
`_score()` quando o projeto usa algum serviço em alta, com uma linha própria no detalhamento —
mesma mecânica de bônus que diagnóstico/especialista. `GameManager.on_year()` compara a era do
ano que terminou com a do ano que começa e loga a virada ("O mercado mudou: ..."). A aba
Agência mostra um cartão com a era atual e marca os serviços em alta com 🔥; a aba Empresa
mostra a era na lista de números.

## Departamentos e concorrência (GDD §30-31, §35)

- **Departamentos** (`department_system.gd`, `data/departments.json`): abrem em
  `state.office_level >= unlock_office` (4, "Escritório com departamentos"). Cada funcionário
  tem `department: String` (vazio = nenhum). Um departamento com gerente (`career_level >=
  MANAGER_CAREER_LEVEL`, o índice de "Gerente" em `data/names.json → career`) e
  `min_members_for_bonus` pessoas (padrão 2) dá `productivity_bonus` (padrão +8%) a todos ali —
  `EmployeeSystem.productivity()` multiplica por `DepartmentSystem.productivity_multiplier(e)`.
  Aba Equipe mostra a visão geral dos departamentos e um seletor por funcionário.
- **Concorrência** (`competitor_system.gd`, `data/competitors.json`): a partir de `min_day`,
  todo dia cada prospect parado há mais de `steal_after_idle_days` tem `steal_chance_per_day`
  de ser fechado por uma agência rival (nome sorteado de `agencies`), via
  `ClientSystem.lose_client()` — reaproveita o mesmo caminho de perda de cliente (log, som de
  crise). Complementa os eventos que já existiam (`proposta_concorrente`, `concorrente_cresce`).

## Fonte pixel art (`tools/gen_font.py`, `assets/fonts/pixel.fnt`)

Bitmap font 5×7 (matriz de pontos), com 2 linhas extras acima para acento — cobre A-Z, a-z,
0-9, pontuação básica e as vogais acentuadas do português (agudo, grave, circunflexo, til) mais
ç/Ç. Gerada por código: `tools/gen_font.py` escreve o atlas (`pixel_atlas.png`) e a descrição
no formato BMFont (`pixel.fnt`), que o Godot importa nativamente como `FontFile`
(`importer="font_data_bmfont"`). `UIKit.pixel_font()` carrega o resource; `UIKit.title()` e
`UIKit.number()` já usam essa fonte — o corpo de texto (labels, parágrafos) segue na fonte do
sistema para não cansar a leitura (GDD §40: "não precisa parecer retrô demais").

## Som (`src/core/audio_manager.gd`, `tools/gen_audio.py`)

Música e efeitos sintetizados por código em ondas quadradas/triangulares (`tools/gen_audio.py`,
sem samples externos): 9 efeitos em `assets/audio/sfx/` (hire, payment, project_complete,
level_up, event, client_happy, crisis, promotion, click) e uma trilha em loop em
`assets/audio/music/theme_loop.wav`. O autoload `Audio` (`src/core/audio_manager.gd`) escuta os
sinais do `EventBus` — nenhum outro sistema precisa saber que o áudio existe:
`employee_hired`→hire, `employee_promoted`→promotion, `client_lost`→crisis,
`event_triggered`→event, `money_changed` (delta>0)→payment, `project_completed`
(`result.stars>=4`)→client_happy, senão→project_complete, e cruzar uma faixa de reputação
(20/40/60/80)→level_up. `UIKit.button()` toca "click" em toda pressão. Preferências
(`music_enabled`/`sfx_enabled`) persistem em `user://audio_settings.cfg` e têm toggle na aba
Empresa. Em ambiente headless (`DisplayServer.get_name() == "headless"`, usado pelos testes) o
áudio fica silencioso propositalmente: o driver "Dummy" não libera `AudioStreamPlayback` entre
chamadas rápidas e os recursos vazariam até o fim do processo.

## Save

`GameState.to_dict()` → JSON em `user://savegame.json`. O estado do RNG é salvo como string
para não perder precisão. Versão do save em `version` (1).

## Como adicionar conteúdo

- **Cliente**: novo objeto em `data/clients.json` (segmento precisa existir em `segment_names`).
- **Serviço**: `data/services.json` + atualizar `match_table`/`problem_solutions`; o papel
  correspondente em `data/names.json → roles` gera candidatos especialistas.
- **Evento**: `data/events.json`; novos tipos de efeito em `EventSystem._apply_effect`.
- **Escritório**: `data/offices.json` (posições em tiles de 16 px; linha 0 é a parede). Mesas adjacentes formam
  uma ilha (cada mesa ocupa 2 tiles); `zones` pinta o tapete do setor e `dividers` levanta a divisória entre ilhas.
- **Objetivo**: `data/objectives.json` (`type` é uma chave de `stats` ou um dos especiais em `ObjectiveSystem.progress_value`).
- **Era**: `data/eras.json` (`year_start`/`year_end`, `trends` com ids de serviço existentes).
- **Departamento**: `data/departments.json → departments` (`id`, `name`, `attr`).
- **Agência concorrente**: `data/competitors.json → agencies` (só o nome, entra no sorteio).
- **Cenário de evento**: `data/scenes.json → scenes` (`backdrop`, `marks`, `front`, `hold`); para um evento ganhar cena, basta `"scene": "<kind>"` na entrada dele.
- **Jornada**: chame `Game.employees.add_journey(e, texto)` em qualquer marco novo.
