# A Growth Story (nome provisório)

Tycoon/simulation mobile (Android primeiro) inspirado na filosofia de *Game Dev Story*:
você começa como freelancer de marketing digital e evolui até dono de agência.
Estética pixel art simples. Este repositório contém **as bases e as mecânicas do MVP**
(GDD em `docs/GDD.md`), com placeholders visuais que serão substituídos por arte definitiva.

## Stack

- **Godot 4.3** (GDScript), renderer *Mobile*, viewport 540×960 em retrato.
- Conteúdo em JSON (`data/`), lógica em sistemas independentes (`src/systems/`).
- Sprites placeholder gerados por script (`tools/gen_sprites.py`, sem dependências).
- Testes headless (`tests/`) executados também no CI (`.github/workflows/tests.yml`).

## Como rodar

1. Instale o [Godot 4.3](https://godotengine.org/download) (versão *standard*, não é preciso .NET).
2. Abra o `project.godot` no editor e pressione **F5** (a cena principal é `src/ui/main.tscn`).
3. Ou pela linha de comando: `godot --path .`

### Testes

```bash
godot --headless --path . --import                       # gera o cache de classes
godot --headless --path . res://tests/sim_test.tscn      # 3 anos de jogo com política automática + save/load + avaliação
godot --headless --path . res://tests/ui_smoke_test.tscn # abre todas as telas e popups
# Capturas de tela das telas (precisa de display; em servidor use xvfb-run):
xvfb-run godot --path . --rendering-driver opengl3 --resolution 540x960 res://tests/screenshot_tour.tscn
```

### Instalar no celular (APK pronto)

A cada mudança no `main` (e em cada pull request) o GitHub gera o APK sozinho, pelo workflow
**APK Android** (`.github/workflows/android.yml`). Para pegar o arquivo:

1. No repositório, abra a aba **Actions** → workflow **APK Android** → clique na execução mais recente.
2. Na seção **Artifacts**, baixe `growth-story-apk` (um zip com o `growth-story.apk` dentro).
3. Mande o `.apk` para o celular (cabo, Drive, WhatsApp) e abra. O Android pede para permitir
   "instalar apps de fontes desconhecidas"; aceite só para esse arquivo.

É um build de debug assinado com uma chave temporária: serve para testar, não para publicar na Play Store.

### Exportar para Android no seu computador

O preset `Android` já está em `export_presets.cfg` (arm64, retrato, imersivo).
Para gerar o APK é preciso, no editor: *Editor → Gerenciar modelos de exportação* (baixar
os templates 4.3) e configurar o Android SDK + keystore de debug em *Editor → Configurações do editor → Export → Android*.
Depois: *Projeto → Exportar → Android → Exportar projeto*, ou
`godot --headless --path . --export-debug Android build/growth-story.apk`.

## O que já existe (MVP, GDD §36)

| Sistema | Onde | Resumo |
|---|---|---|
| Tempo | `time_system.gd`, `game_manager.gd` | Ritmo cozy: dia a cada 3,5 s no 1x (2x, 3x), meses de 30 dias, anos a partir de 2010, pausa automática em eventos/modais |
| Funcionários | `employee_system.gd`, `models/employee.gd` | 6 atributos, motivação, estresse, lealdade, potencial, 8 personalidades, carreira em 8 níveis, burnout, pedidos de demissão |
| Contratação | idem | Candidatos procedurais (nomes BR), qualidade cresce com reputação, expiram em 45 dias, capacidade do escritório |
| Treinamento | `data/training.json` | 7 cursos com custo, dias e ganhos de atributo (potencial multiplica) |
| Clientes | `client_system.gd`, `data/clients.json` | 12 clientes escritos à mão + geração procedural; segmento, tier, personalidade, objetivo declarado e **problema real oculto** |
| Proposta comercial | `client_system.gd`, `popups.gd` | Slider de preço (60% a 140% do orçamento): desconto aumenta a chance de fechar, prêmio reduz e eleva a expectativa do cliente |
| Diagnóstico | idem | Auditoria paga que revela o problema real; a estratégia certa ganha +15 de Estratégia |
| Projetos | `project_system.gd` | Escolha de 1–3 serviços + equipe, execução diária com 4 indicadores, prazo, atraso, micro-eventos de humor |
| Combinações | `service_system.gd`, `match_table` | Segmento × serviços = *Perfect match* (+35%), boa, neutra ou ruim (−25%) |
| Avaliação | `project_system.gd` | Nota 0–100 → 1 a 5 estrelas, pagamento, ROI, reputação, corações do cliente, manchetes de imprensa |
| Contratos | idem | Projeto (entrega única) ou **retainer** (6 ciclos mensais, MRR) liberado após boa entrega |
| Serviços | `data/services.json` | 11 serviços em 3 tiers; desbloqueio por caixa + reputação |
| Finanças | `finance_system.gd` | Caixa, salários, aluguel, ferramentas, histórico mensal, falência abaixo de −R$ 30.000 |
| Reputação | `reputation_system.gd` | 0–100 com retornos decrescentes; faixas do GDD §27 e fases do §29 |
| Eventos | `event_system.gd`, `data/events.json` | 20 eventos com escolhas, condições (reputação, equipe, estresse, projetos…) e cooldown por evento |
| Jornada | `employee_system.gd`, `popups.gd` | Linha do tempo por colaborador: contratação, cursos, promoções, campanhas, eventos (Equipe → Jornada) |
| Objetivos | `objective_system.gd`, `data/objectives.json` | 13 objetivos sequenciais que guiam o primeiro ano, com bônus em caixa (GDD §37) |
| Escritório | `office_system.gd`, `src/office/` | 4 níveis (4 / 7 / 12 / 18 lugares) com layout em tiles; ampliação pela aba Equipe ou Empresa; funcionários andam entre mesa, café e sofá |
| Save/Load | `save_system.gd` | JSON em `user://savegame.json`, autosave mensal, botão na aba Empresa |
| UI | `src/ui/` | HUD, escritório, feed de humor, 5 abas (Equipe, Clientes, Projetos, Empresa, Desbloqueios), modais |

Detalhes de fórmulas e fluxo em `docs/ARQUITETURA.md`.

## Próximos passos sugeridos

1. **Balanceamento** com testes de jogadores reais (ver `tests/sim_test.gd` para a política automática usada como régua).
2. Arte definitiva: substituir `assets/sprites/*.png` mantendo os tamanhos (16×16 personagens, 32×16 mesa/sofá).
3. Fonte pixel art e sons (`GDD §40–41`).
4. Conteúdo: mais clientes, eventos, eras históricas (GDD §23) e serviços de endgame.
5. Departamentos, gerentes, concorrentes e aquisições (Fase 4 do roadmap).
