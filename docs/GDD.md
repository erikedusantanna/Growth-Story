# Agency Story — Game Design Document (GDD) v0.1

> **Documento estratégico do jogo**
>
> Um tycoon/simulation mobile inspirado na filosofia de *Game Dev Story* e *Game Dev Story*-like management games, transportada para o universo de agências de marketing.
>
> **Tagline:** Comece pequeno. Conquiste clientes. Monte seu time. Escale sua agência.

---

## 1. Visão do produto

### Conceito

O jogador começa como um pequeno freelancer/agência de marketing, com poucos recursos, poucos clientes e uma equipe mínima.

Seu objetivo é transformar essa operação em uma grande agência — e, no endgame, em um grupo empresarial/holding de comunicação, marketing e tecnologia.

A experiência deve priorizar:

- decisões simples, mas com consequências;
- progressão constante;
- personagens com personalidade;
- clientes com necessidades diferentes;
- eventos aleatórios;
- humor;
- sensação de crescimento;
- histórias emergentes;
- ciclos curtos e viciantes.

### Fantasia central

A progressão do jogador é:

**Executor → Freelancer → Dono de agência → CEO → Grupo empresarial → Holding**

O jogo começa com o jogador fazendo parte da operação e termina com ele tomando decisões estratégicas de alto nível.

---

# 2. Referência principal: Game Dev Story

A inspiração não deve ser uma cópia de interface, nomes, arte ou sistemas específicos. A referência é a **filosofia de design**:

> **Decisão → execução → resultado → recompensa → progressão → desafio maior → repetição**

Em uma agência:

> **Conquistar cliente → montar equipe → executar projeto → entregar resultado → ganhar dinheiro/reputação → melhorar equipe → desbloquear serviços → conquistar clientes maiores**

### Características que queremos preservar

- escritório vivo;
- funcionários andando;
- contratação;
- treinamento;
- evolução dos personagens;
- projetos;
- avaliações;
- dinheiro;
- reputação;
- desbloqueios;
- eventos aleatórios;
- decisões de alto nível;
- humor;
- progressão por anos;
- sensação de "só mais uma coisa".

---

# 3. Core Loop

O loop principal:

```text
PROSPECTAR
   ↓
CONQUISTAR CLIENTE
   ↓
ENTENDER BRIEFING
   ↓
ESCOLHER ESTRATÉGIA
   ↓
MONTAR EQUIPE
   ↓
EXECUTAR PROJETO
   ↓
AVALIAR RESULTADO
   ↓
RECEBER PAGAMENTO
   ↓
GANHAR REPUTAÇÃO
   ↓
CONTRATAR / TREINAR / INVESTIR
   ↓
CONQUISTAR CLIENTES MAIORES
```

O loop deve ser compreensível em poucos minutos.

O jogador não deve precisar administrar dezenas de configurações operacionais. Ele toma decisões relevantes e observa a equipe executando.

---

# 4. A grande fantasia do jogo

O jogador deve sentir que está construindo uma empresa.

### Início

- 1 pessoa;
- escritório pequeno;
- poucos serviços;
- clientes pequenos;
- caixa apertado.

### Meio

- departamentos;
- especialistas;
- clientes recorrentes;
- contratos maiores;
- novos serviços;
- concorrência;
- crises.

### Final

- grandes marcas;
- escritórios internacionais;
- aquisição de empresas;
- múltiplas unidades;
- tecnologia própria;
- holding.

---

# 5. Escritório

O escritório é um dos elementos visuais centrais.

O jogador vê os funcionários trabalhando, conversando, descansando e se deslocando.

### Primeira versão

```text
┌──────────────────────────┐
│                          │
│       💻 VOCÊ            │
│                          │
│                🚪        │
└──────────────────────────┘
```

### Escritório desenvolvido

```text
┌─────────────────────────────────┐
│ 👨‍💻       👩‍🎨      🧑‍💻          │
│                                 │
│       🛋️        ☕              │
│                                 │
│ 👩‍💼       👨‍💻      👨‍💻        │
│                          🚪     │
└─────────────────────────────────┘
```

### Evolução

1. Quarto/escritório improvisado
2. Sala pequena
3. Escritório profissional
4. Escritório com departamentos
5. Andar inteiro
6. Prédio
7. Campus
8. Escritórios internacionais

### Objetivo

O escritório deve funcionar como:

- representação visual do crescimento;
- espaço onde os personagens ganham vida;
- recompensa visual;
- ponto de interação;
- elemento de personalização.

---

# 6. Funcionários

Os funcionários são o coração emocional do jogo.

Cada funcionário deve ser mais do que um número.

## Atributos principais

- Criatividade
- Estratégia
- Performance
- Comunicação
- Gestão
- Tecnologia

Cada atributo varia, por exemplo, de 1 a 100.

## Atributos secundários

- Motivação
- Experiência
- Potencial
- Salário
- Especialização
- Lealdade
- Estresse

## Personalidade

Exemplos:

### Criativo
Alta criatividade, baixa disciplina.

### Workaholic
Alta produtividade, maior risco de burnout.

### Vendedor
Excelente relacionamento e fechamento.

### Analítico
Excelente estratégia/performance.

### Visionário
Grande potencial, mas pouca experiência.

### Estrela
Muito bom, muito caro.

### Leal
Evolui lentamente, mas dificilmente deixa a empresa.

### Mercenário
Entrega muito, mas exige aumentos constantes.

---

# 7. Evolução dos funcionários

Um funcionário pode começar como:

> João — Estagiário  
> Criatividade: 42

Depois de anos:

> João — Designer  
> Criatividade: 68

Depois:

> João — Senior Designer  
> Criatividade: 81

E finalmente:

> João — Creative Director  
> Criatividade: 96

A progressão cria histórias.

## Sistema de carreira

Exemplo:

```text
ESTAGIÁRIO
   ↓
JÚNIOR
   ↓
PLENO
   ↓
SÊNIOR
   ↓
ESPECIALISTA
   ↓
GERENTE
   ↓
DIRETOR
   ↓
EXECUTIVO
```

Nem todo funcionário precisa seguir o mesmo caminho.

---

# 8. Funcionários lendários

Alguns funcionários podem se tornar personagens extremamente importantes.

Exemplo:

> João entrou na agência com 22 anos e criatividade 42.

Após oito anos:

> Criatividade: 97
> Estratégia: 89
> Gestão: 91

Ele pode se tornar:

# Creative Director

E posteriormente:

# Sócio

Isso cria apego emocional.

O jogador deve lembrar:

> "Esse cara estava comigo desde o começo."

---

# 9. Contratação

O jogador recebe candidatos periodicamente.

Exemplo:

### Candidato

**Lucas**

Cargo: Designer

Criatividade: 84  
Estratégia: 51  
Gestão: 23  
Tecnologia: 48

Salário: R$ 4.800

Potencial: ⭐⭐⭐⭐⭐

O jogador precisa decidir:

> Contratar ou não?

### Possíveis fontes

- Estagiários
- Freelancers
- Mercado
- Head hunters
- Universidades
- Concorrentes
- Funcionários indicados

---

# 10. Treinamento

O jogador pode investir dinheiro e tempo em treinamento.

Exemplos:

- Curso de Copywriting
- Bootcamp de Performance
- Workshop Criativo
- Formação em Estratégia
- Liderança
- IA
- Analytics

Cada treinamento aumenta atributos específicos.

---

# 11. Clientes

Clientes funcionam como personagens.

Cada cliente possui:

- segmento;
- tamanho;
- orçamento;
- expectativa;
- paciência;
- maturidade de marketing;
- potencial;
- relacionamento;
- dificuldade;
- reputação;
- objetivo.

## Exemplo

### 🍕 Pizza do Zé

Segmento: Alimentação  
Tamanho: Pequeno  
Orçamento: R$ 3.000/mês  
Expectativa: Alta  
Paciência: Baixa

Objetivo:

> "Quero vender mais."

Mas o problema real pode ser:

- baixa geração de leads;
- baixa conversão;
- produto ruim;
- atendimento ruim;
- falta de posicionamento.

---

# 12. Diagnóstico

Antes de executar determinados projetos, o jogador pode realizar diagnósticos.

Exemplos:

- Auditoria de Marketing
- Auditoria Comercial
- Pesquisa de Mercado
- Análise de Concorrência
- Diagnóstico de Funil
- Diagnóstico de Marca

O diagnóstico revela informações ocultas.

Exemplo:

> **Problema descoberto**
>
> A empresa gera muitos leads, mas possui baixa conversão comercial.

Isso muda a estratégia recomendada.

---

# 13. Projetos

Projetos são equivalentes ao "desenvolvimento de jogos" na referência.

Exemplo:

## NOVO PROJETO

Cliente: Burger House

Projeto: Campanha de lançamento

Orçamento: R$ 35.000

Prazo: 30 dias

Objetivo:

> Aumentar vendas em 20%.

O jogador escolhe:

### Estratégia

- Performance
- Branding
- Social
- Influencer
- Outbound
- CRM
- Conteúdo

### Equipe

- Copywriter
- Designer
- Tráfego
- Account
- Estrategista

Depois:

# START PROJECT

A equipe executa.

---

# 14. Execução

Durante a execução, o jogador acompanha indicadores.

Exemplo:

```text
ESTRATÉGIA
████████░░ 82%

CRIATIVIDADE
██████░░░░ 61%

EXECUÇÃO
█████████░ 91%

PERFORMANCE
███████░░░ 72%
```

Esses indicadores são influenciados por:

- atributos da equipe;
- experiência;
- combinação de especialistas;
- estratégia;
- briefing;
- dificuldade;
- tecnologia;
- eventos;
- motivação.

---

# 15. Resultado da campanha

Ao terminar:

# CAMPAIGN COMPLETE!

### Burger House

Resultado: ⭐⭐⭐⭐⭐

Criatividade: 92  
Estratégia: 87  
Execução: 94  
ROI: 4.2x

### Cliente

❤️❤️❤️❤️❤️

Recompensas:

**+ R$ 35.000**

**+18 Reputação**

**+1 Case de Sucesso**

---

# 16. Sistema de avaliação

Projetos podem receber avaliações de 1 a 5 estrelas.

### 5 estrelas

- cliente muito satisfeito;
- bônus de reputação;
- chance de indicação;
- possibilidade de upsell;
- case de sucesso.

### 3 estrelas

- entrega aceitável;
- resultado mediano.

### 1 estrela

- cliente insatisfeito;
- perda de reputação;
- risco de cancelamento;
- possibilidade de crise.

---

# 17. Reviews e imprensa

Depois de campanhas importantes, podem aparecer avaliações fictícias.

Exemplo:

> 📰 **Marketing Weekly**
>
> "Burger House encontra nova fórmula para crescimento."
>
> ⭐⭐⭐⭐⭐

Ou:

> 📰 **Agency Insider**
>
> "A agência prometeu muito e entregou pouco."
>
> ⭐⭐

Reviews afetam reputação e atração de clientes.

---

# 18. Combinações estratégicas

Uma das mecânicas mais importantes.

Cada tipo de cliente possui combinações que funcionam melhor.

## Exemplo

### Startup de IA

🤖 IA  
+  
📱 Social  
+  
🎥 Vídeo  
+  
🎯 Performance

= **PERFECT MATCH**

Bônus:

**+35% Campaign Score**

---

### Combinação ruim

IA  
+  
Outdoor  
+  
SEO

= **Poor Match**

Resultado reduzido.

Isso cria profundidade estratégica sem exigir complexidade operacional.

---

# 19. Tipos de cliente

Exemplos:

### 🍕 Alimentação

- restaurante;
- delivery;
- food service.

### 🏭 Indústria

- indústria;
- distribuição;
- B2B.

### 💻 Tecnologia

- SaaS;
- startups;
- apps;
- empresas de IA.

### 👗 Fashion

- moda;
- beleza;
- lifestyle.

### 🏦 Financeiro

- bancos;
- fintechs;
- seguros.

### 🏠 Imobiliário

- construtoras;
- imobiliárias;
- incorporadoras.

### 🚗 Automotivo

- concessionárias;
- montadoras;
- peças.

### 🏥 Saúde

- clínicas;
- hospitais;
- healthtechs.

---

# 20. Clientes com personalidade

### Money Maker

Só se importa com ROI.

### Creative

Quer campanhas premiadas.

### Difficult

Reclama de tudo.

### Loyal

Permanece por anos.

### Whale

Poucos clientes, contratos gigantes.

### Micromanager

Quer aprovar tudo.

### Visionary

Aceita ideias ousadas.

### Traditionalist

Resiste a novidades.

---

# 21. Contratos

Existem dois modelos principais.

## Projeto

Exemplo:

R$ 30.000

Entrega única.

## Retainer

Exemplo:

R$ 15.000/mês durante 24 meses.

O retainer cria receita recorrente e previsibilidade.

Indicadores:

- MRR;
- contratos ativos;
- churn;
- ticket médio;
- margem;
- LTV.

---

# 22. Serviços

A progressão de serviços é uma das árvores de desbloqueio.

## Início

- Social Media
- Design
- Tráfego Pago

## Intermediário

- Copywriting
- SEO
- Google Ads
- Branding
- Influencer Marketing
- Conteúdo

## Avançado

- CRM
- Automação
- BI
- CRO
- Desenvolvimento Web
- Estratégia

## Endgame

- IA
- MarTech
- Dados
- Tecnologia proprietária
- Consultoria Enterprise

---

# 23. Evolução histórica

O jogo pode avançar por décadas.

## 2010

- Facebook;
- blogs;
- e-mail marketing;
- sites;
- mídia tradicional.

## 2012–2015

- crescimento das redes sociais;
- mobile;
- content marketing;
- inbound.

## 2016–2019

- Stories;
- influencers;
- performance;
- automação.

## 2020

- pandemia;
- aceleração digital;
- e-commerce.

## 2021–2024

- TikTok;
- creators;
- comunidades;
- creator economy.

## 2025+

- IA generativa;
- agentes;
- automação avançada;
- produção sintética;
- personalização em escala.

O objetivo é permitir um mundo que continue evoluindo.

---

# 24. Eventos aleatórios

Eventos são fundamentais para criar histórias emergentes.

Exemplos:

### 📱 Nova plataforma

> Uma nova rede social está explodindo.
>
> Investir agora pode colocar sua agência na liderança.

Escolhas:

- Investir;
- Ignorar;
- Esperar.

---

### 🤖 Nova IA

> Uma nova ferramenta revolucionou a criação de conteúdo.

Escolhas:

- Comprar licenças;
- Criar equipe interna;
- Ignorar.

---

### 💼 Funcionário recebe proposta

> Seu melhor designer recebeu uma oferta de uma concorrente.

Escolhas:

- Aumentar salário;
- Promover;
- Deixar sair.

---

### 😡 Cliente ameaça cancelar

> Carlos, da empresa X, está insatisfeito com os resultados.

Escolhas:

- Reunião;
- Desconto;
- Projeto extra;
- Ignorar.

---

### 🏆 Prêmio

> Sua agência foi indicada a um prêmio.

Recompensas possíveis:

- reputação;
- novos clientes;
- funcionários interessados;
- mídia.

---

### 💰 Aquisição

> Uma empresa ofereceu R$ 10 milhões pela sua agência.

Escolhas:

- Vender;
- Recusar;
- Fazer contraproposta.

---

# 25. Humor

O jogo precisa evitar parecer um ERP.

O humor é obrigatório.

Exemplo:

> 👨‍💻 João está trabalhando em uma campanha.
>
> ☕ João tomou seu quarto café.
>
> 💥 **JOÃO ENTROU EM MODO CRIATIVO**
>
> +35% Criatividade

Outro:

> 🚨 CLIENTE PEDIU ALTERAÇÃO
>
> "Pode deixar o logo maior?"
>
> 😱 Toda a equipe perdeu 8% de motivação.

Outro:

> 📩 "Só mais uma coisinha..."
>
> Projeto recebeu +3 tarefas.

---

# 26. Economia

A economia precisa ser simples no início e sofisticada no endgame.

## Receitas

- projetos;
- contratos recorrentes;
- bônus;
- upsells;
- licenciamento;
- aquisições;
- investimentos.

## Custos

- salários;
- aluguel;
- ferramentas;
- marketing;
- contratação;
- treinamento;
- infraestrutura;
- tecnologia.

## Indicadores

- caixa;
- receita;
- lucro;
- margem;
- MRR;
- churn;
- ticket médio;
- reputação.

---

# 27. Reputação

Reputação determina o tipo de oportunidade que aparece.

### 0–20

Freelancer desconhecido.

### 20–40

Agência local.

### 40–60

Agência reconhecida.

### 60–80

Agência nacional.

### 80–100

Agência de elite.

Quanto maior a reputação:

- melhores clientes;
- melhores funcionários;
- maiores contratos;
- mais imprensa;
- mais oportunidades.

---

# 28. Escada de clientes

A progressão de clientes deve acompanhar a reputação.

### Tier 1

- pizzaria;
- salão;
- loja local;
- pequeno comércio.

### Tier 2

- e-commerce;
- indústria média;
- rede de restaurantes;
- startup.

### Tier 3

- grandes empresas;
- grandes e-commerces;
- empresas nacionais.

### Tier 4

- bancos;
- montadoras;
- grandes varejistas;
- multinacionais.

### Tier 5

- megacorporações;
- empresas globais;
- marcas icônicas.

---

# 29. Crescimento da agência

Progressão:

```text
FREELANCER
   ↓
MICRO AGÊNCIA
   ↓
AGÊNCIA LOCAL
   ↓
AGÊNCIA NACIONAL
   ↓
AGÊNCIA GLOBAL
   ↓
GRUPO DE AGÊNCIAS
   ↓
HOLDING
```

---

# 30. Departamentos

No começo:

> Todo mundo faz tudo.

Depois:

- Comercial
- Atendimento
- Estratégia
- Criação
- Performance
- Conteúdo
- Tecnologia
- Dados
- Financeiro
- RH

O jogador gradualmente deixa de administrar indivíduos e começa a administrar estruturas.

---

# 31. O jogador deixa de executar

Essa é uma das progressões mais importantes.

### Fase 1

O jogador decide detalhes.

### Fase 2

O jogador escolhe equipe e estratégia.

### Fase 3

Gerentes executam.

### Fase 4

Diretores gerenciam departamentos.

### Fase 5

O jogador administra o grupo.

Isso representa:

> Executor → Gestor → CEO → Holding

---

# 32. Endgame

O jogo não precisa simplesmente acabar ao atingir determinado patrimônio.

O jogador pode criar um conglomerado.

Exemplo:

### Agência principal

Marketing 360º

### Aquisições

🎨 Agência Criativa  
📊 Agência de Performance  
📱 Agência Social  
🎥 Produtora  
💻 Empresa de Tecnologia  
🤖 Empresa de IA

Resultado:

# THE AGENCY GROUP

O jogador passa a administrar múltiplas empresas.

---

# 33. Arquétipos de agência

O jogador pode desenvolver uma identidade.

## Creative Powerhouse

Especialista em criatividade.

## Performance Machine

Especialista em ROI.

## Strategic Consultancy

Especialista em estratégia.

## Social Media Giant

Domina redes sociais.

## AI Agency

Especialista em IA e automação.

## Advertising Conglomerate

Grupo diversificado.

## Global Agency

Presença internacional.

---

# 34. Sistema de crises

Conforme a agência cresce, surgem problemas maiores.

Exemplos:

- cliente importante cancela;
- funcionário-chave sai;
- crise de reputação;
- campanha fracassa;
- concorrente rouba cliente;
- problema financeiro;
- excesso de trabalho;
- conflito interno;
- problema jurídico;
- ferramenta crítica fica indisponível.

Crises devem ser administráveis, mas não totalmente previsíveis.

---

# 35. Sistema de oportunidades

Também existem eventos positivos.

- cliente gigante;
- funcionário excepcional;
- viralização;
- prêmio;
- aquisição;
- parceria;
- nova tecnologia;
- expansão internacional;
- indicação de grande cliente.

O jogo deve alternar:

> **Risco ↔ recompensa**

---

# 36. MVP

A primeira versão NÃO deve tentar implementar todo o conceito.

## MVP recomendado

### Conteúdo

- 1 escritório;
- 4 funcionários;
- 10 clientes;
- 5 serviços;
- 20 eventos;
- 1 ano de jogo;
- contratação;
- treinamento;
- projetos;
- reputação;
- dinheiro;
- save/load.

### Serviços

1. Social Media
2. Design
3. Tráfego Pago
4. Copywriting
5. Branding

### Clientes

10 clientes diferentes.

### Funcionários

20 candidatos possíveis.

### Projetos

Sistema procedural simples.

---

# 37. Primeiro ano do jogo

O primeiro ano deve funcionar como um tutorial natural.

## Mês 1

- jogador;
- primeiro cliente;
- primeiro projeto.

## Mês 2

- primeiro pagamento;
- contratação.

## Mês 3

- segundo cliente;
- primeiro treinamento.

## Mês 4

- primeiro evento.

## Mês 5–6

- cliente recorrente;
- novo serviço.

## Mês 7–9

- primeiro funcionário especialista;
- escritório melhor.

## Mês 10–12

- cliente maior;
- avaliação anual;
- desbloqueio.

No fim do primeiro ano, o jogador deve sentir:

> "Eu comecei sozinho e agora tenho uma pequena agência."

---

# 38. Progressão anual

A cada ano:

- novos clientes;
- novos funcionários;
- novos serviços;
- novos eventos;
- novas tecnologias;
- novos problemas;
- novos mercados.

A dificuldade aumenta naturalmente.

---

# 39. Interface

A interface deve ser simples e mobile-first.

### Tela principal

```text
┌─────────────────────────────┐
│ 💰 R$ 128.450     ⭐ 47     │
│                             │
│       ESCRITÓRIO            │
│                             │
│ 👨‍💻  👩‍🎨   🧑‍💻            │
│                             │
│      👩‍💼   ☕              │
│                             │
├─────────────────────────────┤
│ 👥 EQUIPE                   │
│ 🤝 CLIENTES                 │
│ 📣 PROJETOS                 │
│ 📊 EMPRESA                  │
│ 🔓 DESBLOQUEIOS             │
└─────────────────────────────┘
```

A interface deve priorizar:

- leitura rápida;
- poucos cliques;
- feedback visual;
- animações pequenas;
- números fáceis de entender.

---

# 40. Estética

Direção recomendada:

## 2D pixel art / stylized pixel art

Motivos:

- custo menor;
- produção com IA mais viável;
- identidade forte;
- combina com o gênero;
- baixa exigência técnica;
- fácil expansão de conteúdo.

A estética pode evoluir para uma aparência de:

> **pixel art sofisticada + UI moderna**

Não precisa parecer retrô demais.

---

# 41. Som

Música:

- leve;
- divertida;
- repetível;
- progressiva.

Sons:

- contratação;
- pagamento;
- projeto concluído;
- level up;
- evento;
- cliente feliz;
- crise;
- promoção.

Pequenos sons devem reforçar o feedback.

---

# 42. Monetização

Como estratégia inicial, o jogo pode ter um preço muito baixo ou modelo free-to-play.

## Opção A — Premium barato

Preço:

**R$ 4,99–9,90**

Vantagens:

- experiência mais limpa;
- mais simples de implementar;
- sem anúncios;
- produto fácil de comunicar.

## Opção B — Gratuito

Monetização:

- anúncios opcionais;
- remoção de anúncios;
- cosméticos;
- expansões;
- conteúdo premium.

## Recomendação inicial

Para um primeiro projeto independente:

**Premium barato** é conceitualmente mais alinhado ao tipo de experiência.

Evitar pay-to-win.

---

# 43. Potencial de conteúdo futuro

Depois do MVP:

### Expansões

- Agência internacional;
- Influencer Agency;
- PR Agency;
- Product Studio;
- AI Agency;
- Consultoria;
- Eventos especiais;
- Novos períodos históricos;
- Novos países.

### Conteúdo

- centenas de clientes;
- funcionários raros;
- eventos;
- tecnologias;
- serviços;
- desafios.

O sistema procedural deve permitir expansão sem reconstruir o jogo.

---

# 44. Diferencial estratégico

O jogo não deve ser simplesmente:

> "Game Dev Story, mas com marketing."

A identidade própria vem de:

### 1. Diagnóstico

Você precisa descobrir o problema do cliente.

### 2. Estratégia

A combinação de serviços importa.

### 3. Resultado

O sucesso depende de métricas de negócio.

### 4. Clientes recorrentes

Relacionamento e MRR são importantes.

### 5. Agência como empresa

Você evolui de executor para CEO.

### 6. Evolução histórica

O mercado muda com o tempo.

### 7. Humor do mercado

Situações absurdas e reconhecíveis do mundo de marketing.

---

# 45. Princípio de design

Sempre perguntar:

> **Isso é divertido ou apenas realista?**

Se algo é muito realista, mas torna o jogo burocrático, simplificar.

Exemplo:

Não simular dezenas de configurações de Meta Ads.

Em vez disso:

> **Estratégia de Performance**
>
> Intensidade: 1–100

O jogo calcula a execução.

O jogador administra a agência, não uma conta de anúncios.

---

# 46. O que NÃO fazer no MVP

Evitar:

- 3D;
- multiplayer;
- PvP;
- mapa mundial complexo;
- sistema contábil profundo;
- CRM realista;
- integração com APIs reais;
- Meta Ads real;
- Google Ads real;
- dezenas de moedas;
- árvores gigantes de habilidades;
- centenas de telas.

O objetivo é validar:

> **O loop é divertido?**

---

# 47. Métrica principal de sucesso

A métrica mais importante no protótipo não é quantidade de sistemas.

É:

> **Quantos jogadores chegam ao segundo ano porque querem continuar?**

O teste ideal:

1. Jogador começa.
2. Conquista primeiro cliente.
3. Faz primeira campanha.
4. Recebe dinheiro.
5. Contrata alguém.
6. Desbloqueia serviço.
7. Conquista cliente maior.
8. Quer continuar.

Se isso funcionar, o jogo tem fundamento.

---

# 48. Roadmap de desenvolvimento

## Fase 1 — Prova de conceito

Objetivo:

> Validar o loop.

Implementar:

- escritório;
- funcionário;
- cliente;
- projeto;
- dinheiro;
- reputação.

---

## Fase 2 — MVP

Adicionar:

- contratação;
- treinamento;
- 10 clientes;
- 5 serviços;
- eventos;
- save;
- progressão anual.

---

## Fase 3 — Conteúdo

Adicionar:

- mais clientes;
- mais funcionários;
- mais serviços;
- mais eventos;
- novos escritórios;
- novas eras.

---

## Fase 4 — Profundidade

Adicionar:

- departamentos;
- gerentes;
- crises;
- concorrentes;
- imprensa;
- aquisições;
- expansão internacional.

---

## Fase 5 — Endgame

Adicionar:

- holding;
- múltiplas empresas;
- fusões;
- aquisições;
- tecnologia própria;
- mercado global.

---

# 49. Arquitetura conceitual

O jogo pode ser estruturado em sistemas independentes:

```text
GAME CORE
│
├── Time System
├── Employee System
├── Client System
├── Project System
├── Service System
├── Finance System
├── Reputation System
├── Event System
├── Research/Unlock System
├── Office System
├── Year/Calendar System
├── Save System
└── UI System
```

Isso facilita desenvolvimento incremental e uso de ferramentas de IA.

---

# 50. Desenvolvimento com IA

A IA pode ajudar principalmente em:

### Código

- sistemas;
- UI;
- lógica de projetos;
- geração procedural;
- save/load;
- economia;
- eventos.

### Conteúdo

- nomes de funcionários;
- nomes de empresas;
- briefs;
- eventos;
- descrições;
- reviews;
- diálogos.

### Arte

- sprites;
- objetos;
- ícones;
- ambientes;
- personagens;
- variações cosméticas.

### Áudio

- efeitos;
- música;
- sons de interface.

---

# 51. Estratégia de produção

Não tentar gerar tudo de uma vez.

Fluxo recomendado:

```text
IDEIA
 ↓
GDD
 ↓
PROTÓTIPO
 ↓
CORE LOOP
 ↓
TESTE
 ↓
BALANCEAMENTO
 ↓
ARTE
 ↓
CONTEÚDO
 ↓
POLIMENTO
 ↓
PUBLICAÇÃO
```

A prioridade deve ser:

**Gameplay > Conteúdo > Arte > Polimento**

---

# 52. Identidade do produto

A promessa ao jogador:

> **"Construa a agência dos seus sonhos."**

A sensação:

> "Só mais um cliente."

A progressão:

> "Só mais um funcionário."

O objetivo:

> "Só mais um ano."

Esse deve ser o equivalente emocional ao:

> "Só mais um jogo."

de Game Dev Story.

---

# 53. Visão final

No estágio máximo, o jogador olha para trás e vê:

```text
2010
Freelancer
R$ 5.000
1 pessoa
1 cliente

↓

2013
Pequena agência
R$ 300.000/ano
6 funcionários
15 clientes

↓

2018
Agência nacional
R$ 8M/ano
50 funcionários
Grandes marcas

↓

2025
Agência global
R$ 100M/ano
300 funcionários
Escritórios internacionais

↓

2035
THE AGENCY GROUP

8 empresas
2.000 funcionários
R$ 1B+ em receita
```

E o jogador pensa:

> **"Eu construí isso."**

Esse é o sentimento que o jogo deve entregar.

---

# 54. Norte do projeto

## O jogo deve ser:

- simples de aprender;
- difícil de largar;
- engraçado;
- visualmente charmoso;
- cheio de pequenas histórias;
- estratégico sem ser burocrático;
- fácil de expandir;
- acessível no celular;
- barato de produzir;
- adequado para desenvolvimento assistido por IA.

## O jogo não deve ser:

- um simulador empresarial complexo;
- um ERP gamificado;
- um gerenciador de anúncios;
- um jogo cheio de menus;
- um clone visual de Game Dev Story.

---

# 55. Frase-guia para todo o desenvolvimento

> **"Faça o jogador sentir que está construindo uma história, não preenchendo uma planilha."**

Essa deve ser a regra central de design de **Agency Story**.
