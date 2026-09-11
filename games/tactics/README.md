# Tactics (nome provisório)

Novo jogo em **Godot 4.3** (GDScript). Este diretório é um projeto Godot completo e
independente do Growth-Story: abra `games/tactics/project.godot` no editor, ou rode
`godot --path games/tactics` a partir da raiz do repositório.

O conteúdo ainda é só o esqueleto: cena principal com um botão "Novo jogo", autoloads
`EventBus` e `Game`, um teste headless e o GDD em branco (`docs/GDD.md`).

## Estrutura

```
project.godot        configuração do projeto (nome, cena principal, autoloads, tela)
src/core/            EventBus (sinais globais) e Game (estado + sistemas)
src/systems/         sistemas de jogo sem dependência de UI (vazio por enquanto)
src/models/          modelos de dados (vazio por enquanto)
src/ui/              cenas e scripts de interface (main.tscn é a cena inicial)
data/                conteúdo em JSON (vazio por enquanto)
tests/               testes headless (rodam no CI)
docs/GDD.md          documento de design, a preencher
```

## Como rodar

1. Instale o [Godot 4.3](https://godotengine.org/download) (versão *standard*).
2. Abra `project.godot` no editor e pressione **F5**.
3. Ou pela linha de comando, a partir desta pasta: `godot --path .`

### Testes

```bash
godot --headless --path . --import                    # gera o cache de classes
godot --headless --path . res://tests/smoke_test.tscn # abre a cena principal e inicia um jogo
```

O CI roda os mesmos comandos no workflow **Tactics — testes headless**
(`.github/workflows/tactics-tests.yml`, na raiz do repositório) sempre que algo
dentro de `games/tactics/` muda.

## Decisões provisórias (trocar quando o GDD definir)

- Viewport 960×540 em paisagem, esticado por `canvas_items`.
- Renderer *Mobile* e filtro de textura *nearest* (pixel art), como no Growth-Story.
- Sem preset de exportação ainda (`export_presets.cfg`): Android/Windows entram quando a plataforma for decidida.
