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
5. A cada 30 dias `on_month`: custos fixos, lealdade, novos candidatos, autosave.
6. A cada 360 dias `on_year`: resumo no feed.

## Projeto

- **Orçamento**: projeto = `budget_cliente × (2 + 0,5 × maturidade)`; retainer = `budget_cliente`/mês.
- **Prazo**: `clamp(15 + orçamento/1000, 20, 60)` dias; retainer avalia a cada 30 dias.
- **Esforço**: `10 + orçamento/600` pontos.
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
- **Estrelas**: limiares 35/50/65/82 (+3 para expectativa alta, −3 para baixa).
- **Pagamento**: orçamento × [0,6; 0,85; 1,0; 1,1; 1,25].
- **Reputação**: `(estrelas − 2,5) × (0,8 + 0,7 × tier)` (+2 em 5 estrelas com perfect match).
  Ganhos × `1 − rep/130`; perdas × `0,3 + 0,7 × rep/100`.
- **Cliente**: relação `± 15 × (estrelas − 3)`; 1–2 estrelas com paciência < 50 → 50% de cancelar.
- **Equipe**: XP `12 + orçamento/2500`, atributos dos serviços crescem com o potencial.

## Combinações (`data/services.json → match_table`)

Por segmento há uma lista `best` e uma `poor`. Qualquer serviço em `poor` → *ruim*;
dois ou mais em `best` → *perfect*; um → *boa*; caso contrário *neutra*.

## Eventos (`data/events.json`)

Campos de condição: `min_day`, `min_reputation`, `min_employees`, `min_active_clients`,
`min_running_projects`, `min_cases`, `min_avg_stress`, `min_office_level`,
`requires_personality`, `once`. Placeholders no texto: `{best_employee}`, `{random_client}`,
`{personality_employee}`. Efeitos suportados estão em `EventSystem._apply_effect`.

## Save

`GameState.to_dict()` → JSON em `user://savegame.json`. O estado do RNG é salvo como string
para não perder precisão. Versão do save em `version` (1).

## Como adicionar conteúdo

- **Cliente**: novo objeto em `data/clients.json` (segmento precisa existir em `segment_names`).
- **Serviço**: `data/services.json` + atualizar `match_table`/`problem_solutions`; o papel
  correspondente em `data/names.json → roles` gera candidatos especialistas.
- **Evento**: `data/events.json`; novos tipos de efeito em `EventSystem._apply_effect`.
- **Escritório**: `data/offices.json` (posições em tiles de 16 px; linha 0 é a parede).
