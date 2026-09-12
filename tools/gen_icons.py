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
    # botões do HUD (20x20: desenhados em 10x10 e ampliados 2x, para ficarem nítidos no botão)
    "map": [  # globo
        "...2222...", ".22333322.", ".23332332.", "2333222332", "2233333322",
        "2223333322", "2233322332", ".23333332.", ".22233322.", "...2222...",
    ],
    "sound_on": [  # alto-falante com ondas
        "....8.....", "...88..3..", "..888.3.3.", "8888..3.3.", "8888.3..3.",
        "8888.3..3.", "8888..3.3.", "..888.3.3.", "...88..3..", "....8.....",
    ],
    "sound_off": [  # alto-falante cortado
        "....8.....", "...88.....", "..888.6..6", "8888...66.", "8888...66.",
        "8888...66.", "8888...66.", "..888.6..6", "...88.....", "....8.....",
    ],
    "pause": [
        "..88..88..", "..88..88..", "..88..88..", "..88..88..", "..88..88..",
        "..88..88..", "..88..88..", "..88..88..", "..88..88..", "..88..88..",
    ],
    "play": [
        "..3.......", "..33......", "..333.....", "..3333....", "..33333...",
        "..33333...", "..3333....", "..333.....", "..33......", "..3.......",
    ],
    "agenda": [  # calendário com marcações (botão do HUD)
        ".1......1.", "1111111111", "1WWWWWWWW1", "1111111111", "1W1WW1WW11",
        "1WWWWWWWW1", "1W11WW1WW1", "1WWWWWWWW1", "1W1WW11WW1", "1111111111",
    ],
}


HUD_BUTTON_ICONS = ("map", "sound_on", "sound_off", "pause", "play", "agenda")


def scale2(c):
    return [[ch for ch in row for _ in (0, 1)] for row in c for _ in (0, 1)]


def main():
    for name, rows in ICONS.items():
        c = icon(rows)
        if name in HUD_BUTTON_ICONS:
            c = scale2(c)
        write_png(os.path.join(OUT, "icons", f"{name}.png"), c)


if __name__ == "__main__":
    main()
