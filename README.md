# A Growth Story (nome provisório)

Tycoon/simulation mobile (Android primeiro) inspirado na filosofia de *Game Dev Story*:
você começa como freelancer de marketing digital e evolui até dono de agência.
Estética pixel art simples. Este repositório contém **as bases e as mecânicas do MVP**
(GDD em `docs/GDD.md`), com placeholders visuais que serão substituídos por arte definitiva.

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
| Tempo | `time_system.gd`, `game_manager.gd` | Ritmo cozy: dia a cada 10,5 s no 1x, 3,5 s no 2x e 1,4 s no 3x, meses de 30 dias, anos a partir de 2010, pausa automática em eventos/modais |
| Funcionários | `employee_system.gd`, `models/employee.gd` | 6 atributos, motivação, estresse, lealdade, potencial, 8 personalidades, carreira em 8 níveis, burnout, pedidos de demissão |
| Contratação | idem | Candidatos procedurais (nomes BR), qualidade cresce com reputação, expiram em 45 dias, capacidade do escritório |
| Treinamento | `data/training.json` | 7 cursos com custo, dias e ganhos de atributo (potencial multiplica) |
| Clientes | `client_system.gd`, `data/clients.json` | 31 clientes escritos à mão (tiers 1–5) + geração procedural; segmento, tier, personalidade, objetivo declarado e **problema real oculto** |
| Proposta comercial | `client_system.gd`, `popups.gd` | Slider de preço (60% a 140% do orçamento): desconto aumenta a chance de fechar, prêmio reduz e eleva a expectativa do cliente |
| Diagnóstico | idem | Auditoria paga que revela o problema real; a estratégia certa ganha +15 de Estratégia |
| Projetos | `project_system.gd` | Escolha de 1–3 serviços + equipe, execução diária com 4 indicadores, prazo, atraso, micro-eventos de humor |
| Combinações | `service_system.gd`, `match_table` | Segmento × serviços = *Perfect match* (+35%), boa, neutra ou ruim (−25%) |
| Avaliação | `project_system.gd` | Nota 0–100 → 1 a 5 estrelas, pagamento, ROI, reputação, corações do cliente, manchetes de imprensa |
| Contratos | idem | Projeto (entrega única) ou **retainer** (6 ciclos mensais, MRR) liberado após boa entrega |
| Serviços | `data/services.json` | 16 serviços em 4 tiers (início, intermediário, avançado, **endgame**: IA, MarTech, Dados, Tecnologia Proprietária, Consultoria Enterprise); desbloqueio por caixa + reputação |
| Eras históricas | `era_system.gd`, `data/eras.json` | GDD §23: 6 eras reais (2010 → 2025+) acompanham o calendário do jogo (`GameState.year()`); cada uma marca serviços "🔥 em alta" que rendem +3 na nota do projeto — a melhor estratégia muda com o tempo. Log ao virar de era, aba Agência mostra a era atual |
| Departamentos | `department_system.gd`, `data/departments.json` | GDD §30-31: a partir do escritório com departamentos, agrupe a equipe por área (Criação, Estratégia, Performance, Atendimento, Tecnologia, Gestão); um Gerente + 2 pessoas no mesmo departamento rende +8% de produtividade para todos ali |
| Concorrência | `competitor_system.gd`, `data/competitors.json` | GDD §30-31/§35. Prospects esquecidos podem ser fechados por uma rival. **Rivais reais** dominam as regiões 2–4 (Vértice Digital, Bumerangue Ads, Prisma Criativo): ao chegar à região, ganham força, 3 clientes e 2 pessoas, aparecem no mapa 🌎 e todo mês podem fazer proposta ao seu funcionário menos leal (cobrir, promover ou deixar sair) ou ao seu cliente de relação mais fraca (igualar desconto, reunião de retenção por Comunicação, ou deixar ir). Tocando na sede delas no mapa você faz **1 investida a cada 3 meses**: propor a um cliente dela (−5 de reputação se aceitar) ou contratar alguém da equipe com bônus de 2 salários (−3). A rival perde força e fica agressiva por 3 meses |
| Finanças | `finance_system.gd` | Caixa, salários, aluguel, ferramentas, histórico mensal, falência abaixo de −R$ 30.000 |
| Reputação | `reputation_system.gd` | 0–100 com retornos decrescentes; faixas do GDD §27 e fases do §29 |
| Eventos | `event_system.gd`, `data/events.json` | 37 eventos com escolhas, condições (reputação, equipe, estresse, projetos, **região mínima/máxima**) e cooldown por evento. Cada região tem os seus: vizinho pedindo logo e feira de rua no bairro; edital da prefeitura e rádio no centro; greve e congresso na capital; headhunter e fusão de clientes no distrito; reunião às 3h e câmbio no hub global |
| Projetos complexos | `project_system.gd` | Clientes tier 5 (Hub Global): equipe mínima de 4 pessoas com 2 especialidades, orçamento ×1,5 e esforço ×1,4; na metade do projeto o cliente avalia (checkpoint) e nota abaixo de 50 vira refação (+25% de trabalho e moral −3) |
| Jornada | `employee_system.gd`, `popups.gd` | Linha do tempo por colaborador: contratação, cursos, promoções, campanhas, eventos (Equipe → Jornada) |
| Objetivos | `objective_system.gd`, `data/objectives.json` | 13 objetivos sequenciais que guiam o primeiro ano, com bônus em caixa (GDD §37) |
| Briefings | `data/briefings.json`, `project_system.gd` | Cada cliente ativo recebe um tema para o próximo projeto (Lançamento, Rebranding, Máquina de leads, Gestão de crise, Institucional, Influenciadores, Fidelidade, Nova unidade, Black Friday, Fim de ano): muda o peso dos indicadores na nota, o prazo e o valor do contrato, e pede serviços-chave (+4 cada, até +8). Sazonais aparecem só nos meses certos; alguns dependem do problema real ou do segmento |
| Química da equipe | `data/chemistry.json`, `chemistry_system.gd` | Pares de personalidades na mesma equipe geram sinergia (+1) ou atrito (−1): ±3 pontos na nota por ponto, ±5% de ritmo, moral sobe com sinergia e estresse sobe com atrito. A prévia do projeto lista os pares e a ficha da pessoa mostra com quem combina |
| Prêmios do Marketing | `award_system.gd`, `data/scenes.json` | Cerimônia na virada do ano com o time no palco: Campanha do Ano (melhor nota, 5 estrelas vence), Agência do Ano (pontos do ano contra uma régua que sobe 8 por ano) e Profissional do Ano (3+ entregas com média 4,0+). Vencer rende reputação e moral; histórico na aba Empresa |
| Guia inicial | `src/ui/tutorial_overlay.gd`, `data/tutorial.json` | Nos 4 primeiros objetivos, um contorno laranja pulsante destaca o botão certo (aba, Proposta, Enviar, Diagnóstico, Novo projeto, Iniciar, Contratar) com um cartão curto explicando o porquê; funciona também dentro dos modais. "Pular guia" desliga; o estado persiste no save |
| Missões e arcos | `data/quests.json`, `quest_system.gd` | Pedidos com prazo que aparecem na rotina (fechar contratos, entregar 4★, treinar, manter a moral, terminar com caixa…). Cumprir paga dinheiro e reputação; deixar o prazo passar custa 1 de reputação. Aparecem no popup, no feed e no calendário. Três **arcos de 3 etapas** (O primeiro case, Time de verdade, O mercado olhando): só a etapa 1 entra no sorteio, cada etapa cumprida começa a seguinte na hora e a última paga bem mais |
| Calendário e agenda | `calendar_system.gd`, `src/ui/calendar_screen.gd` | Botão 📅 no HUD: grade dos 12 próximos meses (datas comemorativas e premiação), agenda do que vem pela frente (fechamento do mês, prazos, missões, leads, aniversários), banca com as últimas notícias, **foco do mês** (vendas, entrega, gente ou caixa, escolhido uma vez por mês) e **aniversário de contrato** dos clientes, com presente que melhora a relação |
| Notícias do mercado | `data/news.json`, `news_system.gd`, `assets/art/news/` | 28 manchetes cômicas de empresas e pessoas fictícias (B4 Company, Agência Beta, Fabio Augusto, Tiago Bigo…) em página de jornal ou post de rede social, com ilustração pixel art. 12 delas **mexem no mercado** por algumas semanas: aquecem 🔥 ou esfriam 🧊 um serviço (muda a nota e a procura), mexem na verba dos clientes ou trazem prospects. O efeito vem escrito na notícia e a tendência fica visível na aba Agência e no calendário |
| Mídia paga | `client_system.gd` (`CAMPAIGNS`) | Aba Clientes: comprar leads (Impulsionar, Campanha, Lançamento) que chegam em poucos dias além dos prospects orgânicos; o custo sobe com a região. Prospect novo toca um som e a aba Clientes pisca com o número esperando |
| World Map e regiões | `data/regions.json`, `tools/gen_layouts.py`, `src/ui/world_map_screen.gd` | Botão 🌎 no HUD abre a cidade isométrica (gerada em `tools/gen_art.py`) em tela cheia: 5 regiões = 5 tiers de cliente (Bairro Criativo → Centro Regional → Capital → Distrito das Marcas → Hub Global). Mudar de sede custa R$ 40 mil / 150 mil / 450 mil / 1,2 mi com reputação 15 / 35 / 55 / 75, abre o nível 1 da região nova, muda a parede e a vista da janela, e começa uma semana de mudança (produtividade ×0,85, caixas no escritório). Cada região tem 3–4 níveis de expansão (+2 lugares, barata); 16 níveis no total. O tier máximo dos prospects passa a ser min(região, 1 + equipe/3). A cidade é viva (`src/ui/world_map_life.gd`, rotas em `data/map_life.json`): carros na avenida e nas ruas, barcos, nuvens com sombra, avião com rastro, pássaros, espuma, pino pulsando, bandeira nas rivais; à noite as janelas acendem e o farol gira; na mudança de sede um caminhão atravessa a avenida com a câmera acompanhando |
| Escritório | `office_system.gd`, `src/office/` | 16 níveis gerados por `tools/gen_layouts.py` (4 → 28 lugares) com layout em tiles, mesas agrupadas em ilhas com tapete e divisória por setor e ala de convivência com mesa de reunião; ampliação pela aba Equipe ou Empresa; funcionários andam entre mesa, café e sofá, com barra de moral sobre a cabeça; arrastar com um dedo e zoom com pinça (ou roda do mouse); toque no avatar abre a jornada |
| Moral | `employee_system.gd`, `office_system.gd` | Barra por pessoa (campo `motivation`) que tende a 55 e tem teto 75 + mobília. Sobe com entregas de 4–5 estrelas, promoções, RH, eventos e prêmios; cai todo dia com pressões visíveis na ficha (estresse acima de 60, salário defasado há 12 meses, 15 dias sem projeto, escritório lotado, projeto atrasado) e com entregas de 1–2 estrelas. A régua do `sim_test` exige moral média entre 45 e 75 |
| Humores | `employee_system.gd` (`mood_of`), `src/office/worker.gd`, `assets/art/moods/` | Estado visível no personagem e na ficha: 🔥 burnout (cabeça vermelha, vapor e estouro), 💦 exausto (suor, anda devagar), 🎵 feliz (notas, pulinhos), 🌧️ desanimado (nuvem), ✨ celebrando (brilhos por 3 dias após promoção, prêmio ou 5 estrelas), 💼 assediado por concorrente (envelope). Quem sai da agência atravessa o escritório com uma caixa e some na porta |
| RH | `hr_system.gd`, `data/hr_actions.json`, `hr_screen.gd` | Aba própria. Contrata-se uma analista (custo único + salário mensal; exige escritório profissional e reputação 30) que ganha um anexo com divisória no escritório. Libera pizza, happy hour, feriado prolongado, energético com paçoca (buff), festa, bem-estar, retiro e as políticas pet friendly (cachorro e depois gato, permanentes no escritório, com moral diária) |
| Mobília | `office_system.gd`, `data/furniture.json` | 15 itens comprados na aba Empresa, cada um liberado por um nível de escritório (recepção no centro; sala envidraçada e estúdio na capital; cozinha e academia no distrito; war room e terraço no hub global): teto de moral, moral diária, estresse, produtividade e bônus permanentes de atributo (valem para quem entra depois). Toda mobília aparece no escritório: troca de sprite (cadeiras ergonômicas, monitores ultrawide, café premium), quadro na parede ou item nos slots de decoração |
| Eventos da agência | `agency_event_system.gd`, `data/agency_events.json` | Abrem com reputação 40 e cada um exige uma região mínima (palestra e meetup no bairro; feira de carreiras e workshop no centro; podcast e congresso na capital; palco principal no distrito; feira internacional no hub global): custam dinheiro e/ou pessoas por alguns dias e rendem reputação, prospects, candidatos, moral ou patrocínio |
| Cenas de evento | `src/office/event_stage.gd`, `data/scenes.json`, `assets/art/scenes/` | A "câmera" sai do escritório e mostra o time no palco da premiação, no auditório da palestra, no estande da feira, no meetup, no estúdio do podcast, na sala de reunião com o investidor ou na coletiva de imprensa — cenário por evento (`scene` em `events.json`/`agency_events.json`), montado na hora com os próprios funcionários (a primeira pessoa segura o troféu). O popup do evento passa a abrir abaixo da cena |
| Atributos por serviço | `project_system.gd` (`indicator_weights`, `team_fit`) | Os pesos da nota vêm dos serviços do projeto: tráfego pago puxa Performance, design puxa Criatividade, CRM puxa Execução. A média da equipe nos atributos que o serviço pede soma até +15 ou tira até −9 pontos da nota, e a ficha de cada pessoa mostra em que serviços ela rende mais |
| Especialização de carreira | `employee_system.gd`, `popups.gd` | Equipe → 🎯 Especializar: quem tem aptidão 50+ num serviço liberado entra numa trilha de 10–21 dias (R$ 3 mil a 15 mil, conforme o tier do serviço). No fim muda de cargo, ganha +7 no atributo principal e +4 no secundário do serviço e passa a render o bônus de especialista nos projetos dele |
| Decisões no projeto | `data/decisions.json`, `project_system.gd` | Nem todo projeto tem uma: a chance é diária (7%) entre 20% e 75% de progresso, e cada projeto recebe no máximo uma. 12 dilemas de rotina (pedido de última hora, ideia ousada, dado estranho, virar a noite…) com 2–3 escolhas que mexem em indicadores, prazo, esforço, orçamento, caixa, moral, estresse, relação com o cliente ou reputação |
| Talento raro | `talent_system.gd` | De tempos em tempos (a partir do dia 180, com 150 dias de intervalo) aparece um profissional muito acima da média, com prazo de 12 dias e bônus de contratação de 2 salários. Entra em Equipe → Candidatos marcado como lenda; se o prazo passar, uma rival leva e fica +4 mais forte |
| Crises regionais | `data/crises.json`, `crisis_system.gd` | 10 crises que pegam a região inteira por alguns dias (apagão, enchente, greve, queda da operadora, onda de calor, aperto econômico, obra no prédio, gripe, vazamento, câmbio): derrubam produtividade e prospects, custam moral e caixa — e também tiram força das rivais da região. Aviso em vermelho no topo do feed e no calendário |
| Vida no escritório | `src/office/office_view.gd`, `season_system.gd`, `data/seasons.json`, `assets/art/seasons/` | Relógio no HUD (08:00–20:00 por dia de jogo): o céu atrás das janelas muda com a hora (sol, nuvens, pôr do sol, lua e estrelas), a luz do escritório (multiplicativa) fica alaranjada a partir das 16h e quase apagada à noite, quando só as luminárias das mesas iluminam (o vidro das janelas fica de fora). Todos os emojis da interface usam a fonte Noto Emoji embutida como fallback (`assets/fonts/NotoEmoji.ttf`, OFL); os botões do HUD usam ícones pixel art. Datas comemorativas por mês só visuais (Carnaval, Festa Junina, Halloween, Black Friday, Natal): guirlanda na parede + objeto no chão, com aviso no feed. Balões de "pensamento" (💡 ☕ 😴) aparecem sobre quem está trabalhando ou descansando |
| Save/Load | `save_system.gd` | 5 espaços de save em JSON (`user://saves/slot_N.json`), autosave mensal no espaço da partida em andamento e botão na aba Empresa. "Continuar" na tela inicial lista os espaços com agência, data, caixa e tamanho da equipe, e cada um pode ser apagado (confirmação em dois toques). O save antigo de arquivo único é migrado para o espaço 1 |
| UI | `src/ui/` | Tela inicial com a cidade da agência (fundo e logo gerados em `tools/gen_art.py`), HUD, escritório, feed de humor, 6 abas (Equipe, Clientes, Projetos, Empresa, RH, Agência), modais |
| Fonte pixel art | `tools/gen_font.py`, `assets/fonts/pixel.fnt` | Bitmap font 5×7 com acentuação (á é í ó ú ã õ â ê ô ç), gerada por código; usada em títulos e números do HUD (`UIKit.pixel_font()`) |
| Som | `src/core/audio_manager.gd`, `tools/gen_audio.py` | Trilha de ~58 s em loop (acordes, baixo, melodia e bateria 8-bit) que toca desde a tela inicial, e 9 efeitos sonoros — tudo sintetizado por código; autoload `Audio` reage aos sinais do `EventBus`; botão de mudo 🔊/🔇 na tela inicial e no HUD (e toggles na aba Empresa). Som ambiente do escritório em loop de 16 s (ar-condicionado, teclados, mouse, papel, notificação) que fica mais presente conforme a equipe cresce; toggle próprio "🏢 Escritório" |

Detalhes de fórmulas e fluxo em `docs/ARQUITETURA.md`. Histórico de desenvolvimento, decisões tomadas e guia de retomada em `docs/HISTORICO.md`.

## Próximos passos sugeridos

1. **Balanceamento** com testes de jogadores reais. A simulação em `tests/sim_test.gd` imprime a curva ano a ano e falha se fugir da régua do GDD §53 (ver `docs/ARQUITETURA.md`).
2. ~~Arte definitiva~~ — feito: arte v2 em `tools/gen_art.py` (tile 32 px). Para trocar por arte desenhada à mão, mantenha os tamanhos gerados e a estrutura de camadas dos personagens (`assets/art/characters/`).
3. ~~Fonte pixel art e sons (`GDD §40–41`)~~ — feito: `assets/fonts/pixel.fnt` e `src/core/audio_manager.gd`.
4. ~~Conteúdo: mais clientes, eventos, eras históricas e serviços de endgame~~ — feito: `era_system.gd`, `data/eras.json`.
5. ~~Departamentos, gerentes e concorrentes~~ — feito: `department_system.gd`, `competitor_system.gd`. Falta: imprensa/aquisições e expansão internacional (resto da Fase 4 do roadmap).
6. ~~Mais ícones e imagens na interface~~ — feito: emojis em títulos, botões, cartões e na navegação inferior (ícone em cima, rótulo curto embaixo) para reduzir o peso visual de texto puro, principalmente para quem está começando.
