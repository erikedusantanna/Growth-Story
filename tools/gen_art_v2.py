"""Arte v2 (tile de 32 px, estilo chibi com contorno escuro e 3 tons por material).

Modo prova de estilo: monta uma cena de exemplo e grava um PNG ampliado, sem tocar no jogo.
    python3 tools/gen_art_v2.py --proof saida.png
"""
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# --- Paleta (nomes, nao letras, para nao colidir) --------------------------------
def hx(s, a=255):
    return (int(s[1:3], 16), int(s[3:5], 16), int(s[5:7], 16), a)

PAL = {
    None: (0, 0, 0, 0),
    "o": hx("#1f2633"),           # contorno
    # piso / parede
    "floor": hx("#f1e9d8"), "floor_line": hx("#e0d5bf"), "floor_hi": hx("#f8f2e6"), "floor_worn": hx("#e6d9c1"),
    "wall": hx("#3d6a7a"), "wall_hi": hx("#6a98a8"), "wall_lo": hx("#2b4c58"), "wall_base": hx("#89adb9"),
    "metal": hx("#a9b6c1"), "metal_hi": hx("#dde5eb"), "metal_lo": hx("#5f6b76"),
    "glass": hx("#7fb0c0"), "glass_hi": hx("#b9dbe5"),
    "sky": hx("#a9d8f0"), "sky_hi": hx("#dff1fb"), "hill": hx("#7bbf6a"), "hill_lo": hx("#4f9a4a"),
    # madeira
    "wood": hx("#d5852d"), "wood_hi": hx("#f2a851"), "wood_lo": hx("#98561b"),
    # cadeira
    "red": hx("#d94a3d"), "red_hi": hx("#f27a6a"), "red_lo": hx("#932c25"),
    # monitor / teclado
    "frame": hx("#2b3340"), "screen": hx("#4b8fd8"), "screen_hi": hx("#9ccdf3"), "screen_lo": hx("#2f6bb0"),
    "key": hx("#c9d2da"), "key_lo": hx("#8f9aa5"), "mug": hx("#ffffff"), "mug_lo": hx("#c9cfd6"), "coffee": hx("#6b3e22"),
    # planta
    "leaf": hx("#4f9a4a"), "leaf_hi": hx("#86cc6c"), "leaf_lo": hx("#2f6b33"),
    "pot": hx("#c2673d"), "pot_hi": hx("#e2905f"), "pot_lo": hx("#7f3f25"),
    # personagem (partes fixas)
    "eye": hx("#1f2633"), "eye_hi": hx("#ffffff"), "eye_iris": hx("#4a5f8a"), "mouth": hx("#b8605c"), "blush": hx("#f2b3a2"),
    "badge": hx("#ffffff"), "badge_lo": hx("#c9d2da"), "lanyard": hx("#3b7dd8"), "shoe": hx("#2a2f3a"), "shoe_hi": hx("#4a5160"),
    "shadow": (31, 38, 51, 60),
}


def tone(rgba, f):
    r, g, b, a = rgba
    return (min(255, int(r * f)), min(255, int(g * f)), min(255, int(b * f)), a)


def color_set(name, base_hex):
    """Registra base, brilho e sombra de uma cor variavel (pele, cabelo, roupa)."""
    base = hx(base_hex)
    PAL[name] = base
    PAL[name + "_hi"] = tone(base, 1.18)
    PAL[name + "_lo"] = tone(base, 0.74)


# --- Canvas ----------------------------------------------------------------------
def canvas(w, h, fill=None):
    return [[fill] * w for _ in range(h)]


def put(c, x, y, ch):
    if 0 <= y < len(c) and 0 <= x < len(c[0]):
        c[y][x] = ch


def rect(c, x, y, w, h, ch):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            put(c, xx, yy, ch)


def hline(c, x0, x1, y, ch):
    for x in range(x0, x1 + 1):
        put(c, x, y, ch)


def vline(c, x, y0, y1, ch):
    for y in range(y0, y1 + 1):
        put(c, x, y, ch)


def outline(c, inside=lambda ch: ch is not None):
    """Contorna tudo que esta pintado com 1 px de 'o' (sem pintar por cima do desenho)."""
    h, w = len(c), len(c[0])
    src = [row[:] for row in c]
    for y in range(h):
        for x in range(w):
            if src[y][x] is not None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= ny < h and 0 <= nx < w and src[ny][nx] is not None and src[ny][nx] != "shadow":
                    c[y][x] = "o"
                    break


def mirror(c):
    return [row[::-1] for row in c]


def blit(dst, src, x, y):
    for yy, row in enumerate(src):
        for xx, ch in enumerate(row):
            if ch is not None:
                put(dst, x + xx, y + yy, ch)


def blit_bottom(dst, src, x, bottom):
    blit(dst, src, x, bottom - len(src))


def write_png(path, c, scale=1):
    h, w = len(c), len(c[0])
    raw = bytearray()
    for row in c:
        line = bytearray()
        for ch in row:
            line.extend(PAL[ch] * scale)
        for _ in range(scale):
            raw.append(0)
            raw.extend(line)

    def chunk(tag, data):
        body = struct.pack(">I", len(data)) + tag + data
        return body + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w * scale, h * scale, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(png)
    print("ok", path, f"{w}x{h} x{scale}")


# --- Tiles -----------------------------------------------------------------------
TILE = 32


def floor_tile(worn=False):
    c = canvas(TILE, TILE, "floor")
    hline(c, 0, TILE - 1, 0, "floor_line")
    vline(c, 0, 0, TILE - 1, "floor_line")
    hline(c, 1, TILE - 1, 1, "floor_hi")
    vline(c, 1, 1, TILE - 1, "floor_hi")
    if worn:
        for x, y, w, h in ((6, 18, 9, 5), (18, 8, 7, 4), (20, 22, 6, 3)):
            rect(c, x, y, w, h, "floor_worn")
    return c


def wall_tile():
    c = canvas(TILE, 64, "wall")
    hline(c, 0, TILE - 1, 0, "o")
    rect(c, 0, 1, TILE, 4, "wall_hi")
    hline(c, 0, TILE - 1, 5, "wall_lo")
    rect(c, 0, 54, TILE, 7, "wall_lo")
    hline(c, 0, TILE - 1, 54, "wall_base")
    rect(c, 0, 61, TILE, 3, "o")
    return c


def pillar():
    c = canvas(8, 64, "metal")
    vline(c, 0, 0, 63, "o")
    vline(c, 7, 0, 63, "o")
    vline(c, 1, 0, 63, "metal_hi")
    vline(c, 6, 0, 63, "metal_lo")
    vline(c, 5, 0, 63, "metal_lo")
    return c


def window():
    c = canvas(48, 34)
    rect(c, 0, 0, 48, 34, "metal")
    rect(c, 3, 3, 42, 28, "sky")
    rect(c, 3, 3, 42, 6, "sky_hi")
    rect(c, 3, 22, 42, 9, "hill")
    for x, y, w in ((3, 20, 10), (16, 19, 14), (33, 21, 12)):
        rect(c, x, y, w, 3, "hill")
    rect(c, 3, 27, 42, 4, "hill_lo")
    rect(c, 22, 3, 3, 28, "metal")
    rect(c, 3, 16, 42, 2, "metal")
    hline(c, 1, 46, 1, "metal_hi")
    vline(c, 1, 1, 32, "metal_hi")
    hline(c, 1, 46, 32, "metal_lo")
    vline(c, 46, 1, 32, "metal_lo")
    outline(c)
    return c


def partition_tile():
    c = canvas(12, 32)
    rect(c, 1, 0, 10, 32, "glass")
    rect(c, 1, 0, 2, 32, "metal_hi")
    rect(c, 3, 0, 1, 32, "metal")
    rect(c, 8, 0, 1, 32, "metal")
    rect(c, 9, 0, 2, 32, "metal_lo")
    for y in range(2, 30, 7):
        put(c, 5, y, "glass_hi")
        put(c, 6, y + 1, "glass_hi")
    outline(c)
    return c


def partition_cap():
    c = canvas(12, 8)
    rect(c, 1, 1, 10, 6, "metal")
    hline(c, 1, 10, 1, "metal_hi")
    hline(c, 1, 10, 6, "metal_lo")
    outline(c)
    return c


# --- Mobilia ---------------------------------------------------------------------
def desk():
    c = canvas(64, 56)
    # monitor (a direita, para a pessoa sentada aparecer a esquerda)
    rect(c, 37, 1, 24, 18, "frame")
    rect(c, 39, 3, 20, 13, "screen")
    rect(c, 39, 3, 20, 3, "screen_hi")
    rect(c, 41, 7, 8, 2, "screen_hi")
    rect(c, 41, 10, 14, 1, "screen_lo")
    rect(c, 41, 12, 10, 1, "screen_lo")
    rect(c, 46, 19, 6, 3, "metal_lo")
    rect(c, 42, 22, 14, 2, "metal_lo")
    # tampo
    rect(c, 1, 24, 62, 8, "wood_hi")
    rect(c, 1, 24, 62, 1, "wood")
    rect(c, 1, 32, 62, 4, "wood")
    hline(c, 1, 62, 35, "wood_lo")
    # teclado e caneca
    rect(c, 8, 27, 18, 4, "key")
    for x in range(9, 25, 3):
        put(c, x, 28, "key_lo")
        put(c, x + 1, 29, "key_lo")
    rect(c, 29, 25, 6, 6, "mug")
    rect(c, 30, 26, 4, 1, "coffee")
    put(c, 35, 27, "mug_lo")
    put(c, 35, 28, "mug_lo")
    vline(c, 34, 27, 30, "mug_lo")
    # gaveteiro (direita) e pe (esquerda)
    rect(c, 44, 36, 18, 18, "wood_lo")
    rect(c, 46, 38, 14, 6, "red")
    rect(c, 46, 38, 14, 1, "red_hi")
    rect(c, 46, 46, 14, 6, "red")
    rect(c, 46, 46, 14, 1, "red_hi")
    rect(c, 51, 41, 4, 1, "metal_hi")
    rect(c, 51, 49, 4, 1, "metal_hi")
    hline(c, 46, 59, 43, "red_lo")
    hline(c, 46, 59, 51, "red_lo")
    rect(c, 3, 36, 4, 18, "wood_lo")
    rect(c, 3, 36, 1, 18, "wood")
    # sombra no chao
    rect(c, 2, 54, 60, 2, "shadow")
    outline(c)
    return c


def chair():
    c = canvas(32, 40)
    # encosto
    rect(c, 7, 1, 18, 17, "red")
    rect(c, 8, 1, 16, 1, "red_hi")
    rect(c, 7, 2, 2, 15, "red_hi")
    rect(c, 22, 2, 3, 16, "red_lo")
    rect(c, 11, 4, 10, 2, "red_lo")
    # bracos e assento
    rect(c, 3, 18, 26, 3, "metal_lo")
    rect(c, 6, 21, 20, 6, "red")
    rect(c, 6, 21, 20, 1, "red_hi")
    rect(c, 6, 26, 20, 1, "red_lo")
    # haste e base
    rect(c, 14, 27, 4, 7, "metal_lo")
    rect(c, 15, 27, 1, 7, "metal")
    rect(c, 5, 34, 22, 3, "metal_lo")
    rect(c, 5, 34, 22, 1, "metal")
    for x in (5, 15, 25):
        rect(c, x, 37, 3, 2, "metal_lo")
    outline(c)
    return c


def plant():
    c = canvas(32, 48)
    # folhas: pontas para fora a partir do centro
    strokes = [
        ((15, 4), (16, 5), (17, 6), (17, 8), (16, 10)),
        ((7, 8), (8, 9), (10, 11), (12, 13), (14, 15)),
        ((25, 7), (24, 9), (22, 11), (20, 13), (18, 15)),
        ((4, 17), (6, 18), (8, 19), (11, 20), (14, 21)),
        ((28, 16), (26, 17), (23, 19), (20, 20), (17, 21)),
        ((10, 25), (12, 24), (14, 23)), ((22, 26), (20, 25), (18, 24)),
    ]
    for stroke in strokes:
        for i, (x, y) in enumerate(stroke):
            rect(c, x - 1, y - 1, 3, 3, "leaf")
            if i < 2:
                put(c, x, y, "leaf_hi")
    rect(c, 13, 14, 6, 14, "leaf_lo")
    rect(c, 14, 12, 3, 4, "leaf")
    for x, y in ((8, 10), (24, 9), (6, 18), (26, 17), (16, 6)):
        put(c, x, y, "leaf_hi")
    # vaso
    rect(c, 8, 28, 16, 4, "pot_hi")
    rect(c, 9, 32, 14, 14, "pot")
    rect(c, 9, 32, 3, 14, "pot_hi")
    rect(c, 20, 32, 3, 14, "pot_lo")
    hline(c, 9, 22, 45, "pot_lo")
    rect(c, 8, 46, 16, 2, "shadow")
    outline(c)
    return c


# --- Personagem chibi 32x48 --------------------------------------------------------
# Cabeca grande (20 px), corpo magro (10 px), 3 tons por material. Cores variaveis sao
# nomes registrados por color_set(): skin, hair, shirt, pants (+ "_hi" / "_lo").
# direction: front | back | left | right (direita = espelho da esquerda)
# pose: idle | walk_a | walk_b | sit

HAIR_STYLES = ("short", "long", "bun", "ponytail", "curly", "buzz", "swept")


def _eye(c, x0, y0):
    rect(c, x0, y0, 3, 5, "eye")
    put(c, x0 + 1, y0 + 2, "eye_iris")
    put(c, x0 + 1, y0 + 3, "eye_iris")
    put(c, x0, y0, "eye_hi")
    put(c, x0 + 1, y0, "eye_hi")
    put(c, x0, y0 + 1, "eye_hi")


def _glasses_front(c, y=10):
    for x0 in (9, 18):
        hline(c, x0, x0 + 4, y, "frame")
        hline(c, x0, x0 + 4, y + 6, "frame")
        vline(c, x0, y, y + 6, "frame")
        vline(c, x0 + 4, y, y + 6, "frame")
        put(c, x0 + 1, y + 1, "glass_hi")
    hline(c, 14, 17, y + 3, "frame")


def _hair_front(c, hair, style):
    lo, hi = hair + "_lo", hair + "_hi"
    if style == "buzz":
        rect(c, 6, 2, 20, 6, hair)
        rect(c, 7, 1, 18, 1, hair)
        rect(c, 5, 4, 1, 5, hair); rect(c, 26, 4, 1, 5, lo)
        rect(c, 8, 2, 7, 1, hi)
        rect(c, 22, 3, 4, 5, lo)
        return
    # base: calota + laterais
    rect(c, 5, 2, 22, 7, hair)
    rect(c, 6, 1, 20, 1, hair)
    rect(c, 5, 9, 2, 3, hair)
    rect(c, 25, 9, 2, 3, lo)
    rect(c, 8, 2, 7, 1, hi)
    rect(c, 7, 3, 3, 1, hi)
    rect(c, 22, 3, 5, 6, lo)
    if style == "swept":
        rect(c, 7, 9, 5, 1, hair)
        rect(c, 11, 9, 8, 2, hair)
        rect(c, 17, 9, 9, 3, hair)
        rect(c, 22, 9, 4, 5, lo)
        return
    # franja recortada
    for x, h in ((5, 2), (8, 3), (11, 1), (13, 3), (16, 2), (18, 3), (21, 1), (23, 3)):
        rect(c, x, 9, 3, h, hair if x < 21 else lo)
    if style == "long":
        rect(c, 4, 8, 3, 15, hair); rect(c, 4, 22, 3, 2, lo)
        rect(c, 25, 8, 3, 15, lo); rect(c, 25, 22, 3, 2, lo)
        rect(c, 4, 9, 1, 8, hi)
    elif style == "bun":
        rect(c, 11, 0, 10, 3, hair); rect(c, 12, -1, 8, 1, hair)
        rect(c, 12, 0, 4, 1, hi)
    elif style == "ponytail":
        rect(c, 25, 9, 3, 6, lo)
    elif style == "curly":
        rect(c, 4, 1, 24, 9, hair)
        for x, y in ((4, 0), (8, 0), (12, -1), (16, -1), (20, 0), (24, 0), (3, 4), (27, 4), (3, 8), (27, 8), (4, 10), (26, 10)):
            rect(c, x, y, 3, 3, hair)
        for x, y in ((6, 1), (10, 0), (14, 0), (5, 5)):
            put(c, x, y, hi)
        rect(c, 24, 2, 4, 8, lo)


def _face_front(c, skin, hair, glasses):
    lo, hi = skin + "_lo", skin + "_hi"
    rect(c, 6, 4, 20, 16, skin)
    rect(c, 7, 3, 18, 1, skin)
    rect(c, 8, 20, 16, 1, skin)
    rect(c, 7, 10, 3, 2, hi)                  # luz na testa/bochecha esquerda
    rect(c, 23, 6, 3, 14, lo)                 # sombra lado direito
    rect(c, 8, 19, 16, 2, lo)                 # queixo
    rect(c, 22, 18, 2, 1, lo)
    hline(c, 6, 25, 9, lo)                    # sombra da franja
    # sobrancelhas, olhos, nariz, boca, bochechas
    hline(c, 10, 12, 10, hair + "_lo")
    hline(c, 19, 21, 10, hair + "_lo")
    _eye(c, 10, 11)
    _eye(c, 19, 11)
    put(c, 16, 15, lo)
    put(c, 14, 16, "mouth"); put(c, 17, 16, "mouth")
    hline(c, 15, 16, 17, "mouth")
    rect(c, 8, 15, 2, 1, "blush"); rect(c, 22, 15, 2, 1, "blush")
    if glasses:
        _glasses_front(c)


def _legs(c, pants, pose, y0=34, left=(12, 3), right=(17, 3)):
    """Pernas finas com sapatos; a caminhada dobra uma perna de cada vez."""
    lo, hi = pants + "_lo", pants + "_hi"
    la = 2 if pose == "walk_a" else 0
    ra = 2 if pose == "walk_b" else 0
    for (x, w), lift, shade in ((left, la, False), (right, ra, True)):
        h = 9 - lift
        rect(c, x, y0, w, h, pants)
        if shade:
            rect(c, x + w - 1, y0, 1, h, lo)
        else:
            rect(c, x, y0, 1, 3, hi)
        rect(c, x - 1, y0 + h, w + 1, 3, "shoe")
        put(c, x - 1, y0 + h, "shoe_hi")
    hline(c, left[0], left[0] + left[1] - 1, y0, lo)
    hline(c, right[0], right[0] + right[1] - 1, y0, lo)


def _torso_front(c, skin, shirt, pants, pose, back=False):
    lo, hi = shirt + "_lo", shirt + "_hi"
    rect(c, 14, 21, 4, 1, skin + "_lo")       # pescoco na sombra do queixo
    rect(c, 11, 22, 10, 12, shirt)
    rect(c, 11, 23, 2, 9, hi)
    rect(c, 18, 23, 3, 11, lo)
    rect(c, 13, 22, 6, 1, lo)                 # gola / sombra do queixo
    if back:
        vline(c, 15, 24, 32, lo)
    else:
        put(c, 15, 22, skin + "_lo"); put(c, 16, 22, skin + "_lo")
        put(c, 14, 30, lo); put(c, 14, 31, lo)   # dobra
    # bracos e maos
    rect(c, 9, 23, 2, 9, shirt); put(c, 9, 23, hi)
    rect(c, 21, 23, 2, 9, lo)
    rect(c, 9, 32, 2, 2, skin)
    rect(c, 21, 32, 2, 2, skin + "_lo")
    if pose == "sit":
        rect(c, 11, 34, 10, 4, pants)
        rect(c, 11, 34, 10, 1, pants + "_hi")
        rect(c, 18, 34, 3, 4, pants + "_lo")
        rect(c, 11, 38, 4, 2, "shoe"); rect(c, 17, 38, 4, 2, "shoe")
        return
    _legs(c, pants, pose)


def _front(skin, hair, shirt, pants, style, glasses, pose):
    c = canvas(32, 48)
    _face_front(c, skin, hair, glasses)
    _hair_front(c, hair, style)
    _torso_front(c, skin, shirt, pants, pose)
    return c


def _back(skin, hair, shirt, pants, style, glasses, pose):
    c = canvas(32, 48)
    lo, hi = hair + "_lo", hair + "_hi"
    rect(c, 6, 4, 20, 16, skin)
    rect(c, 8, 20, 16, 1, skin)
    rect(c, 8, 17, 16, 4, skin + "_lo")       # nuca
    if style == "buzz":
        rect(c, 6, 2, 20, 15, hair); rect(c, 7, 1, 18, 1, hair)
        rect(c, 8, 2, 7, 1, hi); rect(c, 22, 3, 4, 14, lo)
    else:
        rect(c, 5, 2, 22, 15, hair)
        rect(c, 6, 1, 20, 1, hair)
        rect(c, 8, 2, 7, 1, hi); rect(c, 7, 3, 3, 1, hi)
        rect(c, 22, 3, 5, 14, lo)
        for x, h in ((5, 2), (9, 1), (13, 3), (17, 1), (21, 2), (25, 1)):
            rect(c, x, 17, 3, h, hair if x < 21 else lo)
    if style == "long":
        rect(c, 4, 8, 24, 18, hair); rect(c, 22, 8, 6, 18, lo)
        rect(c, 5, 26, 22, 2, lo); rect(c, 4, 9, 1, 10, hi)
    elif style == "bun":
        rect(c, 11, 0, 10, 4, hair); rect(c, 12, -1, 8, 1, hair); rect(c, 12, 0, 4, 1, hi)
        rect(c, 18, 1, 3, 3, lo)
    elif style == "ponytail":
        rect(c, 13, 6, 6, 3, lo)
        rect(c, 14, 15, 4, 14, hair); rect(c, 16, 15, 2, 14, lo)
        rect(c, 13, 28, 6, 2, lo); rect(c, 14, 15, 1, 6, hi)
    elif style == "curly":
        rect(c, 4, 1, 24, 17, hair)
        for x, y in ((4, 0), (8, 0), (12, -1), (16, -1), (20, 0), (24, 0), (3, 4), (27, 4), (3, 8), (27, 8), (3, 12), (27, 12), (5, 17), (9, 18), (13, 18), (17, 18), (21, 18), (25, 17)):
            rect(c, x, y, 3, 3, hair)
        rect(c, 24, 2, 4, 16, lo); put(c, 6, 1, hi); put(c, 10, 0, hi)
    _torso_front(c, skin, shirt, pants, pose, back=True)
    return c


def _side(skin, hair, shirt, pants, style, glasses, pose):
    """Olhando para a esquerda."""
    c = canvas(32, 48)
    slo, shi = skin + "_lo", skin + "_hi"
    hlo, hhi = hair + "_lo", hair + "_hi"
    # cabeca 16 de largura (x 8..23)
    rect(c, 8, 4, 16, 16, skin)
    rect(c, 9, 3, 14, 1, skin)
    rect(c, 10, 20, 12, 1, skin)
    rect(c, 9, 10, 2, 2, shi)
    rect(c, 20, 6, 4, 14, slo)
    rect(c, 10, 19, 12, 2, slo)
    hline(c, 8, 23, 9, slo)
    put(c, 7, 13, skin); put(c, 7, 14, skin)   # nariz de perfil
    hline(c, 10, 12, 10, hlo)
    _eye(c, 10, 11)
    put(c, 10, 17, "mouth"); put(c, 11, 17, "mouth")
    rect(c, 9, 15, 2, 1, "blush")
    if glasses:
        hline(c, 9, 13, 10, "frame"); hline(c, 9, 13, 16, "frame")
        vline(c, 9, 10, 16, "frame"); vline(c, 13, 10, 16, "frame")
        hline(c, 14, 21, 12, "frame"); put(c, 10, 11, "glass_hi")
    # cabelo: calota + nuca
    if style == "buzz":
        rect(c, 8, 2, 16, 6, hair); rect(c, 9, 1, 14, 1, hair)
        rect(c, 16, 8, 8, 8, hair); rect(c, 20, 8, 4, 8, hlo); rect(c, 10, 2, 6, 1, hhi)
    else:
        rect(c, 7, 2, 18, 7, hair); rect(c, 8, 1, 16, 1, hair)
        rect(c, 16, 9, 9, 8, hair); rect(c, 21, 5, 4, 12, hlo)
        rect(c, 10, 2, 6, 1, hhi); rect(c, 9, 3, 3, 1, hhi)
        if style == "swept":
            rect(c, 7, 9, 8, 2, hair); rect(c, 7, 11, 4, 2, hair)
        else:
            for x, h in ((7, 3), (10, 1), (12, 3), (14, 2)):
                rect(c, x, 9, 2, h, hair)
    if style == "long":
        rect(c, 17, 9, 9, 17, hair); rect(c, 22, 9, 4, 17, hlo); rect(c, 18, 26, 7, 2, hlo)
    elif style == "bun":
        rect(c, 17, 0, 8, 4, hair); rect(c, 18, -1, 6, 1, hair); rect(c, 18, 0, 3, 1, hhi)
    elif style == "ponytail":
        rect(c, 23, 8, 4, 14, hair); rect(c, 25, 8, 2, 14, hlo); rect(c, 22, 22, 5, 2, hlo)
    elif style == "curly":
        rect(c, 6, 1, 20, 9, hair); rect(c, 16, 9, 10, 9, hair)
        for x, y in ((6, 0), (10, -1), (14, -1), (18, 0), (22, 0), (5, 4), (25, 4), (25, 8), (25, 12), (24, 16), (20, 18)):
            rect(c, x, y, 3, 3, hair)
        rect(c, 23, 2, 4, 15, hlo); put(c, 8, 1, hhi); put(c, 12, 0, hhi)
    # tronco 8 de largura, braco da frente
    lo, hi = shirt + "_lo", shirt + "_hi"
    rect(c, 14, 21, 3, 1, slo)
    rect(c, 12, 22, 8, 12, shirt)
    rect(c, 12, 23, 1, 9, hi)
    rect(c, 18, 23, 2, 11, lo)
    rect(c, 13, 22, 6, 1, lo)
    rect(c, 13, 24, 3, 8, lo); rect(c, 13, 24, 1, 8, shirt)
    rect(c, 13, 32, 3, 2, skin)
    if pose == "sit":
        rect(c, 8, 34, 10, 4, pants); rect(c, 8, 34, 10, 1, pants + "_hi")
        rect(c, 7, 38, 5, 2, "shoe")
        return c
    # pernas de perfil: a de tras aparece um pouco atras
    plo, phi = pants + "_lo", pants + "_hi"
    la = 2 if pose == "walk_a" else 0
    ra = 2 if pose == "walk_b" else 0
    rect(c, 16, 34, 3, 9 - ra, plo)
    rect(c, 15, 34 + 9 - ra, 5, 3, "shoe")
    rect(c, 12, 34, 5, 9 - la, pants)
    rect(c, 12, 34, 1, 3, phi); hline(c, 12, 16, 34, plo)
    rect(c, 10, 34 + 9 - la, 7, 3, "shoe"); put(c, 10, 34 + 9 - la, "shoe_hi")
    return c


def clear(c, pts):
    for x, y in pts:
        put(c, x, y, None)


def round_head_front(c):
    """Tira os cantos duros da calota, do queixo e dos ombros (antes do contorno)."""
    top = min((y for y in range(0, 6) for x in range(4, 28) if c[y][x] is not None), default=1)
    xs = [x for x in range(3, 29) if c[top][x] is not None]
    if xs:
        l, r = min(xs), max(xs)
        clear(c, [(l, top), (l + 1, top), (r, top), (r - 1, top), (l, top + 1), (r, top + 1)])
    clear(c, [(6, 19), (6, 20), (7, 20), (25, 19), (25, 20), (24, 20), (11, 22), (20, 22)])


def round_head_side(c):
    top = min((y for y in range(0, 6) for x in range(4, 28) if c[y][x] is not None), default=1)
    xs = [x for x in range(3, 29) if c[top][x] is not None]
    if xs:
        l, r = min(xs), max(xs)
        clear(c, [(l, top), (l + 1, top), (r, top), (r - 1, top), (l, top + 1), (r, top + 1)])
    clear(c, [(8, 19), (8, 20), (9, 20), (23, 19), (23, 20), (22, 20), (12, 22), (19, 22)])


def character(direction, skin, hair, shirt, pants, style="short", glasses=False, pose="idle"):
    if direction == "front":
        c = _front(skin, hair, shirt, pants, style, glasses, pose)
        round_head_front(c)
    elif direction == "back":
        c = _back(skin, hair, shirt, pants, style, glasses, pose)
        round_head_front(c)
    else:
        c = _side(skin, hair, shirt, pants, style, glasses, pose)
        round_head_side(c)
        if direction == "right":
            c = mirror(c)
    outline(c)
    return c


# --- Prova de estilo ---------------------------------------------------------------
def _register_cast():
    cast = {
        "a": ("#f0c49c", "#5b3a22", "#f4f4f6", "#2f3542"),
        "b": ("#e5b592", "#3a2416", "#2d3340", "#1f2430"),
        "c": ("#8d5a3c", "#1e1a1a", "#3f4756", "#c9b48f"),
        "d": ("#f3cdb0", "#d8702a", "#f4f4f6", "#5c6b3a"),
        "e": ("#c68a5f", "#2b1d16", "#d94a3d", "#2f3542"),
        "f": ("#f5d6bd", "#e8c65a", "#4b8fd8", "#3a3f4a"),
        "g": ("#6b4028", "#111111", "#7dc466", "#2f3542"),
    }
    for k, (skin, hair, shirt, pants) in cast.items():
        color_set(f"skin_{k}", skin); color_set(f"hair_{k}", hair)
        color_set(f"shirt_{k}", shirt); color_set(f"pants_{k}", pants)


def _args(k):
    return (f"skin_{k}", f"hair_{k}", f"shirt_{k}", f"pants_{k}")


def style_proof(path, scale=3):
    _register_cast()
    W, H = 14, 8
    scene = canvas(W * TILE, H * TILE)
    wall, pil, fl, flw = wall_tile(), pillar(), floor_tile(), floor_tile(True)
    for x in range(W):
        blit(scene, wall, x * TILE, 0)
        for y in range(2, H):
            blit(scene, flw if (x * 7 + y * 3) % 11 == 0 else fl, x * TILE, y * TILE)
    for x in (0, W * TILE - 8):
        blit(scene, pil, x, 0)
    win = window()
    blit(scene, win, 1 * TILE + 8, 12)
    blit(scene, win, 8 * TILE + 8, 12)
    for y in range(2 * TILE + 4, 6 * TILE + 8):
        for x in range(TILE - 8, 5 * TILE + 8):
            scene[y][x] = "floor_worn"
    for y in range(2 * TILE + 4, 6 * TILE + 8):
        for x in range(6 * TILE + 12, 10 * TILE + 28):
            scene[y][x] = "floor_worn"

    sprites = []
    dk, ch = desk(), chair()
    seated = [("a", "short", False), ("b", "long", False), ("c", "curly", True), ("d", "bun", False)]
    islands = [(1, 3), (3, 3), (1, 5), (3, 5), (7, 3), (9, 3), (7, 5), (9, 5)]
    for i, (tx, ty) in enumerate(islands):
        bx, by = tx * TILE, (ty + 1) * TILE
        sprites.append((by - 26, bx + 2, ch))
        if i < 4:
            k, style, gl = seated[i]
            sprites.append((by - 22, bx + 2, character("front", *_args(k), style=style, glasses=gl, pose="sit")))
        sprites.append((by, bx, dk))
    part, cap = partition_tile(), partition_cap()
    px = 5 * TILE + 26
    for y in range(2 * TILE, 6 * TILE, 32):
        sprites.append((y + 32, px, part))
    sprites.append((2 * TILE + 4, px, cap))
    walkers = [
        ("a", "short", False, "front", "walk_a", 7 * TILE + 4, 7 * TILE + 26),
        ("e", "ponytail", False, "back", "walk_b", 11 * TILE + 8, 4 * TILE + 20),
        ("f", "swept", True, "left", "walk_a", 10 * TILE + 8, 7 * TILE + 20),
        ("g", "buzz", False, "right", "idle", 3 * TILE + 8, 7 * TILE + 30),
    ]
    for k, style, gl, d, pose, x, bottom in walkers:
        sprites.append((bottom, x, character(d, *_args(k), style=style, glasses=gl, pose=pose)))
    pl = plant()
    for x, bottom in ((12 * TILE + 12, 3 * TILE + 8), (11 * TILE + 24, 8 * TILE - 4), (5 * TILE + 20, 8 * TILE - 2)):
        sprites.append((bottom, x, pl))
    for bottom, x, spr in sorted(sprites, key=lambda s: s[0]):
        blit_bottom(scene, spr, x, bottom)
    write_png(path, scene, scale)


def sheet(path, scale=3):
    """Ficha: 4 direcoes + caminhada + sentado para um personagem; e os 7 cabelos (+ oculos)."""
    _register_cast()
    c = canvas(330, 176, "floor")
    x = 6
    for d, pose in (("front", "idle"), ("back", "idle"), ("left", "idle"), ("right", "idle"),
                    ("front", "walk_a"), ("front", "walk_b"), ("left", "walk_a"), ("left", "walk_b"), ("front", "sit")):
        blit(c, character(d, *_args("a"), style="short", pose=pose), x, 4); x += 34
    x = 6
    for i, style in enumerate(HAIR_STYLES):
        k = "abcdefg"[i]
        blit(c, character("front", *_args(k), style=style, glasses=(i % 3 == 2)), x, 62); x += 34
    x = 6
    for i, style in enumerate(HAIR_STYLES):
        k = "abcdefg"[i]
        blit(c, character("left", *_args(k), style=style, glasses=(i % 3 == 2)), x, 118); x += 34
    x = 6 + 34 * len(HAIR_STYLES) + 6
    for i, style in enumerate(("long", "ponytail", "curly")):
        blit(c, character("back", *_args("bce"[i]), style=style), x, 118); x += 34
    write_png(path, c, scale)


if __name__ == "__main__":
    if "--proof" in sys.argv:
        out = sys.argv[sys.argv.index("--proof") + 1]
        style_proof(out)
    if "--sheet" in sys.argv:
        out = sys.argv[sys.argv.index("--sheet") + 1]
        sheet(out)
