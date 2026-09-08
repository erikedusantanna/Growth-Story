#!/usr/bin/env python3
"""Gera os sprites placeholder em pixel art (PNG) sem dependências externas.

Uso: python3 tools/gen_sprites.py
Cada sprite é descrito como uma grade de caracteres; cada caractere mapeia para
uma cor RGBA. '.' é transparente. Os arquivos vão para assets/sprites/.
"""
import os
import struct
import zlib

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")

PALETTE = {
    ".": (0, 0, 0, 0),
    "k": (34, 32, 52, 255),      # contorno escuro
    "w": (255, 255, 255, 255),   # branco (recolorível)
    "s": (238, 195, 154, 255),   # pele
    "S": (198, 150, 110, 255),   # pele sombra
    "h": (89, 56, 34, 255),      # cabelo
    "p": (52, 63, 99, 255),      # calça
    "P": (38, 46, 74, 255),      # calça sombra
    "b": (139, 96, 61, 255),     # madeira
    "B": (104, 70, 44, 255),     # madeira sombra
    "g": (99, 105, 117, 255),    # cinza
    "G": (66, 70, 80, 255),      # cinza escuro
    "m": (60, 200, 220, 255),    # tela do monitor
    "M": (30, 120, 150, 255),    # tela sombra
    "f": (232, 222, 196, 255),   # piso claro
    "F": (214, 202, 172, 255),   # piso escuro
    "l": (207, 197, 168, 255),   # linha do piso
    "W": (176, 190, 214, 255),   # parede
    "V": (130, 145, 172, 255),   # parede sombra
    "r": (196, 72, 72, 255),     # vermelho
    "R": (140, 44, 44, 255),
    "e": (96, 168, 84, 255),     # verde planta
    "E": (60, 120, 56, 255),
    "y": (240, 200, 70, 255),    # amarelo
    "c": (120, 80, 50, 255),     # café
    "o": (240, 140, 60, 255),    # laranja (ícone)
    "n": (26, 32, 48, 255),      # azul-noite (ícone)
    "t": (72, 200, 140, 255),    # verde-crescimento (ícone)
}


def write_png(path, rows):
    height = len(rows)
    width = max(len(r) for r in rows)
    raw = bytearray()
    for r in rows:
        raw.append(0)  # filtro none
        for x in range(width):
            ch = r[x] if x < len(r) else "."
            raw.extend(PALETTE[ch])

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as fh:
        fh.write(png)
    print("ok", os.path.relpath(path), f"{width}x{height}")


def hstack(*sheets):
    return ["".join(parts) for parts in zip(*sheets)]


# --- Personagem (16x16), 2 quadros: parado e andando ---------------------------
BODY_A = [
    "................",
    ".....hhhhhh.....",
    "....hhhhhhhh....",
    "....hsssssss....",
    "....hsksskss....",
    "....hsssssss....",
    ".....ssSSss.....",
    "......ssss......",
    "....k......k....",
    "...ks......sk...",
    "...k........k...",
    "....pppppppp....",
    "....PppppppP....",
    "....PPP..PPP....",
    "....kkk..kkk....",
    "................",
]
BODY_B = [
    "................",
    ".....hhhhhh.....",
    "....hhhhhhhh....",
    "....hsssssss....",
    "....hsksskss....",
    "....hsssssss....",
    ".....ssSSss.....",
    "......ssss......",
    "....k......k....",
    "....s......s....",
    "....k......k....",
    "....pppppppp....",
    "...PppP..pppP...",
    "..PPP......PPP..",
    "..kkk......kkk..",
    "................",
]
SHIRT_A = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    ".....wwwwww.....",
    "....wwwwwwww....",
    "....wwwwwwww....",
    "................",
    "................",
    "................",
    "................",
    "................",
]
SHIRT_B = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    ".....wwwwww.....",
    ".....wwwwww.....",
    ".....wwwwww.....",
    "................",
    "................",
    "................",
    "................",
    "................",
]

# --- Mobília -------------------------------------------------------------------
FLOOR = [
    "ffffffffffffffff",
    "fFfffffffFffffff",
    "ffffffffffffffff",
    "ffffffFfffffffff",
    "ffffffffffffffff",
    "ffffffffffffffFf",
    "ffffffffffffffff",
    "fffFffffffffffff",
    "ffffffffffffffff",
    "ffffffffffFfffff",
    "ffffffffffffffff",
    "ffFfffffffffffff",
    "ffffffffffffffff",
    "ffffffffFfffffff",
    "ffffffffffffffff",
    "llllllllllllllll",
]
WALL = [
    "WWWWWWWWWWWWWWWW",
    "WWWWWWWWWWWWWWWW",
    "WWWWWWWWWWWWWWWW",
    "WWWWWWWWWWWWWWWW",
    "WWWWWWWWWWWWWWWW",
    "WWWWWWWWWWWWWWWW",
    "WWWWWWWWWWWWWWWW",
    "WWWWWWWWWWWWWWWW",
    "WWWWWWWWWWWWWWWW",
    "WWWWWWWWWWWWWWWW",
    "WWWWWWWWWWWWWWWW",
    "WWWWWWWWWWWWWWWW",
    "VVVVVVVVVVVVVVVV",
    "kkkkkkkkkkkkkkkk",
    "BBBBBBBBBBBBBBBB",
    "bbbbbbbbbbbbbbbb",
]
DESK = [
    "................................",
    "..........kkkkkkkkkkkk..........",
    "..........kmmmmmmmmmmk..........",
    "..........kmmmmmmmmmmk..........",
    "..........kmmmmMMMMMmk..........",
    "..........kmmmmmmmmmmk..........",
    "..........kkkkkkkkkkkk..........",
    "...............kk...............",
    ".kbbbbbbbbbbbbbbbbbbbbbbbbbbbbk.",
    ".kbbbbbbbbbbbbbbbbbbbbbbbbbbbbk.",
    ".kBBBBBBBBBBBBBBBBBBBBBBBBBBBBk.",
    ".kkkkkkkkkkkkkkkkkkkkkkkkkkkkkk.",
    "..kBk........................kBk",
    "..kBk........................kBk",
    "..kkk........................kkk",
    "................................",
]
COFFEE = [
    "................",
    "....kkkkkkkk....",
    "....kGGGGGGk....",
    "....kGrGGGGk....",
    "....kGGGGGGk....",
    "....kkkkkkkk....",
    "....kggggggk....",
    "....kg.ww.gk....",
    "....kg.wwcgk....",
    "....kg.cc.gk....",
    "....kggggggk....",
    "....kGGGGGGk....",
    "....kkkkkkkk....",
    "....kBBBBBBk....",
    "....kkkkkkkk....",
    "................",
]
SOFA = [
    "................................",
    "................................",
    "................................",
    "................................",
    ".kkkkkkkkkkkkkkkkkkkkkkkkkkkkkk.",
    ".krrrrrrrrrrrrrrrrrrrrrrrrrrrrk.",
    ".krrrrrrrrrrrrrrrrrrrrrrrrrrrrk.",
    ".kRRRRRRRRRRRRRRRRRRRRRRRRRRRRk.",
    "kkrrrrrrrrrrrrrkkrrrrrrrrrrrrrkk",
    "kRrrrrrrrrrrrrrkkrrrrrrrrrrrrrRk",
    "kRrrrrrrrrrrrrrkkrrrrrrrrrrrrrRk",
    "kRRRRRRRRRRRRRRkkRRRRRRRRRRRRRRk",
    "kkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk",
    ".kBk.........................kBk",
    ".kkk.........................kkk",
    "................................",
]
PLANT = [
    "................",
    ".......ee.......",
    "....ee.eEe.ee...",
    "...eEe.eEe.eEe..",
    "...eEeeeEeeeEe..",
    "....eEEEEEEEe...",
    ".....eeEEEee....",
    "......kEEEk.....",
    "......kkkkk.....",
    ".....kbbbbbk....",
    ".....kbbbbbk....",
    ".....kBBBBBk....",
    "......kBBBk.....",
    "......kkkkk.....",
    "................",
    "................",
]
DOOR = [
    "kkkkkkkkkkkkkkkk",
    "kbbbbbbbbbbbbbbk",
    "kbBBBBBBBBBBBBbk",
    "kbBbbbbbbbbbbBbk",
    "kbBbbbbbbbbbbBbk",
    "kbBbbbbbbbbbbBbk",
    "kbBbbbbbbbbbbBbk",
    "kbBBBBBBBBBBBBbk",
    "kbbbbbbbbbbbbbbk",
    "kbBBBBBBBBBBBBbk",
    "kbBbbbbbbbbbbBbk",
    "kbBbbbbbbbbyybBk",
    "kbBbbbbbbbbyybBk",
    "kbBbbbbbbbbbbBbk",
    "kbBbbbbbbbbbbBbk",
    "kbBbbbbbbbbbbBbk",
    "kbBbbbbbbbbbbBbk",
    "kbBBBBBBBBBBBBbk",
    "kbbbbbbbbbbbbbbk",
    "kbbbbbbbbbbbbbbk",
    "kkkkkkkkkkkkkkkk",
    "................",
    "................",
    "................",
]


STAR = [
    "....y....",
    "...yyy...",
    "...yyy...",
    "yyyyyyyyy",
    ".yyyyyyy.",
    "..yyyyy..",
    "..yyyyy..",
    ".yyy.yyy.",
    "yy.....yy",
]
STAR_EMPTY = [
    "....G....",
    "...G.G...",
    "...G.G...",
    "GGGG.GGGG",
    ".G.....G.",
    "..G...G..",
    "..G...G..",
    ".G.G.G.G.",
    "GG.....GG",
]
HEART = [
    ".rr...rr.",
    "rrrr.rrrr",
    "rrrrrrrrr",
    "rrrrrrrrr",
    ".rrrrrrr.",
    "..rrrrr..",
    "...rrr...",
    "....r....",
    ".........",
]
HEART_EMPTY = [
    ".GG...GG.",
    "G..G.G..G",
    "G...G...G",
    "G.......G",
    ".G.....G.",
    "..G...G..",
    "...G.G...",
    "....G....",
    ".........",
]


def icon():
    # 32x32 ícone: fundo azul-noite com barra de crescimento e seta laranja.
    size = 32
    rows = [["n"] * size for _ in range(size)]
    for y in range(size):
        for x in range(size):
            if x in (0, size - 1) or y in (0, size - 1):
                rows[y][x] = "k"
    bars = [(4, 20, 6), (11, 15, 6), (18, 10, 6), (25, 5, 5)]
    for x0, top, w in bars:
        for y in range(top, size - 3):
            for x in range(x0, x0 + w):
                rows[y][x] = "t" if y > top + 1 else "y"
    # seta laranja diagonal
    for i in range(0, 20):
        x = 5 + i
        y = 22 - i
        if 1 <= x < size - 1 and 1 <= y < size - 1:
            rows[y][x] = "o"
            if y - 1 >= 1:
                rows[y - 1][x] = "o"
    for i in range(6):
        rows[3 + i][25] = "o"
        rows[3][20 + i] = "o"
    return ["".join(r) for r in rows]


def scale_rows(rows, factor):
    """Amplia uma grade de caracteres por vizinho mais próximo (mantém o pixel art nítido)."""
    out = []
    for r in rows:
        line = "".join(ch * factor for ch in r)
        out.extend([line] * factor)
    return out


def pad_rows(rows, size, fill="n"):
    """Centraliza a grade em um quadrado de `size` preenchido com a cor `fill`."""
    h = len(rows)
    w = len(rows[0])
    top = (size - h) // 2
    left = (size - w) // 2
    out = [fill * size for _ in range(top)]
    for r in rows:
        out.append(fill * left + r + fill * (size - left - w))
    while len(out) < size:
        out.append(fill * size)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(os.path.join(os.path.dirname(__file__), "..", "assets", "icons"), exist_ok=True)
    write_png(os.path.join(OUT, "body.png"), hstack(BODY_A, BODY_B))
    write_png(os.path.join(OUT, "shirt.png"), hstack(SHIRT_A, SHIRT_B))
    write_png(os.path.join(OUT, "floor.png"), FLOOR)
    write_png(os.path.join(OUT, "wall.png"), WALL)
    write_png(os.path.join(OUT, "desk.png"), DESK)
    write_png(os.path.join(OUT, "coffee.png"), COFFEE)
    write_png(os.path.join(OUT, "sofa.png"), SOFA)
    write_png(os.path.join(OUT, "plant.png"), PLANT)
    write_png(os.path.join(OUT, "door.png"), DOOR)
    write_png(os.path.join(OUT, "star.png"), STAR)
    write_png(os.path.join(OUT, "star_empty.png"), STAR_EMPTY)
    write_png(os.path.join(OUT, "heart.png"), HEART)
    write_png(os.path.join(OUT, "heart_empty.png"), HEART_EMPTY)
    root = os.path.join(os.path.dirname(__file__), "..")
    base = icon()
    write_png(os.path.join(root, "icon.png"), base)
    # Ícones do launcher Android: 192x192 e adaptativo 432x432 (fundo liso + primeiro plano centralizado)
    write_png(os.path.join(root, "assets", "icons", "launcher_192.png"), scale_rows(base, 6))
    write_png(os.path.join(root, "assets", "icons", "adaptive_background_432.png"), ["n" * 432] * 432)
    write_png(os.path.join(root, "assets", "icons", "adaptive_foreground_432.png"), pad_rows(scale_rows(base, 9), 432, "n"))


if __name__ == "__main__":
    main()
