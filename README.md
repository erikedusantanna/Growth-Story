# A Growth Story (nome provisório)

Tycoon/simulation mobile (Android primeiro) inspirado na filosofia de *Game Dev Story*:
você começa como freelancer de marketing digital e evolui até dono de agência.
Estética pixel art simples. Este repositório contém **as bases e as mecânicas do MVP**
(GDD em `docs/GDD.md`), com placeholders visuais que serão substituídos por arte definitiva.

## Outros jogos neste repositório

- **Tactics** (nome provisório): projeto Godot independente em [`games/tactics/`](games/tactics/README.md).
  A pasta `games/` tem um `.gdignore`, então o Godot do Growth-Story não importa nem exporta nada de lá.
  Abra com `godot --path games/tactics`; o CI roda seus testes em `.github/workflows/tactics-tests.yml`.

## Stack

- **Godot 4.3** (GDScript), renderer *Mobile*, viewport 540×960 em retrato.
- Conteúdo em JSON (`data/`), lógica em sistemas independentes (`src/systems/`).
- Arte pixel art gerada por script, sem dependências: `tools/gen_art.py` (tile de 32 px, estilo chibi com contorno escuro e 3 tons; personagens em camadas recoloríveis, 7 cabelos, óculos e 4 direções) e `tools/gen_icons.py` (ícones do HUD).
- Testes headless (`tests/`) executados também no CI (`.github/workflows/tests.yml`); o CI também gera o APK Android e o executável Windows a cada mudança.

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

### Jogar no Windows (executável portátil)

O workflow **Executável Windows** (`.github/workflows/windows.yml`) gera um único `growth-story.exe`
com os dados do jogo embutidos — não precisa instalar nada, basta copiar e abrir.

1. No repositório, abra **Actions** → workflow **Executável Windows** → execução mais recente.
2. Em **Artifacts**, baixe `growth-story-windows` (zip com o `growth-story.exe`).
3. Extraia e dê dois cliques. O Windows pode mostrar o aviso "Windows protegeu o seu PC" por o
   arquivo não ser assinado: clique em **Mais informações → Executar assim mesmo**.

O mouse faz o papel do dedo (arrastar o escritório, tocar no avatar; roda do mouse dá zoom).
O save fica em `%APPDATA%\Godot\app_userdata\A Growth Story\`.

Para gerar no seu computador: `godot --headless --path . --export-release "Windows Desktop" build/growth-story.exe`
(o preset `Windows Desktop` está em `export_presets.cfg`).

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
| Clientes | `client_system.gd`, `data/clients.json` | 23 clientes escritos à mão (tiers 1–5) + geração procedural; segmento, tier, personalidade, objetivo declarado e **problema real oculto** |
| Proposta comercial | `client_system.gd`, `popups.gd` | Slider de preço (60% a 140% do orçamento): desconto aumenta a chance de fechar, prêmio reduz e eleva a expectativa do cliente |
| Diagnóstico | idem | Auditoria paga que revela o problema real; a estratégia certa ganha +15 de Estratégia |
| Projetos | `project_system.gd` | Escolha de 1–3 serviços + equipe, execução diária com 4 indicadores, prazo, atraso, micro-eventos de humor |
| Combinações | `service_system.gd`, `match_table` | Segmento × serviços = *Perfect match* (+35%), boa, neutra ou ruim (−25%) |
| Avaliação | `project_system.gd` | Nota 0–100 → 1 a 5 estrelas, pagamento, ROI, reputação, corações do cliente, manchetes de imprensa |
| Contratos | idem | Projeto (entrega única) ou **retainer** (6 ciclos mensais, MRR) liberado após boa entrega |
| Serviços | `data/services.json` | 16 serviços em 4 tiers (início, intermediário, avançado, **endgame**: IA, MarTech, Dados, Tecnologia Proprietária, Consultoria Enterprise); desbloqueio por caixa + reputação |
| Eras históricas | `era_system.gd`, `data/eras.json` | GDD §23: 6 eras reais (2010 → 2025+) acompanham o calendário do jogo (`GameState.year()`); cada uma marca serviços "🔥 em alta" que rendem +3 na nota do projeto — a melhor estratégia muda com o tempo. Log ao virar de era, aba Agência mostra a era atual |
| Departamentos | `department_system.gd`, `data/departments.json` | GDD §30-31: a partir do escritório com departamentos, agrupe a equipe por área (Criação, Estratégia, Performance, Atendimento, Tecnologia, Gestão); um Gerente + 2 pessoas no mesmo departamento rende +8% de produtividade para todos ali |
| Concorrência | `competitor_system.gd`, `data/competitors.json` | GDD §30-31/§35: prospects esquecidos por muito tempo podem ser fechados por uma agência rival antes de você — soma-se aos eventos que já existiam (proposta a funcionário, concorrente em ascensão) |
| Finanças | `finance_system.gd` | Caixa, salários, aluguel, ferramentas, histórico mensal, falência abaixo de −R$ 30.000 |
| Reputação | `reputation_system.gd` | 0–100 com retornos decrescentes; faixas do GDD §27 e fases do §29 |
| Eventos | `event_system.gd`, `data/events.json` | 27 eventos com escolhas, condições (reputação, equipe, estresse, projetos…) e cooldown por evento; alguns só aparecem em reputação alta e prenunciam o roadmap (cliente internacional, IA generativa, concorrente, investidor) |
| Jornada | `employee_system.gd`, `popups.gd` | Linha do tempo por colaborador: contratação, cursos, promoções, campanhas, eventos (Equipe → Jornada) |
| Objetivos | `objective_system.gd`, `data/objectives.json` | 13 objetivos sequenciais que guiam o primeiro ano, com bônus em caixa (GDD §37) |
| Briefings | `data/briefings.json`, `project_system.gd` | Cada cliente ativo recebe um tema para o próximo projeto (Lançamento, Rebranding, Máquina de leads, Gestão de crise, Institucional, Influenciadores, Fidelidade, Nova unidade, Black Friday, Fim de ano): muda o peso dos indicadores na nota, o prazo e o valor do contrato, e pede serviços-chave (+4 cada, até +8). Sazonais aparecem só nos meses certos; alguns dependem do problema real ou do segmento |
| Química da equipe | `data/chemistry.json`, `chemistry_system.gd` | Pares de personalidades na mesma equipe geram sinergia (+1) ou atrito (−1): ±3 pontos na nota por ponto, ±5% de ritmo, moral sobe com sinergia e estresse sobe com atrito. A prévia do projeto lista os pares e a ficha da pessoa mostra com quem combina |
| Prêmios do Marketing | `award_system.gd`, `data/scenes.json` | Cerimônia na virada do ano com o time no palco: Campanha do Ano (melhor nota, 5 estrelas vence), Agência do Ano (pontos do ano contra uma régua que sobe 8 por ano) e Profissional do Ano (3+ entregas com média 4,0+). Vencer rende reputação e moral; histórico na aba Empresa |
| Guia inicial | `src/ui/tutorial_overlay.gd`, `data/tutorial.json` | Nos 4 primeiros objetivos, um contorno laranja pulsante destaca o botão certo (aba, Proposta, Enviar, Diagnóstico, Novo projeto, Iniciar, Contratar) com um cartão curto explicando o porquê; funciona também dentro dos modais. "Pular guia" desliga; o estado persiste no save |
| Escritório | `office_system.gd`, `src/office/` | 4 níveis (4 / 7 / 12 / 18 lugares) com layout em tiles, mesas agrupadas em ilhas com tapete e divisória por setor e ala de convivência com mesa de reunião; ampliação pela aba Equipe ou Empresa; funcionários andam entre mesa, café e sofá, com barra de moral sobre a cabeça; arrastar com um dedo e zoom com pinça (ou roda do mouse); toque no avatar abre a jornada |
| Moral | `employee_system.gd`, `office_system.gd` | Barra por pessoa (campo `motivation`) com teto dado pela mobília; sobe com resultados, RH e eventos; cai com estresse, pedidos do cliente e sprints |
| RH | `hr_system.gd`, `data/hr_actions.json`, `hr_screen.gd` | Aba própria. Contrata-se uma analista (custo único + salário mensal; exige escritório profissional e reputação 30) que ganha um anexo com divisória no escritório. Libera pizza, happy hour, feriado prolongado, energético com paçoca (buff), festa, bem-estar, retiro e as políticas pet friendly (cachorro e depois gato, permanentes no escritório, com moral diária) |
| Mobília | `office_system.gd`, `data/furniture.json` | Comprada na aba Empresa: teto de moral, moral diária, estresse, produtividade e bônus permanentes de atributo (valem para quem entra depois). Toda mobília aparece no escritório: troca de sprite (cadeiras ergonômicas, monitores ultrawide, café premium), quadro na parede ou item nos slots de decoração |
| Eventos da agência | `agency_event_system.gd`, `data/agency_events.json` | Abrem com reputação 40: custam dinheiro e/ou pessoas por alguns dias e rendem reputação, prospects, candidatos, moral ou patrocínio |
| Cenas de evento | `src/office/event_stage.gd`, `data/scenes.json`, `assets/art/scenes/` | A "câmera" sai do escritório e mostra o time no palco da premiação, no auditório da palestra, no estande da feira, no meetup, no estúdio do podcast, na sala de reunião com o investidor ou na coletiva de imprensa — cenário por evento (`scene` em `events.json`/`agency_events.json`), montado na hora com os próprios funcionários (a primeira pessoa segura o troféu). O popup do evento passa a abrir abaixo da cena |
| Vida no escritório | `src/office/office_view.gd`, `season_system.gd`, `data/seasons.json`, `assets/art/seasons/` | Relógio no HUD (08:00–20:00 por dia de jogo): o céu atrás das janelas muda com a hora (sol, nuvens, pôr do sol, lua e estrelas), a luz do escritório esquenta no fim da tarde e as luminárias das mesas acendem à noite. Datas comemorativas por mês só visuais (Carnaval, Festa Junina, Halloween, Black Friday, Natal): guirlanda na parede + objeto no chão, com aviso no feed. Balões de "pensamento" (💡 ☕ 😴) aparecem sobre quem está trabalhando ou descansando |
| Save/Load | `save_system.gd` | JSON em `user://savegame.json`, autosave mensal, botão na aba Empresa |
| UI | `src/ui/` | Tela inicial com a cidade da agência (fundo e logo gerados em `tools/gen_art.py`), HUD, escritório, feed de humor, 6 abas (Equipe, Clientes, Projetos, Empresa, RH, Agência), modais |
| Fonte pixel art | `tools/gen_font.py`, `assets/fonts/pixel.fnt` | Bitmap font 5×7 com acentuação (á é í ó ú ã õ â ê ô ç), gerada por código; usada em títulos e números do HUD (`UIKit.pixel_font()`) |
| Som | `src/core/audio_manager.gd`, `tools/gen_audio.py` | Trilha de ~58 s em loop (acordes, baixo, melodia e bateria 8-bit) que toca desde a tela inicial, e 9 efeitos sonoros — tudo sintetizado por código; autoload `Audio` reage aos sinais do `EventBus`; botão de mudo 🔊/🔇 na tela inicial e no HUD (e toggles na aba Empresa). Som ambiente do escritório em loop de 16 s (ar-condicionado, teclados, mouse, papel, notificação) que fica mais presente conforme a equipe cresce; toggle próprio "🏢 Escritório" |

Detalhes de fórmulas e fluxo em `docs/ARQUITETURA.md`.

## Próximos passos sugeridos

1. **Balanceamento** com testes de jogadores reais. A simulação em `tests/sim_test.gd` imprime a curva ano a ano e falha se fugir da régua do GDD §53 (ver `docs/ARQUITETURA.md`).
2. ~~Arte definitiva~~ — feito: arte v2 em `tools/gen_art.py` (tile 32 px). Para trocar por arte desenhada à mão, mantenha os tamanhos gerados e a estrutura de camadas dos personagens (`assets/art/characters/`).
3. ~~Fonte pixel art e sons (`GDD §40–41`)~~ — feito: `assets/fonts/pixel.fnt` e `src/core/audio_manager.gd`.
4. ~~Conteúdo: mais clientes, eventos, eras históricas e serviços de endgame~~ — feito: `era_system.gd`, `data/eras.json`.
5. ~~Departamentos, gerentes e concorrentes~~ — feito: `department_system.gd`, `competitor_system.gd`. Falta: imprensa/aquisições e expansão internacional (resto da Fase 4 do roadmap).
6. ~~Mais ícones e imagens na interface~~ — feito: emojis em títulos, botões, cartões e na navegação inferior (ícone em cima, rótulo curto embaixo) para reduzir o peso visual de texto puro, principalmente para quem está começando.
