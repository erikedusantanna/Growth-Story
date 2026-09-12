# A Growth Story — Histórico de desenvolvimento e guia de retomada

> **Para que serve este documento.** Junto com o GDD (`docs/GDD.md`), a arquitetura
> (`docs/ARQUITETURA.md`) e o README, ele dá a uma IA (ou a uma pessoa) todo o contexto para
> retomar o projeto de onde parou: o que foi construído, em que ordem, por quê, o que o usuário
> pediu e aprovou, o que ficou pendente e como trabalhar no repositório sem quebrar nada.
>
> Fontes: histórico de commits e pull requests do repositório `erikedusantanna/Growth-Story`,
> os documentos citados acima e a sessão de trabalho com o Claude Code. Nada aqui foi inventado;
> quando algo não foi confirmado pelo usuário, está marcado como **decisão tomada sem
> resposta** ou **pendente**.
>
> Estado em que este documento foi escrito: `main` no merge do PR #13 (10/09/2026),
> 13 PRs mesclados, 318 arquivos versionados, ~7.550 linhas de GDScript em `src/`,
> ~2.970 linhas de Python em `tools/`, ~1.000 linhas de testes em `tests/`.

---

## 1. O projeto em uma página

- **O que é:** tycoon/simulação mobile (Android primeiro, também Windows) inspirado na filosofia
  de *Game Dev Story*: você começa como freelancer de marketing digital e evolui até dono de agência.
  Nome provisório "A Growth Story" (no GDD aparece como "Agency Story").
- **Quem pede:** Erik (`erikedusantanna` no GitHub), dono do repositório, perfil não técnico:
  valida **jogando** (APK no celular, executável no Windows) e olhando screenshots. A conta usada
  pertence a uma unidade da V4 Company (assessoria de marketing e vendas). O tema do jogo é o
  negócio real dele, então a fidelidade ao "como uma agência funciona" importa.
- **Como a IA deve se comportar (preferência declarada do usuário):** ser específica e direta,
  **nunca inventar informação** — pesquisar, consultar ou dizer que não sabe.
- **Stack:** Godot 4.3 (GDScript), renderer Mobile, viewport 540×960 retrato. Conteúdo em JSON
  (`data/`), lógica em sistemas independentes (`src/systems/`), UI construída em código
  (`src/ui/`, `src/office/`). Arte, fonte e áudio **100% gerados por script Python** em `tools/`
  (sem dependências, sem assets externos). Testes headless em `tests/` rodam no CI a cada push/PR,
  que também gera APK e executável Windows.
- **Documentos de referência:**
  - `docs/GDD.md` — Game Design Document v0.1 (55 seções). O que o jogo deve ser. Seções mais
    citadas no código: §23 (eras), §27 (reputação), §29 (fases da agência), §30–31 (departamentos,
    o jogador deixa de executar), §35 (oportunidades), §36 (MVP), §37 (primeiro ano), §40–41
    (estética e som), §48 (roadmap em 5 fases), §53 (visão final/régua de crescimento).
  - `docs/ARQUITETURA.md` — como o código está organizado, o ciclo do dia, **todas as fórmulas**
    (orçamento, prazo, nota, estrelas, reputação, proposta, custos), como adicionar conteúdo.
    Ainda não cobre briefings, química, prêmios, guia inicial e vida no escritório (ver §6 deste
    documento; a tabela "O que já existe" do README cobre).
  - `README.md` — como rodar, testar, instalar no celular e no Windows; tabela de tudo que existe.

---

## 2. Como o trabalho foi conduzido (processo que deve continuar)

1. **Uma branch de trabalho:** `claude/growth-story-mobile-game-sfwg9e`. Todo PR sai dela contra
   `main`. Depois de cada merge, a branch é **reiniciada a partir de `origin/main`**
   (`git fetch origin main && git checkout -B claude/growth-story-mobile-game-sfwg9e origin/main`)
   e enviada de novo — nunca se empilham commits novos sobre história já mesclada.
2. **PRs em rascunho (draft)** criados pela IA; **o usuário faz o merge** (ele marca "pronto para
   revisão" e mescla em seguida, em geral em minutos). A IA acompanha o CI do PR e corrige se ficar
   vermelho. Depois do merge, apaga o lembrete de check-in e reinicia a branch.
3. **Ciclo de cada entrega:** pedido do usuário (muitas vezes feedback de uma sessão de jogo) →
   implementação → `--import` → `sim_test` → `ui_smoke_test` → tour de screenshots (conferido
   visualmente pela IA) → README/ARQUITETURA atualizados → commit → push → PR draft →
   screenshots enviadas ao usuário com um resumo curto em português.
4. **Perguntas ao usuário** são feitas em lote, só quando a resposta muda o trabalho; enquanto
   isso a IA já começa pelo que não depende da resposta. Quando não há resposta, decide e
   **registra que decidiu sozinha** (ver §5).
5. **Convenções de commit e PR:** mensagens em português, descritivas, com o que mudou e o
   porquê. Commits terminam com `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` e
   `Claude-Session: https://claude.ai/code/session_01VHKpn2xx3REFSoFH9J4JN9`; PRs terminam com
   `🤖 Generated with [Claude Code](https://claude.com/claude-code)` e a URL da sessão.
   **Nunca** colocar identificador de modelo em código, comentários ou nos corpos.
6. **Regra de ouro do código:** a UI nunca altera estado; chama métodos dos sistemas
   (`Game.projects.create_project(...)`), que validam, aplicam e emitem `EventBus.state_changed`.
   É isso que permite rodar o jogo inteiro sem interface nos testes.

---

## 3. Linha do tempo (PR a PR)

Datas são as do merge. Cada bloco traz **o que entrou**, **por que** (pedido ou feedback do
usuário) e **decisões** relevantes.

### PR #1 — Base do jogo: mecânicas do MVP em Godot 4 (08/09/2026)
- Protótipo completo do loop do GDD §36: prospectar → proposta → diagnóstico (revela o problema
  real oculto) → estratégia (1–3 serviços) + equipe → execução diária com 4 indicadores
  (Estratégia, Criatividade, Execução, Performance) → avaliação em estrelas → pagamento,
  reputação, corações do cliente.
- Sistemas independentes (tempo, funcionários, clientes, projetos, serviços, finanças,
  reputação, eventos, escritório, save/load JSON), conteúdo em JSON (11 serviços, 12 clientes,
  20 eventos, 7 cursos, 4 escritórios), retainers de 6 ciclos (MRR), combinações por segmento
  (perfect match / ruim), carreira em 8 níveis, burnout, 8 personalidades de funcionário e 8 de
  cliente. UI mobile em código, sprites placeholder (`tools/gen_sprites.py`), testes headless
  + CI.
- Fora do escopo declarado: arte definitiva, fonte, sons, balanceamento com jogadores, fases
  3–5 do roadmap.

### PR #2 — Ritmo cozy, proposta com preço, jornada e objetivos (08/09)
- Origem: **primeiro teste jogado** pelo usuário.
- Dia passa em 3,5 s no 1x (antes 1,4 s); velocidades 1x/2x/3x. Cooldown por evento (padrão
  120 dias) porque o "workshop gratuito" repetia demais.
- **Jornada do colaborador** (linha do tempo por pessoa), **slider de preço na proposta**
  (60%–140% do orçamento; desconto fecha mais fácil, prêmio eleva a expectativa) e **13
  objetivos sequenciais** do primeiro ano (GDD §37) mostrados acima do feed.

### PR #3 — Escritório maior no início, ampliação visível, APK pelo GitHub (08/09)
- Origem: segundo teste jogado (escritório).
- Capacidades 4/7/12/18; aba Equipe ganha faixa de lotação com botão Ampliar.
- **Workflow `android.yml`** gera o APK de debug como artifact a cada push/PR (o usuário instala
  no celular). Ícones de launcher em pixel art.

### PR #4 — Balanceamento (régua GDD §53) e direção visual (08/09)
- **Régua de crescimento** no `sim_test`: 3 anos com bot ganancioso; falha se ano 1 ou ano 3
  saírem das faixas do GDD. Antes: ano 3 com 18 pessoas e R$ 3,7 mi; depois: 3–4 pessoas e
  R$ 289 mil. Fórmulas em `ARQUITETURA.md`.
- **Direção visual aprovada:** perspectiva 3/4 (top-down inclinado), arte gerada por código em
  `tools/gen_art.py`, personagens 24×32 em camadas recoloríveis, interface clara (painéis brancos,
  fundo creme, laranja de destaque), balões de fala e números flutuantes no escritório.

### PR #5 — Reputação legível, previsão de estrelas, sala de treinamento, toque no avatar (08/09)
- Origem: terceiro teste jogado ("reputação difícil e opaca, treinamento invisível").
- Detalhamento "O que pesou na nota" no resultado e **na prévia** do novo projeto, com dicas.
  Bônus controláveis: prazo +5, diagnóstico +8 (+3 se acertou sem diagnosticar), especialista
  +4/serviço (máx. +8). Fórmula de reputação `(estrelas − 2) × (0,4 + 0,3 × tier)`.
- Quem vai a curso sai pela porta; **sala de aula** aparece sobre o escritório. Toque no avatar
  abre a jornada.

### PR #6 — Moral com teto, RH, mobília com modificadores, eventos da agência (08/09)
- Quatro mecânicas pedidas "para aumentar a vida útil do jogo": moral (`motivation`) com teto
  dado pela mobília; ações de RH (`hr_actions.json`); mobília comprada na aba Empresa com
  modificadores e bônus permanentes; eventos da agência (palestra, feira, meetup…) que custam
  gente/dinheiro e rendem reputação, prospects, candidatos.
- Aba "Desbloqueios" virou **Agência**.

### PR #7 — RH contratável com sala, mobília visível, pets, barra de moral, câmera com zoom (09/09)
- Aba **RH** própria (6 abas). RH deixa de abrir só por reputação: é preciso **contratar a
  analista** (R$ 12.000 + R$ 3.000/mês; exige escritório 3 e reputação 30), que ganha um anexo com
  divisória no escritório. Pets (cachorro, depois gato) moram no escritório e dão moral diária.
- Mobília troca sprites (cadeira ergonômica, monitor ultrawide, café premium). Barra de moral
  sobre a cabeça. Escritório arrastável com um dedo, zoom por pinça/roda.

### PR #8 — Conteúdo, fonte/sons, eras, departamentos/concorrência, ícones (10/09)
- Rodada combinada em 5 fases no mesmo branch:
  1. **Conteúdo** contra a repetição: tier endgame de serviços (IA, MarTech, Dados, Tecnologia
     Proprietária, Consultoria Enterprise), 23 clientes, 27 eventos.
  2. **Fonte pixel art 5×7** com acentuação (`tools/gen_font.py` → BMFont) e **9 efeitos + trilha**
     sintetizados (`tools/gen_audio.py`). Bug real: `AudioServer.get_driver_name()` não existe em
     Godot 4 → `DisplayServer.get_name() == "headless"`.
  3. **Eras históricas** (GDD §23): 6 eras de 2010 a 2025+, serviços "em alta" rendem +3.
  4. **Departamentos e concorrência** (recorte combinado da Fase 4 do roadmap): gerente + 2 no
     mesmo departamento = +8% produtividade; prospects esquecidos são fechados por rivais.
     Ficaram de fora: imprensa, aquisições, expansão internacional.
  5. **Mais ícones** (emojis) em toda a interface; barra de navegação com ícone em cima e rótulo
     embaixo porque a linha única cortava ("Clien…").

### PR #9 — Setoriza o escritório: mesas em ilhas, tapetes e divisórias (10/09)
- Origem: referências de layout enviadas pelo usuário (ele preferiu a planta top-down).
- Decisões do usuário, perguntadas antes: **"Setorizar agora, isométrico depois"** e setores
  **puramente visuais**, sem vínculo com departamentos. Layouts em `offices.json` ganham `zones`
  (tapetes) e `dividers`. A migração para visão isométrica ficou como projeto dedicado; depois o
  usuário decidiu **manter o top-down** (ver PR #10).

### PR #10 — Arte v2 (tile 32 px, chibi), 4 direções e cenas de evento (10/09)
- Origem: "quero melhorar significativamente os gráficos em pixel art". Perguntado se a IA cria
  ou ele envia sprites: escolha **híbrida** (ele manda referências de estilo, a IA desenha por
  código) e **personagens coerentes com as referências** (chibi 4 direções, tileset de escritório).
  Ele gostou do "sombreamento" e dos "personagens fofos".
- Prova de estilo em duas rodadas. Feedback da 1ª: corpo mais magro e menos quadrado, cabeça
  grande mantida ("não tem problema ficar cabeçudo"), rosto mais detalhado, mais sombreamento,
  sem crachá, mais variações de cabelo, grade do piso aprovada. 2ª rodada: **aprovado**.
- Resultado: personagem 32×48, 7 cabelos, óculos, 4 poses × 4 direções; 23 peças de mobília em
  2×; tile 32 px; zoom 1×–2×.
- **Cenas de evento**: pedido do usuário para "dar mais vida" e reduzir a densidade de texto em
  eventos/premiações. Forma escolhida por ele: **substituir o painel do escritório, como se a
  câmera cortasse para a cena**. 7 cenários (`data/scenes.json`) montados com os funcionários
  reais; o popup abre abaixo da cena. "Não precisa encolher o painel" (resposta dele).
- Bug real corrigido: `EventSystem.trigger()` descartava o campo `scene` ao montar `pending_event`.

### PR #11 — Executável portátil para Windows (10/09)
- Pedido direto. Preset `Windows Desktop` (x86_64, `embed_pck`), workflow `windows.yml`, artifact
  `growth-story-windows`. O `.exe` tem ~85 MB, não cabe no envio direto pelo chat (limite 30 MB):
  o usuário baixa pela aba Actions. Ícone do exe ainda é o padrão do Godot (falta `rcedit`).

### PR #12 — Música que toca de verdade, botão de mudo, tela inicial nova (10/09)
- Pedido: em vez de rebalancear, **sugerir melhorias** (lista em §4), inserir música de fundo com
  mudo na tela e refazer a tela inicial com base numa imagem de referência (logo "A GROWTH STORY"
  sobre uma cidade pixel, botões Novo Jogo / Continuar / Recordes).
- O usuário disse não ter ouvido a trilha existente. Diagnóstico: **bug real** — a trilha nunca
  soava porque o loop era ligado com `loop_end = 0` (o stream voltava ao início a cada quadro) e o
  volume estava ~20 dB abaixo dos efeitos. Correções: `edit/loop_mode=1` no `.import`, guarda em
  tempo de execução, −7 dB, trilha nova de 57,6 s, música desde a tela inicial, botão 🔊/🔇 no HUD
  e na tela inicial.
- Tela inicial: a referência era imagem gerada por IA (inconsistente), então a composição foi
  **recriada** no traço do jogo em `tools/gen_art.py` (fundo 270×480 e logo 240×118). Decisões do
  usuário: **"Só novo jogo"** (sem botão Recordes; "Continuar" aparece só quando há save) e
  nomes da agência/fundador num **passo seguinte** ao clicar em Novo Jogo.
- Este PR também levou o **item 9 (vida no escritório)**, ver PR #13 abaixo, porque o usuário
  mesclou depois do segundo push.

### PR #13 — Guia inicial, briefings, química da equipe, Prêmios do Marketing (10/09)
- Fecha o lote escolhido pelo usuário: itens **1, 4, 5, 7 e 9** da lista de sugestões (§4).
- **Item 9 – Vida no escritório** (commit `4aa0a68`, entrou no #12): relógio no HUD
  (08:00–20:00 por dia de jogo), vidro da janela transparente com céu desenhado pela hora (sol,
  nuvens, pôr do sol, lua, estrelas), tinta de luz e luminárias aditivas à noite, datas
  comemorativas mensais (`data/seasons.json` + `assets/art/seasons/`), balões de pensamento e som
  ambiente em loop de 16 s (`gen_ambience`) que cresce com a equipe.
- **Item 4 – Guia inicial** (`497b64f`): `data/tutorial.json` + `TutorialOverlay` (CanvasLayer 12)
  destacam o botão certo nos 4 primeiros objetivos, também dentro dos modais; botões marcados
  com `set_meta("tutorial", tag)`; "Pular guia"; `tutorial_done` no save.
- **Item 1 – Briefings** (`85db4b7`): 10 temas em `data/briefings.json`; cada cliente ativo
  recebe um (fica em `Client.briefing` até a entrega); muda pesos da nota, prazo, valor e pede
  serviços-chave (+4 cada, até +8); entra no título do projeto.
- **Item 7 – Química** (`85db4b7`): 10 pares em `data/chemistry.json` (5 sinergias, 5 atritos);
  soma ±3 → ±3 na nota por ponto, ±5% de ritmo, moral/estresse diários.
- **Item 5 – Prêmios do Marketing** (`85db4b7`): `AwardSystem` na virada do ano com cena de
  palco; Campanha, Agência e Profissional do Ano; efeitos em reputação e moral; histórico na aba
  Empresa.

---

## 4. A lista de sugestões de melhoria (referência para o próximo lote)

Apresentada ao usuário no PR #12, ordenada por impacto ÷ esforço. Ele escolheu **1, 4, 5, 7 e 9**
("9 é incrível"); todos entregues. As demais continuam como candidatas:

| # | Sugestão | Situação |
|---|---|---|
| 1 | Briefings variados por projeto | **Feito** (PR #13) |
| 2 | Decisões durante o projeto (1–2 momentos com escolha rápida, usando eventos e cenas) | Pendente |
| 3 | Identidade da agência (perks por fase de reputação: performance, branding, dados, atendimento) | Pendente |
| 4 | Tutorial guiado | **Feito** (PR #13) |
| 5 | Prêmio anual | **Feito** (PR #13) |
| 6 | Recordes e "nova partida+" (tela de recordes como na referência da tela inicial) | Pendente — o usuário optou por "só Novo Jogo" na tela inicial por enquanto |
| 7 | Sinergia e atrito na equipe | **Feito** (PR #13) |
| 8 | Fluxo de caixa com tensão (pagamentos atrasados, imposto anual) | Pendente |
| 9 | Vida no escritório | **Feito** (PR #12/#13) |
| 10 | Resto da Fase 4 do GDD: imprensa, aquisições, expansão internacional | Pendente (maior esforço) |

---

## 5. Decisões de design e técnicas consolidadas (com o porquê)

**Tomadas com o usuário**
- Visão **top-down 3/4, não isométrica** (avaliado o custo da migração; ele preferiu seguir e
  melhorar a pixel art no formato atual).
- Arte **gerada por código** a partir de referências de estilo (híbrido). Estilo aprovado: contorno
  azul-marinho, 3 tons por material, chibi cabeçudo e magro, rosto detalhado, sem crachá.
- Setores do escritório são **só visuais**; departamentos (mecânica) são outra coisa.
- Cenas de evento **substituem o painel do escritório** (corte de câmera), popup abaixo, painel
  sem encolher.
- Tela inicial com **Novo Jogo / Continuar**, sem Recordes; nomes num passo seguinte.
- Ritmo cozy (3,5 s por dia), objetivos guiando o primeiro ano, reputação e nota **legíveis**
  (detalhamento e previsão) — respostas diretas a feedback de jogo.
- Lote de melhorias: itens 1, 4, 5, 7 e 9.

**Tomadas pela IA sem resposta do usuário (fáceis de mudar)**
- Datas comemorativas: Carnaval (fev), Festa Junina (jun), Halloween (out), Black Friday (nov),
  Natal (dez). Proposta enviada, sem confirmação.
- Som ambiente **ligado por padrão**, com toggle próprio ("🏢 Escritório") separado dos efeitos.
- Guia inicial cobre os **4 primeiros objetivos** (o item falava em 3).
- Números de balanceamento de briefings/química/prêmios (ver §6). A simulação de 3 anos continuou
  dentro da régua do GDD após essas mudanças.

**Técnicas**
- Tudo que é salvo passa por `GameState.to_dict()/from_dict()`; novos campos entram nos dois e
  no `stats` padrão (o teste de roundtrip compara o estado antes/depois via JSON normalizado).
- Áudio em loop: WAV precisa de `edit/loop_mode=1` no `.import` **e** de `loop_end > 0`
  (`Audio._load_loop()` garante). Em ambiente headless o áudio fica mudo de propósito.
- Personagem: folha 4×4 (`frame = direção × 4 + pose`), camadas `outline/skin/legs/shirt/hair`;
  `skin`, `shirt` e `hair` são cinzas modulados pela cor do funcionário.
- Classes novas com `class_name` só são vistas depois de `godot --headless --path . --import`
  (cache em `.godot/global_script_class_cache.cfg`); o CI faz isso antes dos testes.
- Em GDScript, `var x := expr` falha em parse quando `expr` vem de um objeto sem tipo (ex.: `game`
  nos testes é `Variant`): usar `var x: Tipo = expr`.
- O tour de screenshots é a "prova visual": toda mudança de interface/arte foi conferida por
  imagem antes do push (nav bar cortando, tapetes escuros demais, pessoas gigantes na tela
  inicial e halos de luminária chapados foram pegos assim).

---

## 6. Estado atual do jogo (resumo; tabela completa no README)

**Loop e economia:** prospects → proposta com preço → diagnóstico → projeto (briefing + 1–3
serviços + equipe) → execução diária → nota 0–100 → 1–5 estrelas → pagamento, reputação, relação.
Retainers, combinações por segmento, especialistas, serviços em alta por era, expectativa do
cliente, dificuldade por tier, atraso. Custos fixos mensais, falência abaixo de −R$ 30.000.

**Conteúdo (`data/`):** 16 serviços em 4 tiers · 23 clientes escritos + geração procedural ·
27 eventos com escolhas · 7 eventos da agência · 7 cursos · 14 objetivos · 6 eras · 8 mobílias ·
ações de RH + contratação da analista · 4 escritórios · 7 cenários de evento · 5 datas
comemorativas · 10 briefings · 10 pares de química · 12 passos de guia.

**Pessoas:** 6 atributos, 8 personalidades, carreira em 8 níveis, moral com teto, estresse,
lealdade, burnout, pedidos de demissão, jornada, departamentos (escritório 4), química por pares.

**Escritório vivo:** 4 níveis com ilhas, tapetes e divisórias; personagens andam entre mesa,
café e sofá; pets; barra de moral; sala de treinamento; anexo do RH; relógio e ciclo de luz;
decoração sazonal; balões de pensamento; som ambiente; arrastar e zoom.

**Reconhecimento:** eventos com cena (palco, auditório, estande, meetup, estúdio, reunião,
coletiva) e Prêmios do Marketing anuais.

**Números das mecânicas mais recentes (para ajustar balanceamento):**
- Briefing: `budget_mult` 0,9–1,3; `deadline_mult` 0,6–1,4 (mínimo 12 dias); pesos por indicador
  0,6–1,5; serviço-chave +4 (máx. +8); crise `rep_mult` 1,5.
- Química: par sinergia +1 / atrito −1, soma limitada a ±3; nota ±3 por ponto; ritmo ±5% por ponto;
  moral +0,06/dia por ponto positivo; estresse +0,3/dia por ponto negativo.
- Prêmios: Campanha do Ano = melhor nota do ano, vence com 5 estrelas, indicação com 4;
  Agência do Ano = entregas ×3 + cases 5★ ×10 + clientes ativos ×2 + reputação ×0,5 contra
  45 + 8 por ano (indicação a partir de 60% da meta); Profissional = mais participações, vence com
  3+ entregas e média ≥ 4,0. Vencer: Agência +6 rep e +8 moral geral; Campanha +4 rep e +10 moral
  na equipe; Profissional +15 moral e +10 lealdade; indicação +1 rep.
- Vida no escritório: dia de trabalho 08:00–20:00 mapeado na fração do dia; chaves de luz em
  `OfficeView.LIGHT_KEYS`; ambiente −18 dB base, +0,66 dB por pessoa até 10.

**Régua de crescimento (última medição, seed 12345):** ano 1 = 4 pessoas, R$ 100 mil, rep 26 ·
ano 2 = 4 pessoas, R$ 369 mil, rep 67 · ano 3 = 6 pessoas, R$ 458 mil, rep 78. O bot é ótimo;
um jogador real cresce mais devagar.

---

## 7. Ambiente e comandos (como a IA trabalhou)

```bash
# Godot 4.3 headless (no CI é baixado do GitHub releases; na sessão ficou no scratchpad)
godot --headless --path . --import                        # registra class_name novas
godot --headless --path . res://tests/sim_test.tscn       # 3 anos + save/load + blocos de mecânicas
godot --headless --path . res://tests/ui_smoke_test.tscn  # abre todas as telas e popups
xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/screenshot_tour.tscn
#   → capturas em ~/.local/share/godot/app_userdata/A Growth Story/shots/*.png

python3 tools/gen_art.py --export      # regenera assets/art (tiles, mobília, personagens, cenas, título, sazonal)
python3 tools/gen_art.py --proof x.png # prova de estilo sem tocar no jogo (também --sheet, --furniture, --scenes, --title)
python3 tools/gen_audio.py             # regenera sfx, trilha e ambiente (depois: --import e conferir loop_mode=1)
python3 tools/gen_icons.py             # ícones 10×10 do HUD
python3 tools/gen_font.py              # fonte pixel (atenção: importar o módulo já regenera a fonte)

godot --headless --path . --export-release "Windows Desktop" build/growth-story.exe
godot --headless --path . --export-debug Android build/growth-story.apk
```

- Dicas que pouparam tempo: rodar testes longos com `stdbuf -oL ... > log` e esperar com um
  `until grep -q ... ; do sleep 1; done`; um teste com erro de parse **não termina sozinho** (o
  Godot fica aberto) — matar o processo e ler o topo do log; conferir indentação real com
  `cat -A` antes de editar GDScript (tabs).
- Workflows: `tests.yml` (import + sim + smoke), `android.yml` (APK debug, artifact
  `growth-story-apk`), `windows.yml` (exe, artifact `growth-story-windows`). Rodam em push e PR.
- Save do jogador: `user://savegame.json` (Windows: `%APPDATA%\Godot\app_userdata\A Growth Story\`).
  Preferências de áudio em `user://audio_settings.cfg`.

---

## 8. Pendências e próximos passos sugeridos

**Da lista de melhorias (§4):** itens 2, 3, 6, 8 e 10. Ordem sugerida pela IA na época: 2 e 6
primeiro (usam infraestrutura existente e dão motivo para rejogar), depois 3 e 8, e por último 10.

**Confirmações em aberto com o usuário:**
- Conferir no aparelho dele se a **música toca** e se o volume ficou equilibrado (bug corrigido
  no #12, sem retorno explícito).
- Aprovar as **datas comemorativas** e o padrão do **som ambiente** (decisões da IA, §5).
- Feedback jogado sobre guia, briefings, química e prêmios (entregues no #13, mesclado sem
  comentários).

**Do GDD ainda não implementado (verificado no código):** funcionários lendários (§8), arquétipos
de agência (§33), sistema de crises como sistema próprio (§34; hoje existem eventos e o briefing
"Gestão de crise"), endgame com aquisições e grupo (§32), imprensa/aquisições/expansão
internacional (Fase 4, §48), monetização (§42), recordes/nova partida+. Visão isométrica foi
avaliada e **descartada** pelo usuário; não retomar sem pedido.

**Técnicas:** ícone próprio no `.exe` (rcedit); keystore de release para Play Store (hoje só
debug); `ARQUITETURA.md` ainda não descreve briefings, química, prêmios, guia e vida no
escritório (o README descreve); balanceamento com jogadores reais continua sendo o item 1 do
README.

---

## 8b. Bloco B do plano de expansão (moral + humores) — feito nesta sessão

- Moral: ponto de equilíbrio 55, teto base 75, pressões diárias (estresse, salário defasado, sem desafio,
  escritório lotado, projeto atrasado), ganhos menores por estrela, mobília/pets com metade da moral diária;
  produtividade e Execução recalibradas para o novo ponto de operação. Régua do `sim_test` com moral média.
- Humores visíveis no personagem e na ficha; quem sai atravessa o escritório com a caixa.
- Números finais ficaram em `docs/ARQUITETURA.md` (seção Moral). O restante do plano (mapa isométrico,
  regiões, concorrentes reais, eventos/mobília por região, projetos complexos) segue em `docs/PLANO_WORLD_MAP.md`.

## 8c. Bloco A do plano (World Map e regiões) — feito nesta sessão

- `tools/gen_layouts.py` gera `data/offices.json` (16 níveis) e `data/regions.json`; `office_level` virou índice
  global e os limiares de RH/mobília/departamentos/eventos foram remapeados (4, 7, 11).
- Mapa isométrico gerado em `tools/gen_art.py` (`world_map`, `iso_box`, `fill_poly`), `WorldMapScreen`, botão 🌎
  no HUD (a fonte não tem o emoji 🗺️), parede e janela por região, semana de mudança com caixas.
- O bot da simulação quase nunca junta caixa para mudar de sede; a régua continua sendo medida na Região 1.
  Balanceamento das mudanças de sede depende de teste jogado.

## 8d. Bloco C do plano (concorrentes reais) — feito nesta sessão

- `data/competitors.json` com agências por região; `CompetitorSystem` reescrito (carteira/equipe geradas,
  investidas da rival por evento, investidas do jogador pelo painel da rival no mapa, cooldown de 90 dias,
  reputação exata −5/−3 via `ReputationSystem.penalize`).
- Anoitecer/amanhecer suavizados (pedido do usuário): luz desenhada persegue a luz da hora com fade
  (`LIGHT_FADE_RATE`), entardecer começa às 16h, roxo às 18h30, noite às 20h; a virada 20h → 8h vira um
  amanhecer lento.

## 8e. Bloco D do plano (conteúdo por região) — feito nesta sessão

- Eventos com `min_region`/`max_region` (10 novos, 2 por região), eventos da agência com `requires_region`
  (+ feira internacional), 7 mobílias novas por nível (com sprites em `tools/gen_art.py`), 8 clientes tier 4–5,
  projetos complexos para tier 5 (equipe mínima, checkpoint com refação).

## 8f. Ajustes pós-merge do PR #14 (ícones do HUD, luz do escritório, velocidades)

- **Emojis não renderizam no Windows** (a fonte padrão do Godot não tem emoji e o fallback do sistema
  não funcionou: botões 🌎/🔊 ficaram vazios no build do usuário). Solução em duas partes: `UIKit`
  coloca a **Noto Emoji** (monocromática, OFL, `assets/fonts/NotoEmoji.ttf`) como fallback da fonte
  padrão, da negrito e da pixel (`theme.default_font`), então os ~190 emojis da interface renderizam
  em qualquer plataforma; e os botões do HUD/tela inicial (mapa, pausa/play, som) viraram ícones
  pixel art 20×20 (`tools/gen_icons.py`, `HUD_BUTTON_ICONS`, `Button.icon`).
- **Luz do escritório**: `tint_layer` passou a multiplicar as cores (`BLEND_MODE_MUL`); `LIGHT_KEYS`
  guarda multiplicadores (branco = dia). Tarde alaranjada (16h–18h30), noite quase apagada (~0,3) com
  halos das luminárias em 9 anéis aditivos; o vidro das janelas fica fora da tinta. `settle_light()`
  pula o fade (usado no tour).
- **Velocidades**: `SECONDS_PER_DAY` 10,5 s e `SPEEDS` [1, 3, 7.5] — o 1x ficou 3× mais lento, o 2x é o
  antigo 1x (3,5 s) e o 3x (1,4 s) é um pouco mais lento que o antigo 3x (1,17 s).

## 8g. World Map com animação e movimento (pedido do usuário)

- Nova camada `WorldMapLife` entre a imagem e os cartões: 70+ veículos (carros na avenida e nas
  ruas, barcos), nuvens com sombra, avião com rastro, bandos de pássaros, espuma animada, anel
  pulsando na sede, bandeiras nas rivais, janelas acesas e farol girando à noite (mesma hora do
  escritório, mapa escurece via `modulate`), caminhão da mudança de sede com câmera acompanhando,
  rolagem suave ao abrir, pino flutuando e botão "Mudar a sede" respirando quando dá para mudar.
- `tools/gen_art.py` exporta `data/map_life.json` (rotas/pontos) e os sprites pequenos
  (`car`, `truck`, `boat`, `plane`, `bird`, `cloud_a/b`, `flag`).
- **Atenção:** o `world.png` do repositório vinha de uma versão anterior do gerador (cidade mais
  densa); ao reexportar, o mapa passou a ser o do código atual (mais aberto, ruas visíveis). Se o
  usuário preferir a versão densa, é ajustar as probabilidades em `world_map()` e reexportar.

## 8h. Lote de missões, calendário, notícias e balanceamento por serviço (12/09)

Pedido do usuário depois de jogar o build do PR #16. O que entrou:

- **Mapa**: `world_cover.png` (só prédios/árvores, exportado junto com `world.png`) desenhado por cima
  dos veículos — os carros passam **atrás** dos prédios; rival com sprite maior, anel vermelho pulsando,
  rótulo com fundo e "toque para ver".
- **Atributos por serviço** (`indicator_weights`, `team_fit`, `key_attrs`): os pesos dos quatro
  indicadores saem dos serviços do projeto (`ATTR_TO_INDICATOR`, mistura 55% com os pesos base) e a
  aptidão média da equipe soma até +15 / tira até −9 na nota. O diálogo de novo projeto mostra o que
  o trabalho pede e a aptidão de cada pessoa; a ficha mostra "rende mais em".
- **Missões** (`QuestSystem`, `data/quests.json`): 16 tipos com prazo, progresso por contador de
  stats, entrega com N★, dias de moral alta, caixa ou tamanho da equipe. Cumprir paga; perder o prazo
  custa 1 de reputação. Popup ao surgir, linha no feed e item no calendário.
- **Calendário** (`CalendarSystem` + `CalendarScreen`, botão 📅 ao lado do 🌎): grade de 12 meses,
  agenda unificada, banca de notícias, **foco do mês** (4 opções, uma por mês, efeitos em vendas /
  produtividade / estresse / custos) e **aniversário de contrato** com presente.
- **Notícias** (`NewsSystem`, `data/news.json`, `assets/art/news/`): 28 manchetes cômicas com marcas
  fictícias, em jornal ou rede social, com 9 ilustrações novas. Efeito só em algumas, sempre escrito.
- **Mídia paga** (`ClientSystem.CAMPAIGNS`): 3 campanhas que entregam leads em poucos dias, com custo
  por região; prospect novo toca `prospect.wav` e a aba Clientes pisca com o número.
- **Pets**: coelho, tartaruga, papagaio e capivara (sprites em `gen_art.py`, ações de RH encadeadas).

**Balanceamento:** o bot da simulação ficou mais sensato (reserva de caixa, só cresce se o aluguel novo
couber por 6 meses, escolhe o foco do mês, compra mídia paga quando falta prospect). A CI usa a seed
12345; entre seeds o bot continua variando muito (de R$ 850 mil a quase falir), como já acontecia.

### Dois bugs relatados e corrigidos no mesmo lote

1. **Interface "com zoom" e cortada ao trocar de aba**: o HUD passou a pedir 595 px de largura mínima
   (a tela tem 540) quando o botão do calendário entrou na linha de cima — o layout inteiro era
   empurrado. Os botões desceram para a linha de baixo (que tinha folga) e o HUD voltou a 355 px.
   O `ui_smoke_test` agora falha se qualquer tela ou o HUD pedir mais que a largura da tela.
2. **Tempo travado ao continuar um save**: o jogo salva no fechamento do mês, e se um evento estava
   em aberto o `pending_event` ia junto — ao carregar, nada reabria o popup e `is_running()` ficava
   falso para sempre (os botões 1x/2x/3x não resolviam). Agora `load_game()` reemite o evento (ou
   limpa se estiver sem opções) e explica um save que terminou em falência. Coberto por teste.

## 9. Checklist para retomar o projeto

1. Ler este documento, depois `README.md` (tabela "O que já existe") e `docs/ARQUITETURA.md`;
   consultar o GDD por seção quando uma mecânica for tocada.
2. `git fetch origin main` e reiniciar a branch `claude/growth-story-mobile-game-sfwg9e` a partir
   de `origin/main` se houver PR mesclado desde o último trabalho.
3. Rodar `--import`, `sim_test` e `ui_smoke_test` antes de qualquer mudança para ter a linha de
   base verde.
4. Para mudanças visuais, rodar o tour de screenshots e **olhar as imagens**.
5. Conteúdo novo entra em `data/*.json`; mecânica nova vira um sistema em `src/systems/` com
   `setup(game)`, registrado na lista do `GameManager._ready()`; estado novo entra em
   `GameState` (variável + `to_dict` + `from_dict` + `stats` padrão se for contador).
6. Atualizar README (tabela) e, quando houver fórmula, `ARQUITETURA.md`; adicionar teste no bloco
   correspondente do `sim_test` e, se houver UI, no `ui_smoke_test`/tour.
7. Commit em português com o rodapé de atribuição, push, PR draft com resumo/decisões/validação,
   screenshots para o usuário, acompanhar o CI até o merge.
