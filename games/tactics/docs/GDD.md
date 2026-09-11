# Tactics (nome provisório) — Game Design Document (GDD) v0.0

> Documento estratégico do jogo. Ainda não há decisões de design registradas:
> as seções abaixo seguem a estrutura do GDD do Growth-Story e devem ser
> preenchidas antes de implementar mecânicas.

## 1. Visão do produto

- **Conceito:** a definir.
- **Tagline:** a definir.
- **Referências:** a definir.
- **Plataforma-alvo:** a definir (o esqueleto usa o renderer *Mobile* do Godot, como o Growth-Story, e viewport 960×540 em paisagem; ambos podem ser trocados em `project.godot`).

## 2. Loop principal

A definir.

## 3. Sistemas

A definir. Cada sistema entra em `src/systems/` como `RefCounted` com `setup(game)`, sem depender da interface, para poder rodar nos testes headless.

## 4. Conteúdo

A definir. Dados em JSON dentro de `data/`.

## 5. Arte e som

A definir.

## 6. Roadmap

A definir.
