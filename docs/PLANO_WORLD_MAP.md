# Plano de expansão: World Map, concorrentes reais e vida da equipe

> Proposta de design para o próximo grande update, escrita a partir dos números que o jogo tem
> hoje (custos, tiers, eventos, mobília, moral) e da referência visual enviada (mapa com
> "Início" no Bairro Criativo e cinco marcos: Tier 1 Locais → Tier 5 Global). Nada aqui está
> implementado; os números são ponto de partida para a régua da simulação, não valores finais.
> Perguntas em aberto estão marcadas com **[decidir]**.

---

## 1. Visão geral

O mapa vira a espinha dorsal da progressão: **onde a agência está** define que clientes chegam,
que eventos acontecem, que mobília existe e que concorrentes disputam com você. Hoje isso tudo
depende só de reputação e tamanho da equipe.

```
Região 1  Bairro Criativo      → clientes Tier 1 (locais)          início do jogo
Região 2  Centro Regional      → clientes Tier 2 (regionais)       concorrente aparece
Região 3  Capital              → clientes Tier 3 (nacionais)       concorrente aparece
Região 4  Distrito das Marcas  → clientes Tier 4 (grandes marcas)  concorrente aparece
Região 5  Hub Global           → clientes Tier 5 (globais)         [decidir] concorrente global?
```

Cada região é um "escritório" com **1 a 3 níveis de expansão** (mais mesas), em vez dos 4
escritórios fixos de hoje. O jogador paga para **mudar de região** (caro) e, dentro da região,
paga para **expandir** (barato). Total: 4 mudanças + 11 expansões = 15 passos de crescimento,
contra 3 hoje.

---

## 2. Mudança de sede e expansões

### 2.1 Tabela proposta

| Região | Mudança (custo único) | Reputação p/ mudar | Aluguel base/mês | Níveis (lugares) | Expansões (custo cada) |
|---|---|---|---|---|---|
| 1 Bairro Criativo | — (início) | — | R$ 0 → 1.500 no nível 2 | 3 níveis: 4 → 6 → 8 | R$ 3.000 · R$ 6.000 |
| 2 Centro Regional | R$ 40.000 | 15 | R$ 4.000 | 2 níveis: 8 → 10 → 12 | R$ 12.000 · R$ 18.000 |
| 3 Capital | R$ 150.000 | 35 | R$ 10.000 | 3 níveis: 12 → 14 → 16 → 18 | R$ 30.000 · R$ 45.000 · R$ 60.000 |
| 4 Distrito das Marcas | R$ 450.000 | 55 | R$ 25.000 | 2 níveis: 18 → 20 → 22 | R$ 90.000 · R$ 120.000 |
| 5 Hub Global | R$ 1.200.000 | 75 | R$ 60.000 | 2 níveis: 22 → 25 → 28 | R$ 200.000 · R$ 260.000 |

Referência do que existe hoje: ampliações de R$ 8 mil / 45 mil / 150 mil com reputação 8 / 25 /
45 e aluguel 2.500 / 8.000 / 20.000. A mudança de região custa 3–8× a ampliação equivalente de
hoje; as expansões internas custam menos que uma ampliação de hoje porque entregam só +2 lugares
(e podem vir como "+2 mesas" ou "+2 cadeiras numa mesa maior", conforme o layout).

Ordem de grandeza contra a simulação atual (bot ganancioso): receita ano 1 ≈ R$ 100 mil, ano 2 ≈
R$ 370 mil, ano 3 ≈ R$ 460 mil. Com essa tabela a Capital chega no ano 2–3, o Distrito no ano
4–5 e o Hub Global no ano 7+. Um jogador real demora mais. A régua do `sim_test` precisa ganhar
uma linha "região por ano" e ser reajustada.

### 2.2 O que acontece na mudança

- Paga o custo, a região vira a atual, o escritório abre no **nível 1 da região nova** (que já
  tem mais lugares que o nível máximo da anterior, então ninguém fica sem mesa).
- Mobília comprada **vai junto**; o que não couber nos slots do layout novo fica guardado e volta
  a aparecer quando houver slot.
- Aluguel novo entra no custo fixo do mês seguinte.
- Semana de mudança: 7 dias com produtividade ×0,85 e balões de "📦" no escritório (dá vida e
  cria um custo real além do dinheiro). **[decidir]** manter ou dispensar.
- O escritório antigo **[decidir]**: (a) some, como hoje; ou (b) vira **filial** com um gerente
  e 2–3 pessoas, que continua atendendo clientes daquele tier com receita passiva — casa com o
  GDD §31 ("o jogador deixa de executar") e §32 (grupo de agências), mas é bem mais trabalho.
  Recomendação: (a) agora, (b) como expansão futura.
- Visual: cada região tem sua paleta de parede e o que se vê pela janela (bairro com casas →
  prédios → skyline → torres de vidro → cidade global à noite). A arte é gerada por código
  como hoje; são 5 fundos de janela e 5 tons de parede.

### 2.3 HUD

Ícone 🗺️ na linha de cima do HUD (ao lado da data) abre o mapa em tela cheia, cobrindo
escritório e abas, como a tela inicial faz. Fechar volta ao estado anterior.

---

## 3. O World Map

**[decidir] estilo:** a referência é isométrica e horizontal; o jogo é top-down 3/4 e vertical
(540×960). Duas opções:

1. **Mapa no traço do jogo** (recomendado): um "mapa ilustrado" top-down desenhado por código,
   rolável na vertical, com a estrada de progresso subindo do Bairro Criativo (embaixo) até o
   Hub Global (em cima, junto do mar/ilha como na referência). Coerente com o resto e barato.
2. **Mapa isométrico** só nessa tela: mais fiel à imagem, mas exige um segundo estilo de arte e
   mais trabalho. Não recomendo agora.

Elementos (a legenda da referência vale toda):

- **Seu escritório** (pino verde) na região atual.
- **Caminho de progresso** com um marco por região; regiões futuras com cadeado e o requisito
  ("R$ 150 mil · reputação 35").
- **Tier de clientes** de cada região no cartão do marco ("Tier 3 · Nacionais · marcas
  conhecidas, atuação nacional").
- **Concorrentes** desenhados como prédios com logo nas regiões 2, 3 e 4 (e talvez 5). Tocar
  abre o painel do concorrente (§6).
- **Conquistas especiais** (estrela): prêmios ganhos e marcos ("primeiro cliente tier 3")
  aparecem como estrelinhas no mapa.
- Tocar no marco da região atual abre a expansão interna; tocar numa região desbloqueável abre a
  confirmação da mudança.

---

## 4. Tiers de cliente por região

Hoje: `max_tier = min(por reputação 20/40/60/80, 1 + equipe/3)`. Proposto:

```
tier máximo = min(região atual, 1 + equipe/3)
```

- A reputação deixa de liberar tier diretamente e passa a ser o **requisito para mudar de
  região**. O jogador entende: "quero clientes maiores → preciso mudar de sede".
- Prospects continuam vindo do tier da região e do tier abaixo (como hoje: `tier_cap` e
  `tier_cap − 1`), então clientes locais não somem de vez na Capital.
- Os clientes escritos à mão já têm tier 1–5 (5 / 8 / 6 / 2 / 2 por tier). Tiers 4 e 5
  precisam de mais clientes (sugestão: +4 em cada) para a Região 4 e 5 não caírem em geração
  procedural genérica.
- Eventos da agência (palestra, congresso…) e prêmios podem exigir região mínima (§5).

---

## 5. Eventos e mobília por região

### 5.1 Eventos aleatórios (`data/events.json` ganha `min_region`)

| Região mínima | Eventos existentes | Eventos novos sugeridos |
|---|---|---|
| 1 | logo_maior, so_mais_uma_coisinha, reuniao_desnecessaria, ferramenta_caiu, estagiario_genial, cliente_ameaca, viralizou, nova_plataforma, workshop_gratis, burnout_alerta, mercenario_aumento, conflito_interno, indicacao | "Vizinho pede um logo de graça", "Feira de rua do bairro" |
| 2 | parceria, universidade, concorrente_cresce, aluguel_sobe, nova_ia, crise_reputacao, premio | "Prefeitura abre edital", "Rádio local quer entrevista" |
| 3 | cliente_gigante, boom_ia_generativa, aquisicao | "Greve de transporte (produtividade)", "Evento do setor na cidade" |
| 4 | cliente_internacional, premio_internacional, investidor_de_peso | "Headhunter assedia a equipe", "Fusão de dois clientes" |
| 5 | — | "Fuso horário: cliente quer reunião às 3h", "Câmbio mexe no contrato global" |

Regra: `min_region` convive com as condições de hoje (`min_reputation` etc.). Os eventos de
concorrência (`proposta_concorrente`, `concorrente_cresce`) passam a ser disparados pelos
concorrentes reais (§6) e saem do sorteio aleatório.

Eventos da agência: palestra e meetup em qualquer região; feira de carreiras e workshop a partir
da 2; podcast e congresso a partir da 3; palco principal a partir da 4; novo "Feira
internacional" só na 5.

### 5.2 Mobília (`requires_office` vira `requires_region` + `requires_level`)

| Região | Mobília existente | Novas sugeridas |
|---|---|---|
| 1 | plantas, quadro de metas | quadro de avisos |
| 2 | cadeiras ergonômicas, café premium, monitores | recepção com sofá |
| 3 | biblioteca, ping-pong | sala de reunião envidraçada, estúdio de gravação (podcast) |
| 4 | sala de descompressão | academia, cozinha completa |
| 5 | — | terraço, "war room" de dados |

Algumas travadas também por nível dentro da região (ex.: academia só no nível 2 do Distrito),
para as expansões internas terem recompensa além das mesas.

---

## 6. Concorrentes reais

Hoje os concorrentes são só nomes sorteados (`data/competitors.json`) que fecham prospects
esquecidos, mais dois eventos aleatórios. Proposta: agências com **identidade, região, força e
carteira**.

### 6.1 Dados

`data/competitors.json` passa a listar agências:

```
{ id, name, region (2|3|4|5), logo (cor + letra), specialty (serviço),
  strength 0..100 (reputação deles), aggression 0..1,
  clients: gerados no tier da região (3 visíveis), staff: 2 pessoas nomeadas com atributos }
```

Aparecem no mapa **quando o jogador chega à região** (fase 2, 3 e 4, como pedido; **[decidir]**
se a Região 5 tem uma rival global). Força evolui devagar com o tempo e cai quando você tira
clientes dela.

### 6.2 O que elas fazem (todo mês, por concorrente na sua região ou abaixo)

- **Proposta a um funcionário seu** (a mecânica existente, agora com nome e cara): chance sobe
  com a força da rival e cai com lealdade/moral da pessoa. Você responde como hoje (aumentar
  salário, contra-proposta, deixar ir).
- **Proposta a um cliente seu**: mira o cliente com pior relação (< 50) e tier igual ao dela.
  Popup: "Vértice Digital ofereceu 15% de desconto para a Pizza do Zé". Escolhas: igualar
  (renegocia o orçamento para baixo), reunião de retenção (custa um dia de uma pessoa, chance por
  Comunicação), ou deixar ir. Perder para rival dói mais que perder por resultado ruim (−1 rep).

### 6.3 O que você pode fazer (tocando na rival no mapa)

- Painel: nome, região, força, especialidade, 3 clientes (nome, tier, orçamento, "relação com a
  rival": sólida/morna/frágil) e 2 pessoas da equipe (cargo, atributos principais, salário).
- **Proposta a um cliente dela — 1 por mês** (global, não por rival): usa a fórmula de proposta
  atual com bônus por relação frágil e penalidade pela força da rival. Se aceitar: cliente entra
  como ativo com relação 40 e **você perde reputação** (−2; "o mercado comenta a caça"). A rival
  fica agressiva por 3 meses (dobra as tentativas contra você). Se recusar: cooldown do mês gasto.
- **Contratar uma pessoa dela**: bônus de assinatura de 2 salários + salário 10% acima; chance
  pela lealdade dela à rival. Se aceitar: entra na equipe e **você perde reputação** (−2, como
  na proposta ao cliente). Também respeita o limite de 1 investida por mês? **[decidir]**
  (recomendo 1 proposta a cliente + 1 contratação por mês, separadas).
- Prêmio "Agência do Ano" passa a comparar você com as rivais reais (força × resultados), em
  vez da régua fixa de hoje.

### 6.4 Reputação como freio

Reputação é o que libera mudar de região (§4), então "roubar" tem custo real: cada investida
bem-sucedida atrasa a próxima mudança. É o equilíbrio entre crescer rápido por conquista e
crescer limpo por resultado.

---

## 7. Moral: por que está sempre alta e como rebalancear

### 7.1 Diagnóstico (código atual)

- Todo dia a moral **sobe** rumo a 65 (1% da distância) **mais** a moral diária da mobília e dos
  pets (plantas 0,15 + ping-pong 0,20 + cachorro 0,10 + gato 0,10 = até **+0,55/dia**), e
  sinergia da equipe (+0,06/dia por ponto).
- Ganhos frequentes: entrega com 4–5 estrelas **+6** (o bot da simulação entrega 4–5 estrelas
  em 56% dos projetos), promoção +12, curso +5, RH (pizza, festa…), eventos, prêmios (+8/+10/+15).
- Perdas raras: entrega com 1–2 estrelas −8, burnout −25, alguns eventos. **Estresse não
  derruba a moral**; só derruba a produtividade e leva ao burnout.
- Teto 85 + mobília (até 110). Resultado: em jogo normal a moral encosta no teto e fica lá.

### 7.2 Proposta

1. **Ponto de equilíbrio 55** (não 65) e teto base **75** (mobília continua elevando).
2. **Pressões negativas diárias**, cada uma pequena e legível na ficha da pessoa:
   - Estresse acima de 60: −0,15/dia a cada 10 pontos acima (estresse 90 → −0,45/dia).
   - Sem aumento há 12+ meses: −0,10/dia ("salário defasado"); some com aumento/promoção.
   - Na reserva (sem projeto) há 15+ dias: −0,10/dia ("sem desafio").
   - Escritório lotado (equipe = capacidade): −0,10/dia para todos ("apertado").
   - Projeto atrasado: −0,20/dia para a equipe dele enquanto durar o atraso.
3. **Ganhos menores e mais raros**: entrega 5★ +5, 4★ +3, 3★ 0, 2★ −6, 1★ −12; mobília diária
   cortada pela metade (plantas 0,08, ping-pong 0,10, pets 0,05); promoção +10.
4. **Consequências visíveis**: moral < 40 tira −10% de produtividade (hoje já pesa 0,6 na
   fórmula) e abre pedidos de demissão mais cedo; moral > 80 dá "estado feliz" (§8).
5. **Régua**: o `sim_test` passa a imprimir a moral média por ano e falha se ficar acima de 75
   ou abaixo de 45 na média dos 3 anos. Meta: oscilar entre 50 e 70, com quedas em época de
   crunch e subidas depois de vitórias.

---

## 8. Estados visíveis dos funcionários no escritório

Hoje há barra de moral e balões de texto/emoji. Proposta: um **estado de humor** por pessoa,
desenhado no próprio personagem (camada nova gerada em `tools/gen_art.py`, 2 quadros de animação):

| Estado | Condição | Visual |
|---|---|---|
| 🔥 Burnout | `busy_reason == "Burnout"` | cabeça vermelha (pele modulada), "vapor" saindo, sentado curvado; ao entrar em burnout, uma animação de "explosão" de 1 s com estrelinhas |
| 💦 Exausto | estresse ≥ 75 | gotas de suor, olheiras, anda devagar |
| 🎵 Feliz | moral ≥ 80 | notas musicais subindo, pulinho a cada poucos segundos |
| 🌧️ Desanimado | moral ≤ 35 | nuvenzinha cinza sobre a cabeça, ombros caídos, anda devagar |
| ✨ Celebrando | 3 dias após promoção, prêmio ou 5 estrelas | brilhos ao redor, pula no lugar |
| 📦 Mudando | semana de mudança de sede | carrega uma caixa |
| 💼 Assediado | recebeu proposta de rival no mês | olha para a porta de vez em quando; ícone de envelope |
| 🚪 Saindo | pediu demissão / foi contratado pela rival | sai pela porta com caixa; log no feed |

Prioridade: burnout > saindo > exausto > celebrando > desanimado > feliz. O estado também aparece
na ficha (aba Equipe) como texto, para não depender só do desenho.

---

## 9. Outras possibilidades de expansão (além do pedido)

Da lista anterior ainda pendentes: **decisões durante o projeto** (2), **identidade da agência /
perks** (3), **recordes e nova partida+** (6), **fluxo de caixa com tensão** (8), **imprensa e
aquisições** (10). Novas, que nascem do mapa:

- **Filiais**: o escritório antigo vira filial com gerente (GDD §31–32). Receita passiva, risco de
  cair sem atenção, e é o caminho natural para "The Agency Group".
- **Market share por região** no mapa: fatia sua × rivais, mudando com cada cliente ganho/perdido.
  Dá um placar visual para a disputa.
- **Clientes com sede** em regiões: reunião presencial rende relação, mas custa viagem (dinheiro
  + pessoa fora um dia); só faz sentido com o mapa.
- **Aquisição de rival**: com força dela baixa e seu caixa alto, comprar a agência (clientes e
  equipe vêm junto). Fecha o arco da concorrência e realiza o endgame do GDD.
- **Talento raro no mapa**: de tempos em tempos um profissional lendário (GDD §8) aparece numa
  região; quem chegar primeiro (você ou rival) leva.
- **Crises regionais** (GDD §34): apagão, enchente, greve — afetam todo mundo da região, incluindo
  rivais, por alguns dias.

---

## 10. Ordem de implementação sugerida

| PR | Conteúdo | Depende de | Tamanho |
|---|---|---|---|
| A | Regiões e mapa: `data/regions.json`, mudança de sede, expansões internas, tier por região, HUD 🗺️, tela do mapa, fundos de janela por região, rebalance de custos e da régua | — | grande |
| B | Moral rebalanceada + estados visíveis (humores) + régua de moral | — (independente; pode ir antes) | médio |
| C | Concorrentes reais: dados, propostas nos dois sentidos, contratar da rival, painel no mapa, Agência do Ano com rivais | A | grande |
| D | Eventos e mobília por região (os `min_region`), conteúdo novo (clientes tier 4–5, eventos, mobília) | A | médio |

Recomendação: **B primeiro** (rápido, melhora o jogo já, e os humores serão usados pelos
concorrentes: "assediado", "saindo"), depois **A**, **C**, **D**.

---

## 11. Perguntas para fechar antes de codar

1. **Regiões**: são 5, começando no Bairro Criativo com clientes Tier 1, como na tabela do §2? A
   referência mostra "Início" e cinco marcos; li como 5 regiões (o Início é o seu escritório
   dentro da Região 1).
2. **Estilo do mapa**: no traço do jogo, vertical (recomendado) ou isométrico como a referência?
3. **Escritório antigo** ao mudar: some (simples) ou vira filial (grande, fica para depois)?
4. **Concorrente na Região 5**: sim ou só nas regiões 2–4?
5. **Reputação nas investidas**: −2 por cliente ou funcionário tirado de rival está bom? E o
   limite: 1 proposta a cliente + 1 contratação por mês, ou 1 investida no total?
6. **Semana de mudança** com produtividade reduzida: manter?
7. **Números de moral** do §7.2: começo por eles e ajusto pela simulação, ou você quer mexer
   antes?
