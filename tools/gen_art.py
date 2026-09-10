#!/usr/bin/env python3
"""Gera a arte pixel art do jogo (visão 3/4 de cima) sem dependências externas.

Uso: python3 tools/gen_art.py
Saída em assets/art/: tiles, mobília, personagens em camadas (96x32, 4 poses) e ícones.
Cada imagem é desenhada em uma grade de caracteres; o caractere mapeia para uma cor.
"""
import os
import struct
import zlib

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "assets", "art")

# --- Paleta ---------------------------------------------------------------------
P = {
    ".": (0, 0, 0, 0),
    "W": (255, 255, 255, 255),   # branco (camadas moduladas)
    "o": (42, 36, 50, 255),      # contorno
    # piso / parede
    "f": (216, 180, 122, 255), "F": (227, 195, 143, 255), "g": (185, 146, 90, 255), "G": (166, 124, 72, 255),
    "w": (223, 231, 238, 255), "v": (203, 214, 224, 255), "b": (183, 195, 207, 255), "B": (242, 246, 249, 255),
    # madeira / metal
    "m": (198, 141, 85, 255), "M": (219, 167, 108, 255), "d": (143, 96, 53, 255),
    "y": (107, 114, 128, 255), "Y": (154, 163, 175, 255), "z": (63, 70, 80, 255),
    # tela
    "s": (98, 200, 240, 255), "S": (185, 236, 255, 255), "k": (46, 52, 64, 255),
    # sofá / planta / vaso
    "r": (226, 87, 79, 255), "R": (181, 61, 54, 255), "q": (240, 128, 120, 255),
    "l": (88, 179, 104, 255), "L": (61, 138, 74, 255), "p": (181, 101, 74, 255),
    # água / vidro
    "a": (150, 214, 245, 255), "A": (210, 240, 255, 255),
    # personagem (camadas fixas)
    "e": (42, 36, 50, 255),      # olho
    "u": (178, 90, 90, 255),     # boca
    "n": (58, 74, 120, 255),     # calça
    "N": (44, 56, 92, 255),      # calça sombra
    "h": (42, 36, 50, 255),      # sapato
    # ícones
    "1": (255, 143, 61, 255),    # laranja
    "2": (59, 111, 216, 255),    # azul
    "3": (60, 179, 113, 255),    # verde
    "4": (142, 108, 224, 255),   # roxo
    "5": (232, 176, 52, 255),    # amarelo/ouro
    "6": (224, 93, 93, 255),     # vermelho
    "7": (80, 200, 200, 255),    # ciano
    "8": (120, 120, 130, 255),   # cinza médio
    "9": (255, 235, 180, 255),   # creme claro
}


def canvas(w, h, fill="."):
    return [[fill] * w for _ in range(h)]


def rect(c, x, y, w, h, ch):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            if 0 <= yy < len(c) and 0 <= xx < len(c[0]):
                c[yy][xx] = ch


def put(c, x, y, ch):
    if 0 <= y < len(c) and 0 <= x < len(c[0]):
        c[y][x] = ch


def hline(c, x0, x1, y, ch):
    for x in range(x0, x1 + 1):
        put(c, x, y, ch)


def vline(c, x, y0, y1, ch):
    for y in range(y0, y1 + 1):
        put(c, x, y, ch)


def write_png(path, c):
    h = len(c)
    w = len(c[0])
    raw = bytearray()
    for row in c:
        raw.append(0)
        for ch in row:
            raw.extend(P[ch])

    def chunk(tag, data):
        body = struct.pack(">I", len(data)) + tag + data
        return body + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(png)
    print("ok", os.path.relpath(path, ROOT), f"{w}x{h}")


def hstack(frames):
    return [sum((f[y] for f in frames), []) for y in range(len(frames[0]))]


# --- Tiles ----------------------------------------------------------------------

def floor_tile():
    c = canvas(16, 16, "f")
    for y in range(16):
        if y % 4 == 3:
            hline(c, 0, 15, y, "g")
    # emendas das tábuas alternadas
    for y, x in ((0, 5), (4, 12), (8, 2), (12, 9)):
        vline(c, x, y, y + 2, "G")
    for y in (1, 5, 9, 13):
        hline(c, 0, 15, y, "F")
    return c


def wall_tile():
    c = canvas(16, 32, "w")
    rect(c, 0, 0, 16, 2, "B")
    for y in range(6, 26, 6):
        hline(c, 0, 15, y, "v")
    rect(c, 0, 27, 16, 5, "b")
    hline(c, 0, 15, 27, "B")
    hline(c, 0, 15, 31, "o")
    return c


# --- Mobília (âncora: base inferior) --------------------------------------------

def desk():
    c = canvas(32, 28)
    # monitor
    rect(c, 10, 0, 12, 9, "k")
    rect(c, 11, 1, 10, 7, "s")
    rect(c, 12, 2, 4, 2, "S")
    rect(c, 14, 9, 4, 1, "z")
    rect(c, 12, 10, 8, 1, "z")
    # tampo
    rect(c, 1, 11, 30, 6, "M")
    hline(c, 1, 30, 11, "9")
    rect(c, 1, 17, 30, 3, "m")
    hline(c, 1, 30, 19, "d")
    # teclado e caneca
    rect(c, 5, 13, 8, 2, "Y")
    rect(c, 24, 12, 3, 3, "W")
    put(c, 27, 13, "W")
    # pés
    rect(c, 2, 20, 3, 8, "d")
    rect(c, 27, 20, 3, 8, "d")
    hline(c, 2, 29, 27, "o")
    # contorno leve
    vline(c, 0, 11, 19, "o")
    vline(c, 31, 11, 19, "o")
    return c


def chair():
    c = canvas(16, 18)
    rect(c, 3, 0, 10, 9, "z")
    rect(c, 4, 1, 8, 7, "y")
    rect(c, 2, 9, 12, 4, "z")
    rect(c, 7, 13, 2, 3, "z")
    rect(c, 3, 16, 10, 1, "z")
    put(c, 3, 17, "o")
    put(c, 12, 17, "o")
    return c


def sofa():
    c = canvas(40, 24)
    rect(c, 2, 0, 36, 10, "r")
    rect(c, 3, 1, 34, 3, "q")
    rect(c, 0, 8, 40, 12, "r")
    rect(c, 2, 10, 17, 7, "q")
    rect(c, 21, 10, 17, 7, "q")
    rect(c, 0, 17, 40, 3, "R")
    rect(c, 2, 20, 3, 3, "d")
    rect(c, 35, 20, 3, 3, "d")
    hline(c, 0, 39, 19, "o")
    vline(c, 0, 8, 19, "o")
    vline(c, 39, 8, 19, "o")
    return c


def plant():
    c = canvas(16, 24)
    for x, y in ((6, 1), (9, 0), (3, 4), (12, 3), (7, 5), (10, 6), (4, 8), (11, 9)):
        rect(c, x, y, 3, 3, "l")
        put(c, x + 1, y + 1, "L")
    rect(c, 6, 9, 4, 4, "L")
    rect(c, 4, 13, 8, 3, "p")
    rect(c, 5, 16, 6, 7, "p")
    hline(c, 5, 10, 22, "d")
    hline(c, 4, 11, 13, "o")
    return c


def coffee_machine():
    c = canvas(16, 26)
    rect(c, 2, 0, 12, 24, "z")
    rect(c, 3, 1, 10, 6, "y")
    rect(c, 4, 2, 8, 3, "k")
    put(c, 5, 3, "6")
    put(c, 7, 3, "3")
    rect(c, 4, 9, 8, 5, "k")
    rect(c, 6, 14, 4, 3, "W")
    rect(c, 6, 17, 4, 1, "d")
    rect(c, 3, 19, 10, 4, "y")
    hline(c, 2, 13, 24, "o")
    return c


def water_cooler():
    c = canvas(12, 26)
    rect(c, 2, 0, 8, 9, "A")
    rect(c, 3, 1, 6, 7, "a")
    rect(c, 1, 9, 10, 14, "W")
    rect(c, 2, 10, 8, 12, "B")
    rect(c, 3, 13, 2, 3, "a")
    rect(c, 7, 13, 2, 3, "6")
    rect(c, 1, 23, 10, 2, "y")
    hline(c, 1, 10, 25, "o")
    return c


def shelf():
    c = canvas(24, 32)
    rect(c, 0, 0, 24, 30, "m")
    for y in (2, 12, 22):
        rect(c, 2, y, 20, 8, "d")
        # livros coloridos
        for i, ch in enumerate(("6", "2", "3", "1", "4", "5", "2", "6")):
            if 3 + i * 2 < 21:
                rect(c, 3 + i * 2, y + 1 + (i % 3), 2, 7 - (i % 3), ch)
        hline(c, 2, 21, y + 8, "9")
    hline(c, 0, 23, 30, "d")
    hline(c, 0, 23, 31, "o")
    return c


def window():
    c = canvas(24, 20)
    rect(c, 0, 0, 24, 20, "B")
    rect(c, 1, 1, 22, 18, "a")
    rect(c, 2, 2, 20, 6, "A")
    rect(c, 11, 1, 2, 18, "B")
    rect(c, 1, 9, 22, 2, "B")
    # nuvem
    rect(c, 4, 4, 5, 2, "W")
    rect(c, 15, 12, 6, 2, "W")
    rect(c, 0, 19, 24, 1, "b")
    return c


def whiteboard():
    c = canvas(32, 20)
    rect(c, 0, 0, 32, 20, "Y")
    rect(c, 1, 1, 30, 17, "W")
    # rabiscos: gráfico subindo e marcações
    for i, y in enumerate((12, 11, 10, 8, 7, 5, 4, 3)):
        rect(c, 4 + i * 2, y, 2, 1, "2")
    rect(c, 20, 4, 8, 1, "6")
    rect(c, 20, 7, 6, 1, "6")
    rect(c, 20, 10, 9, 1, "3")
    rect(c, 3, 15, 12, 1, "8")
    rect(c, 0, 18, 32, 2, "Y")
    return c


def projector_screen():
    c = canvas(48, 30)
    rect(c, 0, 0, 48, 3, "z")
    rect(c, 22, 0, 4, 2, "k")
    rect(c, 1, 3, 46, 26, "W")
    rect(c, 0, 3, 1, 26, "Y")
    rect(c, 47, 3, 1, 26, "Y")
    # gráfico de barras
    for i, h in enumerate((5, 8, 11, 15)):
        rect(c, 5 + i * 4, 21 - h, 3, h, "2")
    # pizza
    rect(c, 28, 8, 12, 12, "2")
    rect(c, 34, 8, 6, 6, "6")
    rect(c, 34, 14, 6, 6, "5")
    # linhas de texto
    rect(c, 5, 24, 14, 1, "8")
    rect(c, 26, 24, 16, 1, "8")
    rect(c, 5, 26, 10, 1, "8")
    rect(c, 0, 29, 48, 1, "Y")
    return c


def pingpong():
    c = canvas(32, 22)
    rect(c, 1, 2, 30, 12, "l")
    rect(c, 1, 2, 30, 1, "W")
    rect(c, 15, 2, 2, 12, "W")
    rect(c, 1, 8, 30, 1, "W")
    rect(c, 0, 14, 32, 2, "L")
    rect(c, 2, 16, 3, 6, "z")
    rect(c, 27, 16, 3, 6, "z")
    hline(c, 0, 31, 15, "o")
    return c


def door():
    c = canvas(20, 30)
    rect(c, 0, 0, 20, 30, "d")
    rect(c, 2, 2, 16, 27, "m")
    rect(c, 4, 4, 12, 9, "M")
    rect(c, 4, 15, 12, 12, "M")
    rect(c, 14, 13, 2, 2, "5")
    rect(c, 0, 29, 20, 1, "o")
    return c



def partition():
    """Divisória de escritório (tile 8x16, repetido na vertical)."""
    c = canvas(8, 16, "v")
    vline(c, 0, 0, 15, "o")
    vline(c, 7, 0, 15, "o")
    vline(c, 1, 0, 15, "B")
    vline(c, 6, 0, 15, "b")
    hline(c, 1, 6, 7, "b")
    return c


def partition_top():
    """Topo da divisória (visto de cima, 8x6)."""
    c = canvas(8, 6, "Y")
    hline(c, 0, 7, 0, "o")
    hline(c, 0, 7, 5, "o")
    vline(c, 0, 0, 5, "o")
    vline(c, 7, 0, 5, "o")
    hline(c, 1, 6, 1, "B")
    return c


def hr_sign():
    c = canvas(20, 12)
    rect(c, 0, 0, 20, 12, "z")
    rect(c, 1, 1, 18, 10, "1")
    letters = {
        "R": ["WW.", "W.W", "WW.", "W.W", "W.W"],
        "H": ["W.W", "W.W", "WWW", "W.W", "W.W"],
    }
    for i, letter in enumerate("RH"):
        for dy, row in enumerate(letters[letter]):
            for dx, ch in enumerate(row):
                if ch == "W":
                    put(c, 5 + i * 5 + dx, 3 + dy, "W")
    return c


def chair_ergo():
    c = canvas(16, 18)
    rect(c, 5, 0, 6, 2, "z")          # apoio de cabeça
    rect(c, 3, 2, 10, 8, "z")
    rect(c, 4, 3, 8, 6, "2")
    rect(c, 2, 10, 12, 4, "z")
    rect(c, 3, 11, 10, 2, "2")
    rect(c, 7, 14, 2, 2, "z")
    rect(c, 2, 16, 12, 1, "z")
    for x in (2, 7, 13):
        put(c, x, 17, "o")
    return c


def desk_wide():
    c = desk()
    # monitor ultrawide no lugar do monitor comum
    rect(c, 3, 0, 26, 11, ".")
    rect(c, 4, 0, 24, 9, "k")
    rect(c, 5, 1, 22, 7, "s")
    rect(c, 6, 2, 6, 2, "S")
    rect(c, 14, 3, 8, 1, "S")
    rect(c, 14, 9, 4, 1, "z")
    rect(c, 12, 10, 8, 1, "z")
    return c


def coffee_premium():
    c = canvas(18, 28)
    rect(c, 2, 2, 14, 24, "Y")
    rect(c, 3, 3, 12, 22, "W")
    rect(c, 4, 0, 10, 3, "z")          # moedor de grãos
    rect(c, 4, 4, 10, 5, "k")
    put(c, 5, 5, "3")
    rect(c, 7, 5, 5, 1, "s")
    rect(c, 3, 10, 12, 2, "6")         # faixa vermelha
    rect(c, 5, 13, 8, 5, "k")
    rect(c, 7, 18, 4, 3, "W")
    put(c, 11, 19, "W")
    rect(c, 7, 21, 4, 1, "d")
    rect(c, 3, 23, 12, 3, "y")
    hline(c, 2, 15, 26, "o")
    vline(c, 2, 2, 26, "o")
    vline(c, 15, 2, 26, "o")
    return c


def goals_board():
    c = canvas(24, 20)
    rect(c, 0, 0, 24, 20, "m")
    rect(c, 1, 1, 22, 18, "9")
    for i in range(3):
        y = 3 + i * 5
        rect(c, 3, y, 4, 4, "W")
        rect(c, 3, y, 4, 1, "8")
        if i < 2:
            put(c, 4, y + 2, "3")
            put(c, 5, y + 1, "3")
            put(c, 5, y + 2, "3")
        rect(c, 9, y + 1, 8 if i != 1 else 6, 2, "8")
    # alvo no canto
    rect(c, 18, 2, 4, 4, "6")
    rect(c, 19, 3, 2, 2, "W")
    hline(c, 0, 23, 19, "o")
    return c


def dog():
    frames = []
    for walk in (False, True):
        c = canvas(16, 14)
        rect(c, 3, 5, 9, 5, "M")            # corpo
        rect(c, 9, 2, 6, 5, "M")            # cabeça
        rect(c, 9, 1, 2, 3, "m")            # orelha
        rect(c, 14, 4, 2, 2, "m")           # focinho
        put(c, 12, 3, "o")                  # olho
        put(c, 15, 4, "o")                  # nariz
        rect(c, 4, 6, 3, 2, "W")            # mancha
        if walk:
            rect(c, 3, 10, 2, 3, "m")
            rect(c, 10, 10, 2, 3, "m")
            put(c, 2, 3, "m"); put(c, 2, 4, "m"); put(c, 1, 2, "m")   # rabo para cima
        else:
            rect(c, 4, 10, 2, 3, "m")
            rect(c, 9, 10, 2, 3, "m")
            put(c, 2, 4, "m"); put(c, 1, 3, "m"); put(c, 1, 4, "m")
        hline(c, 3, 11, 13, "o")
        frames.append(c)
    return hstack(frames)


def cat():
    frames = []
    for walk in (False, True):
        c = canvas(14, 12)
        rect(c, 2, 6, 8, 4, "Y")            # corpo
        rect(c, 8, 2, 5, 5, "Y")            # cabeça
        put(c, 8, 1, "Y"); put(c, 12, 1, "Y")   # orelhas
        put(c, 9, 4, "3"); put(c, 11, 4, "3")   # olhos
        put(c, 10, 5, "q")                  # nariz
        rect(c, 4, 7, 1, 2, "y"); rect(c, 6, 7, 1, 2, "y")   # listras
        if walk:
            rect(c, 2, 10, 2, 2, "y")
            rect(c, 8, 10, 2, 2, "y")
            put(c, 1, 5, "y"); put(c, 0, 4, "y"); put(c, 0, 3, "y")   # rabo alto
        else:
            rect(c, 3, 10, 2, 2, "y")
            rect(c, 7, 10, 2, 2, "y")
            put(c, 1, 6, "y"); put(c, 0, 5, "y"); put(c, 0, 4, "y")
        frames.append(c)
    return hstack(frames)

def meeting_table():
    """Mesa de reuniao 48x26 com cadeiras ao fundo, papeis e notebook."""
    c = canvas(48, 26)
    # cadeiras atras da mesa
    for x in (9, 30):
        rect(c, x, 1, 9, 8, "z")
        rect(c, x + 1, 2, 7, 6, "y")
    # tampo
    rect(c, 1, 9, 46, 6, "M")
    hline(c, 1, 46, 9, "9")
    rect(c, 1, 15, 46, 3, "m")
    hline(c, 1, 46, 17, "d")
    # notebook, papeis e canecas em cima
    rect(c, 19, 7, 10, 3, "k")
    rect(c, 20, 8, 8, 1, "s")
    rect(c, 18, 10, 12, 2, "Y")
    rect(c, 5, 11, 7, 3, "W")
    hline(c, 6, 10, 12, "b")
    rect(c, 35, 11, 4, 3, "W")
    put(c, 39, 12, "W")
    rect(c, 41, 12, 3, 2, "B")
    # pes e sombra
    rect(c, 3, 18, 3, 8, "d")
    rect(c, 42, 18, 3, 8, "d")
    hline(c, 3, 44, 25, "o")
    vline(c, 0, 9, 17, "o")
    vline(c, 47, 9, 17, "o")
    return c


# --- Personagem 24x32, 4 poses: parado, andar A, andar B, sentado -----------------
# Camadas: skin (W), features (contorno/olhos/boca), hair_N (W), shirt (W), legs (fixa)

HEAD_X, HEAD_Y, HEAD_W, HEAD_H = 6, 2, 12, 12


def body_frame(kind):
    c = canvas(24, 32)
    # cabeça
    rect(c, HEAD_X, HEAD_Y, HEAD_W, HEAD_H, "S")
    put(c, HEAD_X, HEAD_Y, ".")
    put(c, HEAD_X + HEAD_W - 1, HEAD_Y, ".")
    put(c, HEAD_X, HEAD_Y + HEAD_H - 1, ".")
    put(c, HEAD_X + HEAD_W - 1, HEAD_Y + HEAD_H - 1, ".")
    # olhos e boca
    rect(c, 9, 8, 2, 2, "e")
    rect(c, 13, 8, 2, 2, "e")
    rect(c, 11, 12, 2, 1, "u")
    # pescoço
    rect(c, 10, 14, 4, 1, "S")
    # tronco (camisa)
    rect(c, 7, 15, 10, 9, "T")
    if kind == "sit":
        # braços à frente, apoiados na mesa
        rect(c, 5, 15, 2, 5, "T")
        rect(c, 17, 15, 2, 5, "T")
        rect(c, 6, 20, 3, 2, "S")
        rect(c, 15, 20, 3, 2, "S")
        rect(c, 8, 24, 8, 3, "n")   # coxas (o resto fica atrás da mesa)
        return c
    # braços
    arm_l = 15 if kind != "walk_b" else 16
    arm_r = 15 if kind != "walk_a" else 16
    rect(c, 5, arm_l, 2, 6, "T")
    rect(c, 17, arm_r, 2, 6, "T")
    rect(c, 5, arm_l + 6, 2, 2, "S")
    rect(c, 17, arm_r + 6, 2, 2, "S")
    # pernas
    if kind == "idle":
        rect(c, 8, 24, 3, 5, "n")
        rect(c, 13, 24, 3, 5, "n")
        rect(c, 11, 24, 2, 2, "N")
        rect(c, 7, 29, 4, 2, "h")
        rect(c, 13, 29, 4, 2, "h")
    elif kind == "walk_a":
        rect(c, 8, 24, 3, 6, "n")
        rect(c, 13, 24, 3, 4, "n")
        rect(c, 11, 24, 2, 2, "N")
        rect(c, 7, 30, 4, 2, "h")
        rect(c, 13, 28, 4, 2, "h")
    else:
        rect(c, 8, 24, 3, 4, "n")
        rect(c, 13, 24, 3, 6, "n")
        rect(c, 11, 24, 2, 2, "N")
        rect(c, 7, 28, 4, 2, "h")
        rect(c, 13, 30, 4, 2, "h")
    return c


HAIR_STYLES = {
    # curto: topo e laterais até os olhos
    0: lambda c: (rect(c, 6, 1, 12, 5, "H"), put(c, 6, 1, "."), put(c, 17, 1, "."),
                  rect(c, 6, 6, 2, 3, "H"), rect(c, 16, 6, 2, 3, "H")),
    # chanel: até o queixo
    1: lambda c: (rect(c, 5, 1, 14, 5, "H"), put(c, 5, 1, "."), put(c, 18, 1, "."),
                  rect(c, 5, 6, 2, 8, "H"), rect(c, 17, 6, 2, 8, "H"), rect(c, 7, 6, 3, 1, "H")),
    # longo: cai sobre os ombros
    2: lambda c: (rect(c, 5, 1, 14, 5, "H"), put(c, 5, 1, "."), put(c, 18, 1, "."),
                  rect(c, 5, 6, 2, 13, "H"), rect(c, 17, 6, 2, 13, "H"), rect(c, 13, 6, 4, 1, "H")),
    # coque: curto + bolinha no topo
    3: lambda c: (rect(c, 6, 2, 12, 4, "H"), put(c, 6, 2, "."), put(c, 17, 2, "."),
                  rect(c, 10, 0, 4, 3, "H"), rect(c, 6, 6, 2, 2, "H"), rect(c, 16, 6, 2, 2, "H")),
}


def hair_frame(style, kind):
    c = canvas(24, 32)
    HAIR_STYLES[style](c)
    return c


def outline(mask_frames):
    """Contorno de 1px ao redor da silhueta (união de todas as camadas)."""
    out = []
    for m in mask_frames:
        h, w = len(m), len(m[0])
        c = canvas(w, h)
        for y in range(h):
            for x in range(w):
                if m[y][x] != ".":
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < w and 0 <= yy < h and m[yy][xx] != ".":
                        c[y][x] = "o"
                        break
        out.append(c)
    return out


def split_layer(frame, chars, as_white=True, keep=None):
    c = canvas(24, 32)
    for y in range(32):
        for x in range(24):
            ch = frame[y][x]
            if ch in chars:
                c[y][x] = "W" if as_white else ch
            elif keep and ch in keep:
                c[y][x] = ch
    return c


def characters():
    kinds = ["idle", "walk_a", "walk_b", "sit"]
    bodies = [body_frame(k) for k in kinds]
    skin = [split_layer(b, "S") for b in bodies]
    shirt = [split_layer(b, "T") for b in bodies]
    legs = [split_layer(b, "nNh", as_white=False) for b in bodies]
    features = [split_layer(b, "eu", as_white=False) for b in bodies]
    write_png(os.path.join(OUT, "characters", "skin.png"), hstack(skin))
    write_png(os.path.join(OUT, "characters", "shirt.png"), hstack(shirt))
    write_png(os.path.join(OUT, "characters", "legs.png"), hstack(legs))
    for style in HAIR_STYLES:
        hair = [hair_frame(style, k) for k in kinds]
        write_png(os.path.join(OUT, "characters", f"hair_{style}.png"), hstack([split_layer(h, "H") for h in hair]))
        # contorno por estilo (silhueta = corpo + cabelo)
        merged = []
        for b, hf in zip(bodies, hair):
            m = [row[:] for row in b]
            for y in range(32):
                for x in range(24):
                    if hf[y][x] != ".":
                        m[y][x] = "H"
            merged.append(m)
        ol = outline(merged)
        # olhos e boca entram na mesma camada fixa
        for o, f in zip(ol, features):
            for y in range(32):
                for x in range(24):
                    if f[y][x] != ".":
                        o[y][x] = f[y][x]
        write_png(os.path.join(OUT, "characters", f"outline_{style}.png"), hstack(ol))


# --- Ícones 10x10 ---------------------------------------------------------------

def icon(rows):
    return [list(r) for r in rows]


ICONS = {
    # atributos
    "attr_creativity": [  # lâmpada
        "...4444...", "..444444..", ".44999944.", ".44999944.", ".44499444.",
        "..449944..", "...4444...", "...8888...", "...8888...", "....88....",
    ],
    "attr_strategy": [  # alvo
        "...2222...", ".22....22.", "2..2222..2", "2.2....2.2", "2.2.22.2.2",
        "2.2.22.2.2", "2.2....2.2", "2..2222..2", ".22....22.", "...2222...",
    ],
    "attr_performance": [  # gráfico subindo
        "........33", ".......33.", "......33..", "..3..33...", ".33.33....",
        "333.3.....", "3333......", "333.......", "3.........", "3333333333",
    ],
    "attr_communication": [  # balão de fala
        ".11111111.", "1111111111", "1199991191", "1111111111", "1199999911",
        "1111111111", ".11111111.", "..111.....", "..11......", "..1.......",
    ],
    "attr_management": [  # prancheta
        "...8888...", ".88888888.", ".8WWWWWW8.", ".8W3WWWW8.", ".8WWWWWW8.",
        ".8W3WWWW8.", ".8WWWWWW8.", ".8W3WWWW8.", ".8WWWWWW8.", ".88888888.",
    ],
    "attr_technology": [  # engrenagem
        "...77.77..", "..777777..", ".77777777.", "7777..7777", "777....777",
        "777....777", "7777..7777", ".77777777.", "..777777..", "...77.77..",
    ],
    # indicadores de projeto
    "ind_strategy": [
        "...2222...", ".22....22.", "2..2222..2", "2.2....2.2", "2.2.22.2.2",
        "2.2.22.2.2", "2.2....2.2", "2..2222..2", ".22....22.", "...2222...",
    ],
    "ind_creativity": [
        "...4444...", "..444444..", ".44999944.", ".44999944.", ".44499444.",
        "..449944..", "...4444...", "...8888...", "...8888...", "....88....",
    ],
    "ind_execution": [  # check
        "........11", ".......111", "......111.", ".....111..", "11..111...",
        "111.111...", ".11111....", "..111.....", "...1......", "..........",
    ],
    "ind_performance": [
        "........33", ".......33.", "......33..", "..3..33...", ".33.33....",
        "333.3.....", "3333......", "333.......", "3.........", "3333333333",
    ],
    # HUD
    "coin": [
        "...5555...", ".55555555.", ".55999955.", "5559555555", "5559999955",
        "5555559555", "5559999955", ".55555555.", ".55555555.", "...5555...",
    ],
    "rep": [  # estrela
        "....55....", "....55....", "...5555...", "5555555555", ".55555555.",
        "..555555..", "..555555..", ".555..555.", "55......55", "..........",
    ],
    "calendar": [
        ".8......8.", "8888888888", "8WWWWWWWW8", "8888888888", "8W8W8W8W88",
        "8WWWWWWWW8", "8W8W8W8W88", "8WWWWWWWW8", "8888888888", "..........",
    ],
}


def main():
    write_png(os.path.join(OUT, "tiles", "floor_wood.png"), floor_tile())
    write_png(os.path.join(OUT, "tiles", "wall.png"), wall_tile())
    for name, fn in (("desk", desk), ("chair", chair), ("sofa", sofa), ("plant", plant),
                     ("coffee", coffee_machine), ("cooler", water_cooler), ("shelf", shelf),
                     ("window", window), ("whiteboard", whiteboard), ("door", door),
                     ("projector", projector_screen), ("pingpong", pingpong),
                     ("partition", partition), ("partition_top", partition_top), ("hr_sign", hr_sign),
                     ("chair_ergo", chair_ergo), ("desk_wide", desk_wide), ("coffee_premium", coffee_premium),
                     ("goals_board", goals_board), ("dog", dog), ("cat", cat),
                     ("meeting_table", meeting_table)):
        write_png(os.path.join(OUT, "furniture", f"{name}.png"), fn())
    characters()
    for name, rows in ICONS.items():
        write_png(os.path.join(OUT, "icons", f"{name}.png"), icon(rows))


if __name__ == "__main__":
    main()
