"""Arte do jogo (tile de 32 px, estilo chibi com contorno escuro e 3 tons por material).

Modo prova de estilo: monta uma cena de exemplo e grava um PNG ampliado, sem tocar no jogo.
    python3 tools/gen_art.py --export            # grava assets/art (mobilia, tiles, personagens em camadas)
    python3 tools/gen_art.py --proof saida.png   # cena de prova, sem tocar no jogo
Os icones 10x10 do HUD ficam em tools/gen_icons.py.
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
    "gold": hx("#e8b234"), "purple": hx("#8e6ce0"),
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


# --- Mobilia (continuacao): tamanhos 2x da arte antiga, ancora no canto inferior esquerdo --

def window():
    """Moldura com barras; o vidro fica transparente e o jogo desenha o ceu atras, conforme a hora."""
    c = canvas(48, 40)
    rect(c, 0, 0, 48, 40, "metal")
    rect(c, 3, 3, 42, 34, "sky")
    rect(c, 22, 3, 3, 34, "metal")
    rect(c, 3, 19, 42, 2, "metal")
    hline(c, 1, 46, 1, "metal_hi"); vline(c, 1, 1, 38, "metal_hi")
    hline(c, 1, 46, 38, "metal_lo"); vline(c, 46, 1, 38, "metal_lo")
    outline(c)
    for y in range(40):
        for x in range(48):
            if c[y][x] == "sky":
                c[y][x] = None
    return c


def partition_tile():
    c = canvas(16, 32)
    rect(c, 1, 0, 14, 32, "glass")
    rect(c, 1, 0, 2, 32, "metal_hi"); rect(c, 3, 0, 1, 32, "metal")
    rect(c, 12, 0, 1, 32, "metal"); rect(c, 13, 0, 2, 32, "metal_lo")
    for y in range(2, 30, 7):
        put(c, 6, y, "glass_hi"); put(c, 7, y + 1, "glass_hi"); put(c, 8, y + 2, "glass_hi")
    outline(c)
    return c


def partition_cap():
    c = canvas(16, 12)
    rect(c, 1, 1, 14, 10, "metal")
    hline(c, 1, 14, 1, "metal_hi"); hline(c, 1, 14, 2, "metal_hi")
    hline(c, 1, 14, 10, "metal_lo")
    outline(c)
    return c


def sofa():
    c = canvas(80, 48)
    rect(c, 6, 2, 68, 20, "red")
    rect(c, 6, 2, 68, 2, "red_hi"); rect(c, 6, 2, 3, 20, "red_hi")
    rect(c, 70, 4, 4, 18, "red_lo")
    vline(c, 40, 4, 20, "red_lo")
    rect(c, 0, 16, 10, 26, "red"); rect(c, 0, 16, 10, 2, "red_hi"); rect(c, 0, 16, 2, 26, "red_hi")
    rect(c, 70, 16, 10, 26, "red"); rect(c, 70, 16, 10, 2, "red_hi"); rect(c, 78, 18, 2, 24, "red_lo")
    rect(c, 10, 22, 60, 14, "red"); rect(c, 10, 22, 60, 2, "red_hi")
    vline(c, 40, 24, 34, "red_lo")
    rect(c, 10, 36, 60, 6, "red_lo")
    rect(c, 4, 42, 6, 4, "wood_lo"); rect(c, 70, 42, 6, 4, "wood_lo")
    rect(c, 2, 46, 76, 2, "shadow")
    outline(c)
    return c


def coffee_machine(premium=False):
    w, h = (36, 56) if premium else (32, 52)
    c = canvas(w, h)
    body = "metal_hi" if premium else "frame"
    edge = "metal" if premium else "metal_lo"
    rect(c, 3, 6, w - 6, h - 12, body)
    rect(c, 3, 6, 2, h - 12, "metal_hi" if premium else "metal_lo")
    rect(c, w - 6, 8, 3, h - 14, edge)
    rect(c, 1, 2, w - 2, 6, edge); hline(c, 1, w - 2, 2, "metal_hi")
    if premium:
        rect(c, 8, 0, w - 16, 5, "glass"); rect(c, 9, 1, 4, 1, "glass_hi")
        rect(c, 10, 2, w - 20, 2, "coffee")
    rect(c, 8, 12, w - 20, 7, "screen"); rect(c, 9, 13, 5, 2, "screen_hi")
    put(c, w - 9, 13, "red"); put(c, w - 9, 16, "leaf"); put(c, w - 12, 13, "gold" if premium else "metal")
    rect(c, 7, 24, w - 14, 14, "frame" if premium else "metal_lo")
    rect(c, 11, 29, 9, 8, "mug"); rect(c, 12, 30, 7, 1, "coffee"); put(c, 20, 32, "mug_lo")
    rect(c, w // 2 - 2, 24, 4, 3, edge)
    rect(c, 5, h - 8, w - 10, 3, edge); hline(c, 5, w - 6, h - 8, "metal_hi")
    rect(c, 3, h - 5, w - 6, 3, "frame")
    rect(c, 2, h - 2, w - 4, 2, "shadow")
    outline(c)
    return c


def water_cooler():
    c = canvas(24, 52)
    rect(c, 5, 1, 14, 16, "glass"); rect(c, 6, 2, 3, 12, "glass_hi"); rect(c, 15, 3, 3, 13, "sky")
    rect(c, 9, 0, 6, 2, "glass_hi")
    rect(c, 3, 17, 18, 28, "metal_hi"); rect(c, 3, 17, 18, 2, "metal"); rect(c, 17, 19, 4, 26, "metal")
    rect(c, 5, 20, 14, 3, "glass"); rect(c, 6, 20, 5, 1, "glass_hi")
    put(c, 8, 27, "red"); put(c, 8, 28, "red"); put(c, 14, 27, "screen"); put(c, 14, 28, "screen")
    rect(c, 6, 30, 12, 8, "metal_lo"); rect(c, 7, 31, 10, 1, "frame")
    rect(c, 3, 45, 18, 5, "metal_lo"); hline(c, 3, 20, 45, "metal")
    rect(c, 2, 50, 20, 2, "shadow")
    outline(c)
    return c


def shelf():
    c = canvas(48, 64)
    rect(c, 0, 0, 48, 64, "wood_lo")
    rect(c, 3, 3, 42, 58, "wood")
    for sy in (3, 23, 43):
        rect(c, 3, sy + 17, 42, 3, "wood_lo")
        rect(c, 3, sy, 42, 1, "wood_hi")
    books = ["red", "screen", "leaf", "gold", "purple", "red_lo", "screen_lo", "leaf_lo"]
    for row, sy in enumerate((4, 24)):
        x = 5
        i = row * 3
        while x < 43:
            bw = 4 + (i % 3)
            bh = 13 + (i % 2) * 2
            rect(c, x, sy + 16 - bh, bw, bh, books[i % len(books)])
            rect(c, x, sy + 16 - bh, 1, bh, "metal_hi" if i % 4 == 0 else books[(i + 1) % len(books)])
            x += bw + 1
            i += 1
    rect(c, 6, 46, 14, 14, "metal_hi"); rect(c, 7, 47, 12, 2, "red"); rect(c, 7, 50, 12, 8, "metal")
    rect(c, 24, 48, 10, 12, "leaf"); put(c, 26, 49, "leaf_hi"); rect(c, 26, 56, 6, 4, "pot")
    rect(c, 36, 50, 7, 10, "screen"); rect(c, 37, 51, 5, 2, "screen_hi")
    outline(c)
    return c


def whiteboard():
    c = canvas(64, 40)
    rect(c, 0, 0, 64, 40, "metal"); hline(c, 0, 63, 0, "metal_hi"); rect(c, 0, 36, 64, 4, "metal_lo")
    rect(c, 3, 3, 58, 31, "mug")
    pts = [(8, 26), (14, 22), (20, 24), (26, 16), (32, 18), (38, 11), (44, 13), (50, 7), (56, 9)]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        steps = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(steps + 1):
            put(c, x0 + (x1 - x0) * i // steps, y0 + (y1 - y0) * i // steps, "leaf")
    rect(c, 8, 6, 14, 2, "screen"); rect(c, 8, 10, 10, 2, "screen"); rect(c, 26, 6, 8, 2, "red")
    hline(c, 8, 56, 30, "metal"); vline(c, 8, 8, 30, "metal")
    rect(c, 40, 36, 12, 2, "red"); rect(c, 26, 36, 10, 2, "screen")
    outline(c)
    return c


def goals_board():
    c = canvas(48, 40)
    rect(c, 0, 0, 48, 40, "wood_lo"); rect(c, 2, 2, 44, 36, "pot_hi"); rect(c, 2, 2, 44, 2, "pot")
    for x, y, w, h, col in ((5, 5, 14, 12, "mug"), (23, 6, 12, 10, "gold"), (38, 5, 7, 8, "leaf_hi"),
                            (6, 21, 10, 12, "screen_hi"), (20, 20, 16, 14, "mug"), (38, 22, 7, 10, "red_hi")):
        rect(c, x, y, w, h, col)
        put(c, x + w // 2, y, "red")
    rect(c, 7, 8, 10, 1, "metal_lo"); rect(c, 7, 11, 8, 1, "metal_lo"); rect(c, 7, 14, 6, 1, "metal_lo")
    for i, bh in enumerate((3, 6, 9, 11)):
        rect(c, 22 + i * 3, 33 - bh, 2, bh, "leaf")
    rect(c, 25, 9, 8, 1, "frame"); rect(c, 25, 12, 6, 1, "frame")
    outline(c)
    return c


def door():
    c = canvas(40, 60)
    rect(c, 0, 0, 40, 60, "metal_lo"); rect(c, 3, 3, 34, 57, "wood")
    rect(c, 3, 3, 2, 57, "wood_hi"); rect(c, 34, 3, 3, 57, "wood_lo")
    rect(c, 8, 8, 24, 18, "wood_lo"); rect(c, 10, 10, 20, 14, "wood"); rect(c, 10, 10, 20, 2, "wood_hi")
    rect(c, 8, 32, 24, 22, "wood_lo"); rect(c, 10, 34, 20, 18, "wood"); rect(c, 10, 34, 20, 2, "wood_hi")
    rect(c, 28, 28, 6, 3, "metal_hi"); put(c, 33, 29, "metal")
    hline(c, 0, 39, 0, "metal")
    outline(c)
    return c


def pingpong():
    c = canvas(64, 44)
    rect(c, 2, 8, 60, 22, "screen"); rect(c, 2, 8, 60, 2, "screen_hi"); rect(c, 2, 26, 60, 4, "screen_lo")
    hline(c, 3, 60, 18, "mug"); vline(c, 32, 9, 29, "mug")
    rect(c, 30, 2, 5, 12, "metal_hi"); rect(c, 31, 4, 3, 9, "glass")
    rect(c, 6, 30, 5, 12, "metal_lo"); rect(c, 53, 30, 5, 12, "metal_lo")
    rect(c, 8, 30, 48, 3, "metal_lo")
    rect(c, 12, 11, 7, 5, "red"); rect(c, 13, 16, 2, 4, "wood_lo")
    rect(c, 46, 20, 7, 5, "frame"); rect(c, 48, 25, 2, 4, "wood_lo")
    rect(c, 40, 13, 3, 3, "mug")
    rect(c, 4, 42, 56, 2, "shadow")
    outline(c)
    return c


def hr_sign():
    c = canvas(40, 24)
    rect(c, 0, 0, 40, 24, "metal_lo"); rect(c, 2, 2, 36, 20, "mug"); rect(c, 2, 2, 36, 2, "metal_hi")
    heart = ["01100110", "11111111", "11111111", "01111110", "00111100", "00011000"]
    for y, row in enumerate(heart):
        for x, ch in enumerate(row):
            if ch == "1":
                put(c, 5 + x, 8 + y, "red")
    put(c, 6, 9, "red_hi")
    R = ["1110", "1001", "1001", "1110", "1010", "1001", "1001"]
    H = ["1001", "1001", "1001", "1111", "1001", "1001", "1001"]
    for gx, glyph in ((17, R), (25, H)):
        for y, row in enumerate(glyph):
            for x, ch in enumerate(row):
                if ch == "1":
                    put(c, gx + x, 7 + y, "frame")
    outline(c)
    return c


def projector_screen():
    c = canvas(96, 60)
    rect(c, 0, 0, 96, 6, "metal_lo"); rect(c, 0, 0, 96, 2, "metal")
    rect(c, 4, 6, 88, 46, "mug"); rect(c, 4, 6, 88, 1, "metal_hi")
    for i, bh in enumerate((10, 16, 12, 22, 26, 30)):
        rect(c, 14 + i * 12, 44 - bh, 8, bh, "screen" if i % 2 == 0 else "leaf")
        rect(c, 14 + i * 12, 44 - bh, 8, 2, "screen_hi" if i % 2 == 0 else "leaf_hi")
    hline(c, 10, 88, 45, "metal_lo"); vline(c, 10, 12, 45, "metal_lo")
    rect(c, 12, 10, 24, 3, "frame"); rect(c, 12, 15, 16, 2, "metal_lo")
    rect(c, 40, 52, 16, 6, "metal_lo"); rect(c, 30, 58, 36, 2, "metal")
    outline(c)
    return c


def meeting_table():
    c = canvas(96, 52)
    for x in (12, 40, 68):
        rect(c, x, 2, 16, 14, "red"); rect(c, x + 1, 2, 14, 1, "red_hi"); rect(c, x + 13, 4, 3, 12, "red_lo")
        rect(c, x + 4, 5, 8, 2, "red_lo")
    rect(c, 1, 16, 94, 10, "wood_hi"); rect(c, 1, 16, 94, 1, "wood"); rect(c, 1, 26, 94, 7, "wood"); hline(c, 1, 94, 32, "wood_lo")
    rect(c, 8, 18, 12, 5, "mug"); hline(c, 9, 18, 20, "metal_lo")
    rect(c, 34, 12, 20, 6, "frame"); rect(c, 35, 13, 18, 3, "screen"); rect(c, 33, 18, 22, 3, "metal")
    rect(c, 66, 18, 8, 5, "mug"); put(c, 74, 20, "mug_lo"); rect(c, 78, 19, 10, 4, "mug")
    rect(c, 6, 33, 6, 17, "wood_lo"); rect(c, 84, 33, 6, 17, "wood_lo"); rect(c, 6, 33, 1, 17, "wood")
    rect(c, 4, 50, 88, 2, "shadow")
    outline(c)
    return c


def chair_ergo():
    c = canvas(32, 44)
    rect(c, 11, 0, 10, 5, "frame"); rect(c, 12, 0, 8, 1, "metal_lo")
    rect(c, 7, 5, 18, 17, "frame"); rect(c, 8, 5, 16, 1, "metal_lo"); rect(c, 22, 6, 3, 16, "eye")
    for y in range(7, 21, 3):
        hline(c, 9, 21, y, "metal_lo")
    rect(c, 7, 12, 18, 2, "screen")
    rect(c, 3, 22, 26, 3, "metal_lo"); rect(c, 3, 22, 26, 1, "metal")
    rect(c, 6, 25, 20, 6, "frame"); rect(c, 6, 25, 20, 1, "metal_lo"); rect(c, 6, 30, 20, 1, "eye")
    rect(c, 14, 31, 4, 7, "metal_lo"); rect(c, 15, 31, 1, 7, "metal")
    rect(c, 5, 38, 22, 3, "metal_lo"); rect(c, 5, 38, 22, 1, "metal")
    for x in (5, 15, 25):
        rect(c, x, 41, 3, 2, "metal_lo")
    outline(c)
    return c


def desk_wide():
    c = desk()
    for y in range(0, 24):
        for x in range(20, 64):
            if c[y][x] is not None and c[y][x] != "shadow":
                c[y][x] = None
    rect(c, 26, 3, 36, 16, "frame"); rect(c, 28, 5, 32, 11, "screen"); rect(c, 28, 5, 32, 3, "screen_hi")
    rect(c, 30, 9, 10, 2, "screen_hi"); rect(c, 30, 12, 20, 1, "screen_lo"); rect(c, 44, 9, 12, 1, "screen_lo")
    rect(c, 42, 19, 6, 3, "metal_lo"); rect(c, 38, 22, 14, 2, "metal_lo")
    outline(c)
    return c


def dog():
    frames = []
    for k in range(2):
        c = canvas(32, 28)
        rect(c, 6, 10, 20, 10, "wood"); rect(c, 6, 10, 20, 2, "wood_hi"); rect(c, 6, 17, 20, 3, "wood_lo")
        rect(c, 20, 4, 10, 10, "wood"); rect(c, 21, 4, 8, 1, "wood_hi"); rect(c, 27, 8, 4, 4, "wood_lo")
        rect(c, 19, 3, 4, 6, "wood_lo"); rect(c, 26, 3, 3, 5, "wood_lo")
        put(c, 27, 7, "eye"); put(c, 30, 10, "eye"); rect(c, 25, 11, 3, 2, "mug")
        rect(c, 2, 6, 4, 6, "wood_lo"); put(c, 3, 5 + k, "wood")
        for x in (8, 13, 19, 23):
            rect(c, x, 20, 3, 6 - (k if x in (8, 19) else 0), "wood_lo")
        rect(c, 4, 26, 24, 2, "shadow")
        outline(c)
        frames.append(c)
    return hstack(frames)


def cat():
    frames = []
    for k in range(2):
        c = canvas(28, 24)
        rect(c, 6, 8, 16, 9, "metal"); rect(c, 6, 8, 16, 2, "metal_hi"); rect(c, 6, 15, 16, 2, "metal_lo")
        for x in (9, 13, 17):
            rect(c, x, 9, 2, 6, "metal_lo")
        rect(c, 18, 3, 9, 9, "metal"); rect(c, 19, 3, 7, 1, "metal_hi")
        put(c, 19, 1, "metal"); put(c, 20, 2, "metal"); put(c, 25, 1, "metal"); put(c, 24, 2, "metal")
        put(c, 21, 6, "leaf_hi"); put(c, 25, 6, "leaf_hi"); put(c, 23, 8, "blush")
        rect(c, 1, 2, 3, 8, "metal"); put(c, 2, 1, "metal"); rect(c, 3, 6, 3, 4, "metal_lo")
        for x in (8, 12, 17, 20):
            rect(c, x, 17, 2, 5 - (k if x in (8, 17) else 0), "metal_lo")
        rect(c, 4, 22, 22, 2, "shadow")
        outline(c)
        frames.append(c)
    return hstack(frames)


def hstack(frames):
    return [sum((f[y] for f in frames), []) for y in range(len(frames[0]))]


def vstack(frames):
    return [row[:] for f in frames for row in f]


# --- Exportacao das camadas do personagem -------------------------------------------
# Camadas moduladas (skin, hair_N, shirt) sao cinzas: base 216, brilho 255, sombra 160.
GRAY = {"": (216, 216, 216, 255), "_hi": (255, 255, 255, 255), "_lo": (160, 160, 160, 255)}
POSES = ("idle", "walk_a", "walk_b", "sit")
DIRECTIONS = ("front", "back", "left", "right")


def _register_gray_layers():
    for base in ("skin", "hair", "shirt"):
        for suf, col in GRAY.items():
            PAL[base + suf] = col
    color_set("pants", "#2f3542")


def _split(frame, names, keep=None):
    c = canvas(len(frame[0]), len(frame))
    for y, row in enumerate(frame):
        for x, ch in enumerate(row):
            if ch is None:
                continue
            if any(ch == n or ch.startswith(n + "_") for n in names) or (keep and ch in keep):
                c[y][x] = ch
    return c


def _outline_only(frame):
    c = canvas(len(frame[0]), len(frame))
    for y, row in enumerate(frame):
        for x, ch in enumerate(row):
            if ch == "o":
                c[y][x] = "o"
    return c


def export_characters(out_dir):
    _register_gray_layers()
    face = ("eye", "eye_hi", "eye_iris", "mouth", "blush")
    for style_idx, style in enumerate(HAIR_STYLES):
        for glasses in (False, True):
            grid = [[character(d, "skin", "hair", "shirt", "pants", style=style, glasses=glasses, pose=p)
                     for p in POSES] for d in DIRECTIONS]
            sheet = vstack([hstack(row) for row in grid])
            tag = f"{style_idx}g" if glasses else f"{style_idx}"
            ol = _outline_only(sheet)
            for y, row in enumerate(sheet):
                for x, ch in enumerate(row):
                    if ch in face or ch in ("frame", "glass_hi"):
                        ol[y][x] = ch
            write_png(os.path.join(out_dir, f"outline_{tag}.png"), ol)
            write_png(os.path.join(out_dir, f"hair_{tag}.png"), _split(sheet, ["hair"]))
            if style_idx == 0 and not glasses:
                write_png(os.path.join(out_dir, "skin.png"), _split(sheet, ["skin"]))
                write_png(os.path.join(out_dir, "shirt.png"), _split(sheet, ["shirt"]))
                write_png(os.path.join(out_dir, "legs.png"), _split(sheet, ["pants", "shoe"]))


# --- Decoracao sazonal (data/seasons.json): guirlanda repetida na parede + um objeto no chao ----
PAL.update({
    "pine": hx("#2f7d3a"), "pine_hi": hx("#4caa52"), "pine_lo": hx("#1e5427"),
    "lt_r": hx("#ff5c4d"), "lt_g": hx("#5be36a"), "lt_y": hx("#ffe066"), "lt_b": hx("#5fb8ff"), "wire": hx("#2b3340"),
    "pumpkin": hx("#f28c28"), "pumpkin_hi": hx("#ffb055"), "pumpkin_lo": hx("#b85f12"), "pface": hx("#ffe066"),
    "straw": hx("#e6c15a"), "straw_lo": hx("#b8923a"), "corn": hx("#ffd94a"), "corn_lo": hx("#d9a92a"),
    "check_r": hx("#d94a3d"), "check_w": hx("#f7f4ec"),
    "bf": hx("#14161c"), "bf_hi": hx("#2b2f3a"), "bf_y": hx("#ffd23c"),
    "box": hx("#d8a86a"), "box_hi": hx("#efc48c"), "box_lo": hx("#a67a45"), "tape": hx("#f1e9d8"),
    "string": hx("#e8e2d2"), "web": hx("#dfe4ea"),
})
FEST = ["red", "screen", "gold", "leaf_hi", "purple"]   # cores de festa (balões, bandeirinhas, serpentinas)


def garland_lights():
    """Pisca-pisca de Natal: fio caído com lâmpadas coloridas."""
    c = canvas(32, 16)
    ys = [2 + int(round(5 * (1 - ((x - 15.5) / 15.5) ** 2))) for x in range(32)]
    for x, y in enumerate(ys):
        put(c, x, y, "wire")
    for i, x in enumerate((3, 11, 19, 27)):
        col = ("lt_r", "lt_g", "lt_y", "lt_b")[i]
        y = ys[x] + 1
        put(c, x, y, "wire")
        rect(c, x - 1, y + 1, 3, 4, col)
        put(c, x - 1, y + 1, "mug")
    outline(c)
    return c


def garland_streamers():
    """Carnaval: serpentinas onduladas e confete."""
    c = canvas(32, 16)
    for i, x0 in enumerate((3, 12, 21, 28)):
        col = FEST[i % len(FEST)]
        for y in range(0, 15):
            dx = (0, 1, 1, 0, -1, -1)[(y + i) % 6]
            put(c, x0 + dx, y, col)
            put(c, x0 + dx + 1, y, col)
    for x, y, col in ((7, 9, "gold"), (17, 4, "leaf_hi"), (25, 12, "screen"), (9, 14, "red"), (15, 12, "purple")):
        put(c, x, y, col)
    outline(c)
    return c


def garland_flags():
    """Festa junina: bandeirinhas triangulares num barbante."""
    c = canvas(32, 16)
    hline(c, 0, 31, 1, "string")
    for i, x0 in enumerate((0, 8, 16, 24)):
        col = FEST[(i + 1) % len(FEST)]
        for r in range(7):
            w = 7 - r
            if w <= 0:
                break
            rect(c, x0 + r // 2 + 1, 2 + r, max(1, 7 - r), 1, col)
        put(c, x0 + 2, 3, "mug")
    outline(c)
    return c


def garland_bats():
    """Halloween: morcegos e aboborinhas de papel pendurados."""
    c = canvas(32, 16)
    hline(c, 0, 31, 1, "string")
    # morcego
    for x0 in (3, 19):
        vline(c, x0 + 4, 2, 5, "string")
        rect(c, x0 + 3, 6, 3, 3, "o")
        rect(c, x0, 7, 3, 2, "o"); rect(c, x0 + 6, 7, 3, 2, "o")
        put(c, x0, 9, "o"); put(c, x0 + 8, 9, "o")
        put(c, x0 + 3, 7, "lt_y"); put(c, x0 + 5, 7, "lt_y")
    # aboborinha
    for x0 in (12, 27):
        vline(c, x0 + 2, 2, 5, "string")
        rect(c, x0, 6, 5, 4, "pumpkin")
        put(c, x0 + 1, 7, "pumpkin_hi"); vline(c, x0 + 2, 6, 9, "pumpkin_lo")
    outline(c)
    return c


def garland_sale():
    """Black Friday: faixa preta com etiquetas amarelas de desconto."""
    c = canvas(32, 16)
    rect(c, 0, 1, 32, 12, "bf")
    hline(c, 0, 31, 2, "bf_hi")
    for x0 in (2, 18):
        rect(c, x0, 3, 11, 8, "bf_y")
        put(c, x0 + 1, 6, "bf")                                   # furo da etiqueta
        put(c, x0 + 3, 4, "bf"); put(c, x0 + 4, 4, "bf"); put(c, x0 + 3, 5, "bf"); put(c, x0 + 4, 5, "bf")   # "%"
        put(c, x0 + 8, 8, "bf"); put(c, x0 + 9, 8, "bf"); put(c, x0 + 8, 9, "bf"); put(c, x0 + 9, 9, "bf")
        for i in range(6):
            put(c, x0 + 9 - i, 4 + i, "bf")
    outline(c)
    return c


def season_tree():
    """Árvore de Natal com estrela, bolas e presentes."""
    c = canvas(40, 56)
    rect(c, 17, 46, 6, 6, "wood_lo")
    for tier, (top, h, half) in enumerate(((30, 18, 19), (18, 16, 14), (7, 14, 9))):
        for r in range(h):
            w = max(2, int(half * 2 * (r + 2) / (h + 1)))
            x = 20 - w // 2
            rect(c, x, top + r, w, 1, "pine")
            put(c, x, top + r, "pine_hi")
            if r >= h - 2:
                rect(c, x, top + r, w, 1, "pine_lo")
    for x, y, col in ((14, 42, "red"), (24, 40, "gold"), (19, 36, "screen"), (16, 28, "gold"), (23, 26, "red"),
                      (20, 20, "screen"), (18, 14, "red"), (22, 12, "gold")):
        rect(c, x, y, 2, 2, col)
    _stars(c, [(20, 5)], "gold_hi"); put(c, 20, 5, "gold")
    # presentes
    rect(c, 2, 46, 12, 9, "red"); rect(c, 2, 46, 12, 1, "red_hi"); vline(c, 8, 46, 54, "gold_hi"); hline(c, 2, 13, 49, "gold_hi")
    rect(c, 27, 48, 10, 7, "screen"); rect(c, 27, 48, 10, 1, "screen_hi"); vline(c, 32, 48, 54, "gold_hi"); hline(c, 27, 36, 51, "gold_hi")
    outline(c)
    return c


def season_balloons():
    """Cacho de balões de Carnaval preso a um peso."""
    c = canvas(28, 44)
    balls = ((4, 6, "red"), (13, 2, "screen"), (20, 7, "gold"), (8, 15, "leaf_hi"), (17, 16, "purple"))
    for x, y, col in balls:
        rect(c, x + 1, y, 5, 8, col); rect(c, x, y + 1, 7, 6, col)
        put(c, x + 2, y + 1, "mug")
        put(c, x + 3, y + 8, col)
        # linha até o peso
        for t in range(1, 30):
            lx = int(round(x + 3 + (13 - (x + 3)) * t / 30))
            ly = y + 9 + int((37 - (y + 9)) * t / 30)
            if ly < 38 and c[ly][lx] is None:
                c[ly][lx] = "metal_lo"
    rect(c, 10, 37, 7, 5, "metal"); rect(c, 10, 37, 7, 1, "metal_hi"); hline(c, 10, 16, 41, "metal_lo")
    outline(c)
    return c


def season_junina_table():
    """Mesa com toalha xadrez, chapéu de palha e espigas de milho."""
    c = canvas(40, 32)
    for y in range(12, 20):
        for x in range(2, 38):
            c[y][x] = "check_r" if ((x // 3) + (y // 3)) % 2 == 0 else "check_w"
    rect(c, 2, 20, 36, 2, "wood_lo")
    rect(c, 4, 22, 3, 9, "wood"); rect(c, 33, 22, 3, 9, "wood")
    # chapéu
    rect(c, 5, 8, 14, 3, "straw"); hline(c, 5, 18, 10, "straw_lo")
    rect(c, 8, 3, 8, 6, "straw"); rect(c, 8, 7, 8, 1, "red"); hline(c, 8, 15, 3, "straw_lo")
    # milho
    for x0 in (23, 30):
        rect(c, x0 + 1, 2, 3, 9, "corn"); put(c, x0 + 1, 3, "corn_lo"); put(c, x0 + 3, 6, "corn_lo"); put(c, x0 + 2, 9, "corn_lo")
        rect(c, x0, 8, 2, 4, "leaf"); rect(c, x0 + 3, 8, 2, 4, "leaf_hi")
    outline(c)
    return c


def season_pumpkins():
    """Duas abóboras de Halloween com rosto iluminado."""
    c = canvas(36, 24)
    def pumpkin(x, y, w, h):
        rect(c, x + 1, y, w - 2, h, "pumpkin"); rect(c, x, y + 1, w, h - 2, "pumpkin")
        for gx in range(x + 3, x + w - 2, 4):
            vline(c, gx, y + 1, y + h - 2, "pumpkin_lo")
        rect(c, x + 2, y + 1, 3, 1, "pumpkin_hi")
        rect(c, x + w // 2 - 1, y - 3, 2, 3, "leaf_lo")
        # olhos e boca
        ey = y + h // 3
        put(c, x + w // 3, ey, "pface"); put(c, x + w // 3 + 1, ey + 1, "pface"); put(c, x + w // 3 - 1, ey + 1, "pface")
        put(c, x + 2 * w // 3, ey, "pface"); put(c, x + 2 * w // 3 + 1, ey + 1, "pface"); put(c, x + 2 * w // 3 - 1, ey + 1, "pface")
        my = y + h - 4
        for i, mx in enumerate(range(x + 3, x + w - 3)):
            put(c, mx, my + (i % 2), "pface")
    pumpkin(0, 8, 20, 15)
    pumpkin(21, 12, 14, 11)
    outline(c)
    return c


def season_boxes():
    """Pilha de caixas de campanha com etiqueta de desconto."""
    c = canvas(36, 36)
    def box(x, y, w, h):
        rect(c, x, y, w, h, "box"); rect(c, x, y, w, 2, "box_hi"); rect(c, x, y + h - 2, w, 2, "box_lo")
        vline(c, x + w // 2, y, y + h - 1, "tape"); vline(c, x + w // 2 + 1, y, y + h - 1, "tape")
    box(2, 20, 20, 15)
    box(23, 24, 12, 11)
    box(6, 7, 16, 13)
    rect(c, 25, 10, 9, 7, "bf_y"); put(c, 26, 11, "bf"); put(c, 28, 11, "bf"); put(c, 29, 12, "bf"); put(c, 30, 13, "bf"); put(c, 31, 14, "bf"); put(c, 32, 15, "bf"); put(c, 26, 15, "bf")
    vline(c, 24, 8, 12, "wire")
    outline(c)
    return c


SEASON_ART = {
    "garland_lights": garland_lights, "garland_streamers": garland_streamers, "garland_flags": garland_flags,
    "garland_bats": garland_bats, "garland_sale": garland_sale,
    "tree": season_tree, "balloons": season_balloons, "junina_table": season_junina_table,
    "pumpkins": season_pumpkins, "boxes": season_boxes,
}


def export_seasons(root):
    out = os.path.join(root, "assets", "art", "seasons")
    for name, fn in SEASON_ART.items():
        write_png(os.path.join(out, f"{name}.png"), fn())


def season_sheet(path, scale=3):
    c = canvas(300, 130, "floor")
    rect(c, 0, 0, 300, 40, "wall")
    x = 4
    for name in ("garland_lights", "garland_streamers", "garland_flags", "garland_bats", "garland_sale"):
        art = SEASON_ART[name]()
        blit(c, art, x, 4); blit(c, art, x + 32, 4)
        x += 64 - 8
    x = 4
    for name in ("tree", "balloons", "junina_table", "pumpkins", "boxes"):
        blit_bottom(c, SEASON_ART[name](), x, 120)
        x += 52
    write_png(path, c, scale)



# --- Humores dos personagens (icone 16x16 em 2 quadros, desenhado acima da cabeca) ---------------
PAL.update({"steam": hx("#f4f4f6"), "steam_lo": hx("#c9cfd6"), "sweat": hx("#6fc3f5"), "sweat_hi": hx("#c9ecff"),
            "note": hx("#8e6ce0"), "note_hi": hx("#c4b0ff"), "cloud": hx("#8f9aa5"), "cloud_lo": hx("#5f6b76"),
            "rain": hx("#5fb8ff"), "spark": hx("#ffe066"), "spark_hi": hx("#fff6c0"),
            "env": hx("#fffdf8"), "env_lo": hx("#c9cfd6"), "seal": hx("#d94a3d"),
            "burst": hx("#ff5c4d"), "burst_hi": hx("#ffe066")})


def _mood_frames(draw):
    frames = []
    for k in range(2):
        c = canvas(16, 16)
        draw(c, k)
        outline(c)
        frames.append(c)
    return hstack(frames)


def mood_burnout():
    """Vapor saindo da cabeca."""
    def d(c, k):
        for i, (x, y) in enumerate(((3, 9), (8, 7), (12, 9))):
            yy = y - (k if i != 1 else 1 - k)
            rect(c, x, yy, 3, 4, "steam"); put(c, x + 1, yy - 1, "steam"); put(c, x + 1, yy + 3, "steam_lo")
            put(c, x, yy + 1, "steam_lo")
    return _mood_frames(d)


def mood_exhausted():
    """Gotas de suor caindo."""
    def d(c, k):
        for i, (x, y) in enumerate(((3, 3), (11, 6))):
            yy = y + (k * 3 if i == 0 else (1 - k) * 3)
            put(c, x + 1, yy, "sweat"); rect(c, x, yy + 1, 3, 3, "sweat"); put(c, x, yy + 1, "sweat_hi")
    return _mood_frames(d)


def mood_happy():
    """Notas musicais subindo."""
    def d(c, k):
        for i, (x, y) in enumerate(((2, 6), (9, 3))):
            yy = y - k + (i * k)
            rect(c, x, yy + 5, 3, 3, "note"); put(c, x, yy + 5, "note_hi")
            vline(c, x + 2, yy, yy + 5, "note"); hline(c, x + 2, x + 5, yy, "note")
            if i == 1:
                rect(c, x + 4, yy + 4, 3, 3, "note"); vline(c, x + 5, yy, yy + 4, "note")
    return _mood_frames(d)


def mood_sad():
    """Nuvem cinza com chuva."""
    def d(c, k):
        rect(c, 3, 3, 10, 5, "cloud"); rect(c, 5, 1, 6, 3, "cloud"); rect(c, 3, 7, 10, 1, "cloud_lo")
        put(c, 5, 2, "steam"); put(c, 6, 2, "steam")
        for x in (4, 8, 12):
            put(c, x, 10 + ((k + x // 4) % 2) * 2, "rain")
    return _mood_frames(d)


def mood_celebrating():
    """Brilhos."""
    def d(c, k):
        pts = ((3, 4), (11, 2), (8, 10), (13, 11)) if k == 0 else ((2, 10), (12, 5), (6, 2), (9, 13))
        for x, y in pts:
            put(c, x, y, "spark_hi"); put(c, x - 1, y, "spark"); put(c, x + 1, y, "spark")
            put(c, x, y - 1, "spark"); put(c, x, y + 1, "spark")
    return _mood_frames(d)


def mood_courted():
    """Envelope (proposta recebida)."""
    def d(c, k):
        rect(c, 2, 4 + k, 12, 8, "env"); hline(c, 2, 13, 11 + k, "env_lo")
        for i in range(6):
            put(c, 2 + i, 4 + k + i, "env_lo"); put(c, 13 - i, 4 + k + i, "env_lo")
        put(c, 7, 8 + k, "seal"); put(c, 8, 8 + k, "seal")
    return _mood_frames(d)


def mood_burst():
    """Estouro do burnout (1 s)."""
    def d(c, k):
        r = 6 if k == 0 else 7
        for dx, dy in ((r, 0), (-r, 0), (0, r), (0, -r), (r - 2, r - 2), (-(r - 2), r - 2), (r - 2, -(r - 2)), (-(r - 2), -(r - 2))):
            put(c, 8 + dx, 8 + dy, "burst"); put(c, 8 + dx // 2, 8 + dy // 2, "burst_hi")
        rect(c, 7, 7, 3, 3, "burst_hi")
    return _mood_frames(d)


def held_box():
    """Caixa de mudanca carregada na frente do corpo."""
    c = canvas(14, 11)
    rect(c, 0, 1, 14, 10, "box"); rect(c, 0, 1, 14, 2, "box_hi"); rect(c, 0, 9, 14, 2, "box_lo")
    vline(c, 6, 1, 10, "tape"); vline(c, 7, 1, 10, "tape")
    outline(c)
    return c


MOOD_ART = {"burnout": mood_burnout, "exhausted": mood_exhausted, "happy": mood_happy, "sad": mood_sad,
            "celebrating": mood_celebrating, "courted": mood_courted, "burst": mood_burst}


def export_moods(root):
    out = os.path.join(root, "assets", "art", "moods")
    for name, fn in MOOD_ART.items():
        write_png(os.path.join(out, f"{name}.png"), fn())
    write_png(os.path.join(out, "box.png"), held_box())


def mood_sheet(path, scale=4):
    c = canvas(150, 40, "floor")
    x = 4
    for name in MOOD_ART:
        blit(c, MOOD_ART[name](), x, 4); x += 36
    blit(c, held_box(), 4, 26)
    write_png(path, c, scale)



# --- World Map isometrico (270x640 em 1x, exibido em 2x) ------------------------------------------
MAP_W, MAP_H = 270, 640
PAL.update({
    "g_sub": hx("#8fcf6e"), "g_sub_lo": hx("#78b85c"), "g_park": hx("#6fbf62"), "g_park_lo": hx("#5aa64f"),
    "g_urb": hx("#b7bcc4"), "g_urb_lo": hx("#a2a8b1"), "g_dist": hx("#9ea6b3"), "g_dist_lo": hx("#8a93a1"),
    "g_glob": hx("#c8cfd8"), "g_glob_lo": hx("#b3bbc6"), "sand": hx("#efd9a0"), "sand_lo": hx("#d9c085"),
    "sea": hx("#3f8fd0"), "sea_hi": hx("#6fb3e6"), "sea_lo": hx("#2f6fa8"), "foam2": hx("#cfe9f7"),
    "iso_road": hx("#4e5561"), "iso_road_lo": hx("#3d434d"), "iso_lane": hx("#e4d27a"), "path": hx("#f7f1e0"), "path_lo": hx("#d9d0b8"),
    "h_wall": hx("#f1e3c8"), "h_wall_lo": hx("#cfbf9d"), "h_roof_r": hx("#c95c48"), "h_roof_r_lo": hx("#9a4234"),
    "h_roof_b": hx("#4a7fb8"), "h_roof_b_lo": hx("#345f8f"), "h_roof_g": hx("#5fa35a"), "h_roof_g_lo": hx("#437a40"),
    "b_gray": hx("#c3c8d1"), "b_gray_l": hx("#a9afba"), "b_gray_r": hx("#8e95a1"), "b_beige": hx("#e2cfae"), "b_beige_l": hx("#c6b391"), "b_beige_r": hx("#a99676"),
    "b_brick": hx("#c8735a"), "b_brick_l": hx("#a85a44"), "b_brick_r": hx("#874536"), "b_glass": hx("#8fc6ec"), "b_glass_l": hx("#5f9fd0"), "b_glass_r": hx("#3f7fb0"),
    "b_navy": hx("#3e5f8f"), "b_navy_l": hx("#2f4a70"), "b_navy_r": hx("#233858"), "b_white": hx("#eef1f5"), "b_white_l": hx("#c9d0da"), "b_white_r": hx("#a6b0bd"),
    "b_win": hx("#f5e8a8"), "b_win_d": hx("#2c3a4e"), "iso_tree": hx("#4f9a4a"), "iso_tree_hi": hx("#7fc56a"), "iso_tree_lo": hx("#2f6b33"), "iso_trunk": hx("#7a4a25"),
    "light_w": hx("#fbfbfb"), "light_r": hx("#e04a3c"), "pin": hx("#3cc36a"), "gold2": hx("#f2c744"),
})
ISO_TW, ISO_TH = 16, 8   # tile isometrico em 1x (losango 16x8)


def fill_poly(c, pts, ch):
    """Preenche um poligono convexo (scanline) sem contorno."""
    h, w = len(c), len(c[0])
    ys = [p[1] for p in pts]
    for y in range(max(0, int(min(ys))), min(h - 1, int(max(ys))) + 1):
        xs = []
        n = len(pts)
        for i in range(n):
            (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % n]
            if y0 == y1:
                continue
            if (y >= min(y0, y1)) and (y < max(y0, y1)):
                xs.append(x0 + (y - y0) * (x1 - x0) / (y1 - y0))
        if len(xs) >= 2:
            xs.sort()
            for x in range(max(0, int(round(xs[0]))), min(w - 1, int(round(xs[-1]))) + 1):
                c[y][x] = ch


def iso_pt(i, j, ox, oy):
    return (ox + (i - j) * (ISO_TW // 2), oy + (i + j) * (ISO_TH // 2))


def iso_tile(c, i, j, ox, oy, ch, edge=None):
    x, y = iso_pt(i, j, ox, oy)
    pts = [(x, y), (x + 8, y + 4), (x, y + 8), (x - 8, y + 4)]
    fill_poly(c, pts, ch)
    if edge:
        for (x0, y0), (x1, y1) in ((pts[3], pts[2]), (pts[2], pts[1])):
            steps = max(abs(x1 - x0), abs(y1 - y0))
            for t in range(steps + 1):
                put(c, int(round(x0 + (x1 - x0) * t / steps)), int(round(y0 + (y1 - y0) * t / steps)), edge)


def iso_box(c, i, j, a, b, h, ox, oy, top, left, right, win=None, win_rows=None):
    """Caixa isometrica com base a x b tiles a partir do tile (i, j) e altura h px."""
    p0 = iso_pt(i, j, ox, oy)            # norte
    p1 = iso_pt(i + a, j, ox, oy)        # leste
    p2 = iso_pt(i + a, j + b, ox, oy)    # sul
    p3 = iso_pt(i, j + b, ox, oy)        # oeste
    up = lambda p: (p[0], p[1] - h)
    fill_poly(c, [up(p3), up(p2), p2, p3], left)
    fill_poly(c, [up(p2), up(p1), p1, p2], right)
    fill_poly(c, [up(p0), up(p1), up(p2), up(p3)], top)
    if win and h >= 10:
        rows = win_rows or max(1, (h - 6) // 7)
        for r in range(rows):
            yy = p2[1] - h + 5 + r * 7
            # face esquerda (de p3 a p2): x cresce, y cresce 1 a cada 2 px
            for k in range(2, a * 8 + b * 8 - 2, 5):
                if k < b * 8:
                    x = p3[0] + k; y = yy + k // 2
                    if k % 5 == 2:
                        rect(c, x, y, 2, 3, win)
            for k in range(2, a * 8 - 2, 5):
                x = p2[0] + k; y = yy + (b * 8) // 2 - k // 2
                rect(c, x, y, 2, 3, win)


def iso_tree(c, x, y, size=5):
    rect(c, x - 1, y - 2, 2, 3, "iso_trunk")
    fill_poly(c, [(x, y - size * 2 - 2), (x + size, y - size), (x, y - 2), (x - size, y - size)], "iso_tree")
    fill_poly(c, [(x, y - size * 2 - 2), (x + size // 2, y - size - 1), (x, y - size), (x - size // 2, y - size - 1)], "iso_tree_hi")
    put(c, x - size + 1, y - size, "iso_tree_lo"); put(c, x + 1, y - 3, "iso_tree_lo")


def _band_of(y):
    """Faixa da regiao pela altura no mapa (1 embaixo ... 5 em cima)."""
    if y >= 500: return 1
    if y >= 380: return 2
    if y >= 250: return 3
    if y >= 130: return 4
    return 5


def world_map(regions_pos):
    """regions_pos: lista de (x, y) dos marcos das 5 regioes em 1x, de baixo para cima."""
    import random
    rng = random.Random(7)
    c = canvas(MAP_W, MAP_H, "sea")
    ox, oy = MAP_W // 2 + 40, -40
    ground = {1: ("g_sub", "g_sub_lo"), 2: ("g_park", "g_park_lo"), 3: ("g_urb", "g_urb_lo"), 4: ("g_dist", "g_dist_lo"), 5: ("g_glob", "g_glob_lo")}
    # terreno: losangos por faixa; o topo vira mar com praia e uma ilha
    tiles = {}
    for i in range(-70, 100):
        for j in range(-70, 140):
            x, y = iso_pt(i, j, ox, oy)
            if y < -8 or y > MAP_H + 8 or x < -8 or x > MAP_W + 8:
                continue
            band = _band_of(y + 4)
            sea = (y < 96 and x > 60 + (96 - y) * 2) or (y < 40)
            island = (x - 215) ** 2 / 900.0 + (y - 60) ** 2 / 300.0 < 1.0
            if island:
                tiles[(i, j)] = "sand" if (x - 215) ** 2 / 900.0 + (y - 60) ** 2 / 300.0 > 0.55 else "g_park"
            elif sea:
                tiles[(i, j)] = "sea_hi" if (i + j) % 7 == 0 else "sea"
            else:
                g, glo = ground[band]
                tiles[(i, j)] = glo if (i * 7 + j * 3) % 11 == 0 else g
    # estrada de progresso: tiles proximos da polilinha entre os marcos
    def near_path(x, y):
        best = 1e9
        for (x0, y0), (x1, y1) in zip(regions_pos, regions_pos[1:]):
            dx, dy = x1 - x0, y1 - y0
            t = max(0.0, min(1.0, ((x - x0) * dx + (y - y0) * dy) / float(dx * dx + dy * dy)))
            px, py = x0 + dx * t, y0 + dy * t
            best = min(best, ((x - px) ** 2 + ((y - py) * 2) ** 2) ** 0.5)
        return best
    for (i, j), ch in list(tiles.items()):
        x, y = iso_pt(i, j, ox, oy)
        if ch.startswith("sea") or ch == "sand":
            continue
        d = near_path(x, y + 4)
        if d < 9:
            tiles[(i, j)] = "iso_road"
        elif d < 13 and (i + j) % 2 == 0:
            tiles[(i, j)] = "path"
    # ruas secundarias em grade
    for (i, j), ch in list(tiles.items()):
        if ch in ("sea", "sea_hi", "sand", "iso_road", "path"):
            continue
        x, y = iso_pt(i, j, ox, oy)
        band = _band_of(y + 4)
        if band >= 2 and (i % 9 == 0 or j % 9 == 0):
            tiles[(i, j)] = "iso_road_lo"
    for (i, j) in sorted(tiles, key=lambda t: (t[0] + t[1], t[0])):
        ch = tiles[(i, j)]
        iso_tile(c, i, j, ox, oy, ch, edge=None)
    # ondas
    for (i, j), ch in tiles.items():
        if ch == "sea" and (i * 3 + j * 5) % 13 == 0:
            x, y = iso_pt(i, j, ox, oy)
            hline(c, x - 3, x + 3, y + 4, "foam2")
    # predios por faixa (ordenados por profundidade i+j)
    boxes = []
    for (i, j), ch in tiles.items():
        if ch not in ("g_sub", "g_sub_lo", "g_park", "g_park_lo", "g_urb", "g_urb_lo", "g_dist", "g_dist_lo", "g_glob", "g_glob_lo"):
            continue
        x, y = iso_pt(i, j, ox, oy)
        if near_path(x, y + 4) < 20 or (i % 9 in (0, 8)) or (j % 9 in (0, 8)):
            continue
        band = _band_of(y + 4)
        if x < 12 or x > MAP_W - 12:
            continue
        r = rng.random()
        if band == 1:
            if r < 0.16:
                roof = rng.choice([("h_roof_r", "h_roof_r_lo"), ("h_roof_b", "h_roof_b_lo"), ("h_roof_g", "h_roof_g_lo")])
                boxes.append((i + j, ("house", i, j, roof)))
            elif r < 0.30:
                boxes.append((i + j, ("tree", i, j)))
        elif band == 2:
            if r < 0.14:
                boxes.append((i + j, ("box", i, j, 1, 1, rng.randint(10, 18), rng.choice(["b_beige", "b_brick", "b_gray"]))))
            elif r < 0.24:
                boxes.append((i + j, ("tree", i, j)))
        elif band == 3:
            if r < 0.15:
                boxes.append((i + j, ("box", i, j, 1, 1, rng.randint(16, 30), rng.choice(["b_gray", "b_beige", "b_glass"]))))
            elif r < 0.20:
                boxes.append((i + j, ("tree", i, j)))
        elif band == 4:
            if r < 0.16:
                boxes.append((i + j, ("box", i, j, 1, 1, rng.randint(26, 46), rng.choice(["b_glass", "b_navy", "b_gray"]))))
        else:
            if r < 0.15:
                boxes.append((i + j, ("box", i, j, 1, 1, rng.randint(34, 58), rng.choice(["b_glass", "b_white", "b_navy"]))))
    faces = {"b_gray": ("b_gray", "b_gray_l", "b_gray_r"), "b_beige": ("b_beige", "b_beige_l", "b_beige_r"), "b_brick": ("b_brick", "b_brick_l", "b_brick_r"),
             "b_glass": ("b_glass", "b_glass_l", "b_glass_r"), "b_navy": ("b_navy", "b_navy_l", "b_navy_r"), "b_white": ("b_white", "b_white_l", "b_white_r")}
    for _, item in sorted(boxes, key=lambda t: t[0]):
        kind = item[0]
        if kind == "tree":
            x, y = iso_pt(item[1], item[2], ox, oy)
            iso_tree(c, x, y + 6, 4)
        elif kind == "house":
            _, i, j, roof = item
            iso_box(c, i, j, 1, 1, 7, ox, oy, roof[0], "h_wall", "h_wall_lo")
            x, y = iso_pt(i, j, ox, oy)
            put(c, x + 3, y - 2, "b_win_d"); put(c, x - 5, y - 1, "b_win_d")
        else:
            _, i, j, a, b, h, col = item
            top, left, right = faces[col]
            iso_box(c, i, j, a, b, h, ox, oy, top, left, right, win="b_win" if col in ("b_gray", "b_beige", "b_brick") else "b_win_d")
    # farol na ilha
    fx, fy = 232, 52
    rect(c, fx - 3, fy - 22, 6, 22, "light_w")
    for yy in range(fy - 20, fy, 6):
        rect(c, fx - 3, yy, 6, 3, "light_r")
    rect(c, fx - 4, fy - 26, 8, 4, "b_navy"); rect(c, fx - 2, fy - 25, 4, 2, "b_win")
    outline_region(c, 0, 0, MAP_W, MAP_H)
    return c


def outline_region(c, x0, y0, w, h):
    """Contorno escuro so em volta dos predios (pixels nao-terreno) — mantem o mapa legivel em 2x."""
    ground = {"g_sub", "g_sub_lo", "g_park", "g_park_lo", "g_urb", "g_urb_lo", "g_dist", "g_dist_lo", "g_glob", "g_glob_lo",
              "sand", "sea", "sea_hi", "foam2", "iso_road", "iso_road_lo", "iso_lane", "path", "path_lo", None}
    src = [row[:] for row in c]
    for y in range(y0 + 1, y0 + h - 1):
        for x in range(x0 + 1, x0 + w - 1):
            if src[y][x] in ground:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if src[y + dy][x + dx] not in ground:
                        c[y][x] = "o"
                        break


def map_pin():
    """Pino verde do escritorio (16x22)."""
    c = canvas(16, 22)
    fill_poly(c, [(8, 1), (14, 7), (8, 20), (2, 7)], "pin")
    rect(c, 3, 3, 10, 8, "pin"); rect(c, 5, 4, 6, 6, "mug"); rect(c, 6, 5, 4, 4, "pin")
    outline(c)
    return c


def map_lock():
    c = canvas(14, 16)
    rect(c, 2, 7, 10, 8, "metal_lo"); rect(c, 3, 8, 8, 6, "metal"); rect(c, 6, 10, 2, 3, "o")
    rect(c, 4, 2, 6, 6, "metal_lo"); rect(c, 5, 3, 4, 5, None)
    for x in (4, 9):
        rect(c, x, 2, 1, 6, "metal_lo")
    rect(c, 5, 2, 4, 1, "metal_lo")
    outline(c)
    return c


def map_star():
    c = canvas(12, 12)
    fill_poly(c, [(6, 0), (8, 4), (12, 4), (9, 7), (10, 12), (6, 9), (2, 12), (3, 7), (0, 4), (4, 4)], "gold2")
    outline(c)
    return c


def rival_hq(color="b_brick"):
    """Sede de agencia concorrente (predio isometrico 2x2 com bandeira), 40x56."""
    faces = {"b_brick": ("b_brick", "b_brick_l", "b_brick_r"), "b_navy": ("b_navy", "b_navy_l", "b_navy_r"), "b_glass": ("b_glass", "b_glass_l", "b_glass_r")}
    c = canvas(40, 56)
    top, left, right = faces[color]
    iso_box(c, 0, 0, 2, 2, 30, 20, 22, top, left, right, win="b_win")
    rect(c, 19, 2, 2, 22, "metal_lo"); rect(c, 21, 3, 10, 6, "light_r"); rect(c, 22, 4, 8, 4, "gold2")
    outline(c)
    return c


def export_map(root, regions_pos):
    out = os.path.join(root, "assets", "art", "map")
    write_png(os.path.join(out, "world.png"), world_map(regions_pos))
    write_png(os.path.join(out, "pin.png"), map_pin())
    write_png(os.path.join(out, "lock.png"), map_lock())
    write_png(os.path.join(out, "star.png"), map_star())
    for col in ("b_brick", "b_navy", "b_glass"):
        write_png(os.path.join(out, f"rival_{col[2:]}.png"), rival_hq(col))


def _regions_pos(root):
    import json
    with open(os.path.join(root, "data", "regions.json"), encoding="utf-8") as fh:
        return [tuple(r["map_pos"]) for r in json.load(fh)["regions"]]



# --- Mobilia das regioes (bloco D) ---------------------------------------------------------
PAL.update({"steel": hx("#8d97a5"), "steel_hi": hx("#c2cad4"), "steel_lo": hx("#5b6470"), "mat": hx("#3f7fb0"), "mat_hi": hx("#6fa6d6"),
            "deck": hx("#c98a4b"), "deck_lo": hx("#9a6332"), "rail": hx("#d9dee6"), "led": hx("#5be36a"), "led_r": hx("#ff5c4d"),
            "tile_w": hx("#f2f2f2"), "tile_g": hx("#dfe6ea"), "counter": hx("#e8dcc4"), "counter_lo": hx("#c6b89b")})


def reception():
    """Balcao de recepcao com sofa pequeno e tablet (48x40)."""
    c = canvas(48, 40)
    rect(c, 2, 14, 30, 18, "wood"); rect(c, 2, 14, 30, 3, "wood_hi"); rect(c, 2, 29, 30, 3, "wood_lo")
    rect(c, 6, 18, 22, 8, "wood_lo"); draw_text = None
    rect(c, 10, 8, 8, 6, "frame"); rect(c, 11, 9, 6, 4, "screen")
    rect(c, 34, 20, 13, 12, "red"); rect(c, 34, 18, 13, 3, "red_hi"); rect(c, 34, 30, 13, 2, "red_lo"); rect(c, 33, 22, 2, 8, "red_lo"); rect(c, 46, 22, 2, 8, "red_lo")
    rect(c, 4, 32, 26, 6, "shadow"); rect(c, 34, 32, 13, 4, "shadow")
    outline(c)
    return c


def glass_room():
    """Sala de reuniao envidracada com mesa e telao (64x48)."""
    c = canvas(64, 48)
    rect(c, 0, 0, 64, 40, "glass"); rect(c, 0, 0, 64, 40, None)
    rect(c, 0, 0, 2, 40, "metal"); rect(c, 62, 0, 2, 40, "metal"); rect(c, 0, 0, 64, 2, "metal"); rect(c, 31, 0, 2, 40, "metal")
    for x in range(3, 62, 1):
        for y in range(3, 12):
            if (x + y) % 5 == 0:
                put(c, x, y, "glass_hi")
    rect(c, 4, 4, 20, 12, "frame"); rect(c, 5, 5, 18, 10, "screen"); rect(c, 7, 8, 8, 2, "screen_hi"); rect(c, 7, 11, 12, 1, "screen_lo")
    rect(c, 12, 22, 40, 12, "wood"); rect(c, 12, 22, 40, 2, "wood_hi"); rect(c, 12, 32, 40, 2, "wood_lo")
    for x in (10, 26, 42):
        rect(c, x, 36, 8, 4, "metal_lo"); rect(c, x + 1, 33, 6, 3, "red")
    rect(c, 2, 40, 60, 6, "shadow")
    outline(c)
    return c


def studio():
    """Estudio: microfone de pedestal, painel acustico e luz ON AIR (32x48)."""
    c = canvas(32, 48)
    rect(c, 0, 4, 32, 26, "foam"); 
    for y in range(6, 30, 6):
        for x in range(2, 30, 6):
            rect(c, x, y, 3, 3, "foam_hi")
    rect(c, 8, 0, 16, 6, "onair_lo"); rect(c, 10, 1, 12, 4, "onair")
    rect(c, 14, 20, 4, 20, "metal_lo"); rect(c, 10, 40, 12, 3, "metal")
    rect(c, 12, 12, 8, 10, "metal"); rect(c, 13, 13, 6, 8, "metal_hi"); rect(c, 14, 14, 4, 2, "metal_lo")
    rect(c, 6, 43, 20, 4, "shadow")
    outline(c)
    return c


def kitchen():
    """Cozinha: bancada com fogao, pia e geladeira (64x44)."""
    c = canvas(64, 44)
    rect(c, 0, 12, 40, 22, "counter"); rect(c, 0, 12, 40, 3, "tile_w"); rect(c, 0, 31, 40, 3, "counter_lo")
    rect(c, 4, 16, 14, 8, "metal"); 
    for x, y in ((6, 18), (12, 18), (6, 21), (12, 21)):
        rect(c, x, y, 3, 2, "frame")
    rect(c, 22, 16, 14, 8, "metal_hi"); rect(c, 24, 18, 10, 4, "glass"); rect(c, 28, 12, 2, 5, "metal_lo")
    rect(c, 44, 2, 18, 32, "tile_g"); rect(c, 44, 2, 18, 2, "tile_w"); rect(c, 44, 16, 18, 1, "metal_lo"); rect(c, 58, 6, 2, 8, "metal_lo"); rect(c, 58, 19, 2, 8, "metal_lo")
    rect(c, 2, 34, 36, 6, "shadow"); rect(c, 44, 34, 18, 6, "shadow")
    outline(c)
    return c


def gym():
    """Academia: esteira, halteres e colchonete (56x44)."""
    c = canvas(56, 44)
    rect(c, 2, 26, 30, 8, "steel"); rect(c, 2, 26, 30, 2, "steel_hi"); rect(c, 2, 32, 30, 2, "steel_lo")
    rect(c, 26, 6, 4, 22, "steel_lo"); rect(c, 18, 4, 14, 6, "frame"); rect(c, 20, 5, 10, 3, "screen")
    rect(c, 36, 20, 18, 12, "mat"); rect(c, 36, 20, 18, 2, "mat_hi")
    for x in (38, 46):
        rect(c, x, 14, 3, 6, "steel_lo"); rect(c, x + 3, 16, 4, 2, "steel"); rect(c, x + 7, 14, 3, 6, "steel_lo")
    rect(c, 4, 34, 28, 6, "shadow"); rect(c, 36, 32, 18, 6, "shadow")
    outline(c)
    return c


def server_rack():
    """War room: rack de servidores com leds e telao de dashboards (48x56)."""
    c = canvas(48, 56)
    rect(c, 2, 8, 20, 44, "steel_lo"); rect(c, 2, 8, 20, 2, "steel")
    for y in range(12, 50, 6):
        rect(c, 4, y, 16, 4, "steel"); put(c, 18, y + 1, "led" if (y // 6) % 3 else "led_r"); put(c, 16, y + 1, "led")
    rect(c, 26, 4, 20, 26, "frame"); rect(c, 27, 5, 18, 24, "screen_lo")
    for i, h in enumerate((6, 10, 8, 14, 11, 16)):
        rect(c, 28 + i * 3, 27 - h, 2, h, "screen_hi" if i % 2 else "gold")
    rect(c, 34, 30, 4, 6, "metal_lo"); rect(c, 30, 36, 12, 2, "metal_lo")
    rect(c, 4, 52, 18, 3, "shadow"); rect(c, 28, 38, 16, 3, "shadow")
    outline(c)
    return c


def terrace():
    """Terraco: deck de madeira com guarda-corpo, espreguicadeira e plantas (64x40)."""
    c = canvas(64, 40)
    rect(c, 0, 14, 64, 20, "deck")
    for y in range(16, 34, 4):
        hline(c, 0, 63, y, "deck_lo")
    rect(c, 0, 4, 64, 2, "rail"); 
    for x in range(2, 64, 8):
        rect(c, x, 4, 2, 10, "rail")
    rect(c, 10, 20, 22, 8, "red"); rect(c, 10, 18, 8, 4, "red_hi"); rect(c, 10, 28, 22, 2, "red_lo"); rect(c, 12, 30, 2, 3, "metal_lo"); rect(c, 28, 30, 2, 3, "metal_lo")
    for x in (40, 52):
        rect(c, x, 22, 8, 8, "pot"); rect(c, x, 22, 8, 2, "pot_hi"); rect(c, x + 1, 14, 6, 8, "leaf"); rect(c, x + 2, 12, 4, 3, "leaf_hi"); put(c, x + 1, 20, "leaf_lo")
    rect(c, 2, 34, 60, 5, "shadow")
    outline(c)
    return c



def export_all(root):
    art = os.path.join(root, "assets", "art")
    write_png(os.path.join(art, "tiles", "floor_wood.png"), floor_tile())
    write_png(os.path.join(art, "tiles", "floor_worn.png"), floor_tile(True))
    write_png(os.path.join(art, "tiles", "wall.png"), wall_tile())
    write_png(os.path.join(art, "tiles", "wall_pillar.png"), pillar())
    for name, fn in (("desk", desk), ("desk_wide", desk_wide), ("chair", chair), ("chair_ergo", chair_ergo),
                     ("sofa", sofa), ("plant", plant), ("coffee", coffee_machine),
                     ("coffee_premium", lambda: coffee_machine(True)), ("cooler", water_cooler),
                     ("shelf", shelf), ("window", window), ("whiteboard", whiteboard), ("goals_board", goals_board),
                     ("door", door), ("pingpong", pingpong), ("partition", partition_tile),
                     ("partition_top", partition_cap), ("hr_sign", hr_sign), ("projector", projector_screen),
                     ("meeting_table", meeting_table), ("dog", dog), ("cat", cat),
                     ("reception", reception), ("glass_room", glass_room), ("studio", studio), ("kitchen", kitchen),
                     ("gym", gym), ("server_rack", server_rack), ("terrace", terrace)):
        write_png(os.path.join(art, "furniture", f"{name}.png"), fn())
    export_characters(os.path.join(art, "characters"))
    export_scenes(root)
    export_title(root)
    export_seasons(root)
    export_moods(root)
    export_map(root, _regions_pos(root))


def furniture_sheet(path, scale=2):
    items = [desk(), desk_wide(), chair(), chair_ergo(), sofa(), plant(), coffee_machine(), coffee_machine(True),
             water_cooler(), shelf(), window(), whiteboard(), goals_board(), door(), pingpong(), partition_tile(),
             partition_cap(), hr_sign(), projector_screen(), meeting_table(), dog(), cat(), wall_tile(), pillar()]
    c = canvas(560, 300, "floor")
    x, y, row_h = 6, 6, 0
    for it in items:
        w, h = len(it[0]), len(it)
        if x + w > 554:
            x, y, row_h = 6, y + row_h + 8, 0
        blit(c, it, x, y)
        x += w + 8
        row_h = max(row_h, h)
    write_png(path, c, scale)


# --- Cenarios de evento (270x168, exibidos em 2x no lugar do escritorio) -------------------
SCENE_W, SCENE_H = 270, 168
PAL.update({
    "night": hx("#1b2438"), "night_hi": hx("#2a3654"), "night_lo": hx("#111826"),
    "spot": (255, 236, 190, 34), "spot_hi": (255, 246, 220, 52),
    "curtain": hx("#a8322b"), "curtain_hi": hx("#c9463c"), "curtain_lo": hx("#6e1f1a"),
    "gold_hi": hx("#f6d675"), "gold_lo": hx("#a87a14"),
    "hall": hx("#dfe6ea"), "hall_lo": hx("#c3cdd4"), "hall_floor": hx("#b9c2c8"),
    "sky_night": hx("#243559"), "city": hx("#0f1727"), "city_win": hx("#f2d27a"),
    "foam": hx("#2c2f3a"), "foam_hi": hx("#3a3e4c"),
    "onair": hx("#ff5a4a"), "onair_lo": hx("#5a1b16"),
    "paper": hx("#f7f4ec"), "flash": (255, 255, 255, 150),
})


def _spotlight(c, x_top, x_bottom_l, x_bottom_r, y_bottom):
    """Cone de luz translucido do topo ate o palco."""
    for y in range(0, y_bottom):
        t = y / max(1, y_bottom - 1)
        l = int(x_top + (x_bottom_l - x_top) * t)
        r = int(x_top + (x_bottom_r - x_top) * t)
        for x in range(l, r + 1):
            if c[y][x] is not None and c[y][x] != "spot" and c[y][x] != "spot_hi":
                c[y][x] = "spot_hi" if abs(x - (l + r) / 2) < (r - l) * 0.25 else "spot"


def _planks(c, y0, y1, hi_rows=1):
    rect(c, 0, y0, SCENE_W, y1 - y0, "wood")
    for y in range(y0, y1, 6):
        hline(c, 0, SCENE_W - 1, y, "wood_lo")
    for y in range(y0 + 1, y0 + 1 + hi_rows):
        hline(c, 0, SCENE_W - 1, y, "wood_hi")


def _stars(c, pts, col="gold_hi"):
    for x, y in pts:
        put(c, x, y, col); put(c, x - 1, y, col); put(c, x + 1, y, col); put(c, x, y - 1, col); put(c, x, y + 1, col)


def _trophy_big(c, cx, y, col="gold", hi="gold_hi", lo="gold_lo"):
    rect(c, cx - 10, y, 20, 14, col); rect(c, cx - 9, y, 8, 2, hi); rect(c, cx + 6, y + 2, 4, 12, lo)
    rect(c, cx - 14, y + 2, 4, 8, col); rect(c, cx + 10, y + 2, 4, 8, col)
    rect(c, cx - 8, y + 14, 16, 3, col); rect(c, cx - 3, y + 17, 6, 6, lo); rect(c, cx - 9, y + 23, 18, 4, col)
    rect(c, cx - 9, y + 23, 18, 1, hi)


def scene_stage():
    c = canvas(SCENE_W, SCENE_H, "night")
    rect(c, 0, 0, SCENE_W, 48, "curtain")
    for x in range(0, SCENE_W, 14):
        rect(c, x, 0, 4, 48, "curtain_hi"); rect(c, x + 9, 0, 3, 48, "curtain_lo")
    for x in range(0, SCENE_W, 14):
        rect(c, x + 2, 44, 10, 4, "curtain_lo")
    rect(c, 0, 48, SCENE_W, 4, "gold"); hline(c, 0, SCENE_W - 1, 48, "gold_hi")
    # painel de fundo com trofeu e estrelas
    rect(c, 70, 58, 130, 60, "night_lo"); rect(c, 72, 60, 126, 56, "sky_night")
    rect(c, 70, 58, 130, 2, "gold"); rect(c, 70, 116, 130, 2, "gold"); rect(c, 70, 58, 2, 60, "gold"); rect(c, 198, 58, 2, 60, "gold")
    _trophy_big(c, 135, 70)
    _stars(c, ((88, 72), (182, 70), (96, 100), (176, 104), (110, 66), (160, 112)))
    _spotlight(c, 40, 80, 140, 128); _spotlight(c, 230, 130, 190, 128)
    _planks(c, 128, 152); rect(c, 0, 152, SCENE_W, 16, "wood_lo"); hline(c, 0, SCENE_W - 1, 152, "wood")
    for x in range(6, SCENE_W, 12):
        put(c, x, 158, "gold_hi")
    # confete
    cols = ("red_hi", "gold_hi", "screen_hi", "leaf_hi", "purple", "mug")
    for i in range(70):
        x = (i * 37 + 11) % SCENE_W; y = (i * 53 + 7) % 120
        rect(c, x, y, 2, 1, cols[i % len(cols)])
    return c


def scene_auditorium():
    c = canvas(SCENE_W, SCENE_H, "night_hi")
    rect(c, 0, 0, SCENE_W, 16, "night"); rect(c, 0, 16, SCENE_W, 2, "night_lo")
    # telao
    rect(c, 62, 22, 146, 76, "metal_lo"); rect(c, 66, 26, 138, 68, "paper"); rect(c, 66, 26, 138, 2, "metal_hi")
    for i, bh in enumerate((14, 22, 18, 30, 36, 44, 40)):
        rect(c, 82 + i * 16, 84 - bh, 10, bh, "screen" if i % 2 == 0 else "leaf")
        rect(c, 82 + i * 16, 84 - bh, 10, 2, "screen_hi" if i % 2 == 0 else "leaf_hi")
    hline(c, 76, 196, 85, "metal_lo"); rect(c, 76, 32, 40, 4, "frame"); rect(c, 76, 39, 26, 2, "metal_lo")
    _spotlight(c, 30, 20, 60, 110); _spotlight(c, 240, 210, 250, 110)
    _planks(c, 110, 134); rect(c, 0, 134, SCENE_W, 10, "wood_lo"); hline(c, 0, SCENE_W - 1, 134, "wood")
    # pulpito
    rect(c, 26, 92, 30, 42, "wood_lo"); rect(c, 24, 88, 34, 6, "wood"); rect(c, 24, 88, 34, 1, "wood_hi"); rect(c, 30, 98, 22, 30, "wood")
    rect(c, 36, 82, 3, 8, "metal_lo"); rect(c, 34, 78, 7, 5, "frame")
    # plateia de costas
    rect(c, 0, 144, SCENE_W, 24, "night_lo")
    for row, (y, off) in enumerate(((146, 0), (156, 12))):
        for x in range(off, SCENE_W, 24):
            rect(c, x + 2, y, 14, 12, "night_hi"); rect(c, x + 3, y - 2, 12, 5, ("wood_lo" if (x // 24 + row) % 3 else "frame"))
    return c


def scene_booth():
    c = canvas(SCENE_W, SCENE_H, "hall")
    rect(c, 0, 0, SCENE_W, 12, "hall_lo")
    # outros estandes ao fundo
    for x, col in ((6, "screen"), (60, "purple"), (196, "leaf"), (236, "gold")):
        rect(c, x, 24, 40, 34, col); rect(c, x, 24, 40, 3, "paper"); rect(c, x + 4, 30, 32, 20, "paper")
        rect(c, x + 8, 34, 24, 3, col); rect(c, x + 8, 40, 16, 3, col)
    rect(c, 0, 100, SCENE_W, 68, "hall_floor")
    for y in range(100, SCENE_H, 12):
        hline(c, 0, SCENE_W - 1, y, "hall_lo")
    # nosso estande: painel laranja com o logo (barras) e baloes
    rect(c, 96, 18, 78, 90, "wood"); rect(c, 96, 18, 78, 4, "wood_hi"); rect(c, 170, 22, 4, 86, "wood_lo")
    rect(c, 104, 28, 62, 44, "night"); rect(c, 106, 30, 58, 40, "night_hi")
    for i, bh in enumerate((10, 16, 22, 30)):
        rect(c, 114 + i * 12, 64 - bh, 8, bh, "leaf" if i % 2 else "screen")
        rect(c, 114 + i * 12, 64 - bh, 8, 2, "leaf_hi" if i % 2 else "screen_hi")
    for i in range(4):
        put(c, 112 + i * 12, 66 - (10, 16, 22, 30)[i] - 2 - i, "gold_hi")
    rect(c, 104, 76, 62, 24, "paper"); rect(c, 110, 82, 50, 3, "wood_lo"); rect(c, 110, 88, 36, 3, "wood_lo"); rect(c, 110, 94, 44, 2, "wood_lo")
    for x, y, col in ((82, 26, "red"), (90, 36, "screen"), (186, 30, "gold"), (194, 42, "leaf")):
        rect(c, x - 5, y - 6, 10, 12, col); rect(c, x - 4, y - 7, 8, 1, col); rect(c, x - 4, y + 6, 8, 1, col)
        put(c, x - 3, y - 4, "paper"); vline(c, x, y + 7, y + 30, "metal_lo")
    return c


def scene_meetup():
    c = canvas(SCENE_W, SCENE_H, "wall")
    hline(c, 0, SCENE_W - 1, 0, "o"); rect(c, 0, 1, SCENE_W, 4, "wall_hi"); rect(c, 0, 58, SCENE_W, 6, "wall_lo")
    rect(c, 0, 64, SCENE_W, 104, "floor")
    for x in range(0, SCENE_W, 32):
        vline(c, x, 64, SCENE_H - 1, "floor_line")
    for y in range(64, SCENE_H, 32):
        hline(c, 0, SCENE_W - 1, y, "floor_line")
    # varal de luzes
    for x in range(0, SCENE_W, 4):
        put(c, x, 10 + int(3 * abs(((x % 60) / 30) - 1)), "metal_lo")
    for x in range(6, SCENE_W, 12):
        rect(c, x, 12 + int(3 * abs(((x % 60) / 30) - 1)), 3, 4, ("gold_hi", "red_hi", "screen_hi", "leaf_hi")[(x // 12) % 4])
    # faixa
    rect(c, 82, 24, 106, 18, "paper"); rect(c, 82, 24, 106, 2, "red"); rect(c, 82, 40, 106, 2, "red")
    rect(c, 90, 30, 30, 4, "night"); rect(c, 126, 30, 20, 4, "night"); rect(c, 152, 30, 28, 4, "night")
    # mesa de lanches e baloes
    rect(c, 178, 80, 82, 10, "wood_hi"); rect(c, 178, 90, 82, 6, "wood"); rect(c, 180, 96, 6, 22, "wood_lo"); rect(c, 252, 96, 6, 22, "wood_lo")
    rect(c, 184, 72, 18, 8, "wood_lo"); rect(c, 184, 72, 18, 2, "wood"); rect(c, 206, 74, 14, 6, "paper"); rect(c, 224, 70, 8, 10, "mug"); rect(c, 236, 72, 8, 8, "red")
    for x, y, col in ((14, 30, "red"), (24, 40, "gold"), (250, 34, "screen")):
        rect(c, x - 5, y - 6, 10, 12, col); put(c, x - 3, y - 4, "paper"); vline(c, x, y + 6, y + 26, "metal_lo")
    return c


def scene_studio():
    c = canvas(SCENE_W, SCENE_H, "foam")
    for y in range(0, 110, 14):
        for x in range(0, SCENE_W, 14):
            rect(c, x + 1, y + 1, 12, 12, "foam_hi"); rect(c, x + 4, y + 4, 6, 6, "foam")
    rect(c, 0, 110, SCENE_W, 58, "night_lo")
    # letreiro ON AIR
    rect(c, 96, 14, 78, 22, "onair_lo"); rect(c, 98, 16, 74, 18, "night_lo")
    glyphs = {"O": ["111", "101", "101", "101", "111"], "N": ["101", "111", "111", "101", "101"],
              "A": ["111", "101", "111", "101", "101"], "I": ["111", "010", "010", "010", "111"],
              "R": ["111", "101", "111", "110", "101"]}
    x = 104
    for ch in "ON AIR":
        if ch == " ":
            x += 6; continue
        for gy, row in enumerate(glyphs[ch]):
            for gx, bit in enumerate(row):
                if bit == "1":
                    rect(c, x + gx * 3, 19 + gy * 3, 3, 3, "onair")
        x += 12
    # monitores nas laterais (a mesa e adereco de primeiro plano)
    rect(c, 22, 60, 26, 18, "frame"); rect(c, 24, 62, 22, 12, "screen"); rect(c, 26, 64, 8, 2, "screen_hi"); rect(c, 30, 78, 10, 3, "metal_lo")
    rect(c, 222, 60, 26, 18, "frame"); rect(c, 224, 62, 22, 12, "leaf"); rect(c, 226, 64, 6, 2, "leaf_hi"); rect(c, 230, 78, 10, 3, "metal_lo")
    return c


def scene_boardroom():
    c = canvas(SCENE_W, SCENE_H, "hall_lo")
    rect(c, 0, 0, SCENE_W, 8, "hall")
    # janela panoramica com skyline
    rect(c, 20, 12, 230, 80, "metal"); rect(c, 24, 16, 222, 72, "sky"); rect(c, 24, 16, 222, 20, "sky_hi")
    for i, (x, w, h) in enumerate(((28, 18, 40), (50, 12, 56), (66, 24, 30), (94, 16, 62), (114, 20, 44), (138, 14, 70), (156, 26, 36), (186, 18, 58), (208, 14, 48), (226, 18, 34))):
        rect(c, x, 88 - h, w, h, "city")
        for wy in range(90 - h, 86, 6):
            for wx in range(x + 2, x + w - 2, 5):
                if (wx + wy + i) % 3:
                    rect(c, wx, wy, 2, 2, "city_win")
    rect(c, 133, 16, 4, 72, "metal"); rect(c, 24, 50, 222, 3, "metal")
    rect(c, 0, 100, SCENE_W, 68, "night_hi")
    for y in range(100, SCENE_H, 10):
        hline(c, 0, SCENE_W - 1, y, "night")
    rect(c, 246, 40, 16, 40, "leaf"); put(c, 250, 44, "leaf_hi"); rect(c, 248, 80, 12, 14, "pot")
    return c


def scene_press():
    c = canvas(SCENE_W, SCENE_H, "paper")
    for y in range(6, 110, 26):
        for x in range((y // 26) % 2 * 20, SCENE_W, 40):
            for i, bh in enumerate((3, 5, 7)):
                rect(c, x + 4 + i * 4, y + 10 - bh, 3, bh, "hall_lo")
    rect(c, 0, 110, SCENE_W, 58, "night_hi"); rect(c, 0, 110, SCENE_W, 3, "night")
    for x, y in ((30, 30), (230, 22), (60, 80), (200, 70)):
        for dx, dy in ((0, 0), (-3, 0), (3, 0), (0, -3), (0, 3), (-2, -2), (2, 2), (-2, 2), (2, -2), (-5, 0), (5, 0), (0, -5), (0, 5)):
            put(c, x + dx, y + dy, "flash")
        rect(c, x - 1, y - 1, 3, 3, "mug")
    return c


# adereços de primeiro plano (na frente das pessoas)
def prop_trophy():
    c = canvas(16, 26)
    rect(c, 3, 0, 10, 10, "gold"); rect(c, 4, 0, 4, 1, "gold_hi"); rect(c, 11, 1, 2, 9, "gold_lo")
    rect(c, 0, 1, 3, 6, "gold"); rect(c, 13, 1, 3, 6, "gold")
    rect(c, 5, 10, 6, 2, "gold"); rect(c, 7, 12, 2, 6, "gold_lo"); rect(c, 3, 18, 10, 3, "gold"); rect(c, 3, 18, 10, 1, "gold_hi")
    rect(c, 2, 21, 12, 4, "wood_lo")
    outline(c)
    return c


def prop_mic_stand():
    c = canvas(14, 48)
    rect(c, 4, 0, 6, 10, "frame"); rect(c, 5, 1, 4, 2, "metal_lo"); rect(c, 5, 5, 4, 3, "metal_lo")
    rect(c, 6, 10, 2, 32, "metal"); rect(c, 7, 10, 1, 32, "metal_lo")
    rect(c, 1, 42, 12, 4, "metal_lo"); rect(c, 1, 42, 12, 1, "metal")
    outline(c)
    return c


def prop_lectern():
    c = canvas(40, 56)
    rect(c, 2, 0, 36, 8, "wood"); rect(c, 2, 0, 36, 2, "wood_hi"); rect(c, 6, 8, 28, 46, "wood"); rect(c, 30, 8, 4, 46, "wood_lo")
    rect(c, 12, 16, 16, 12, "night"); rect(c, 14, 18, 12, 8, "night_hi")
    for i, bh in enumerate((2, 4, 6)):
        rect(c, 15 + i * 3, 25 - bh, 2, bh, "leaf_hi")
    rect(c, 8, 50, 24, 4, "wood_lo")
    outline(c)
    return c


def prop_table_long():
    c = canvas(200, 40)
    rect(c, 2, 2, 196, 10, "wood_hi"); rect(c, 2, 2, 196, 1, "wood"); rect(c, 2, 12, 196, 8, "wood"); hline(c, 2, 197, 19, "wood_lo")
    for x in (20, 70, 120, 170):
        rect(c, x, 4, 12, 5, "paper"); hline(c, x + 1, x + 10, 6, "metal_lo")
    rect(c, 90, 0, 20, 5, "frame"); rect(c, 91, 1, 18, 3, "screen"); rect(c, 88, 5, 24, 2, "metal")
    rect(c, 150, 4, 6, 5, "mug"); put(c, 156, 6, "mug_lo")
    rect(c, 8, 20, 8, 18, "wood_lo"); rect(c, 184, 20, 8, 18, "wood_lo")
    outline(c)
    return c


def prop_counter():
    c = canvas(150, 44)
    rect(c, 0, 0, 150, 8, "wood_hi"); rect(c, 0, 0, 150, 1, "wood"); rect(c, 0, 8, 150, 34, "wood"); rect(c, 0, 40, 150, 2, "wood_lo")
    rect(c, 40, 12, 70, 24, "night"); rect(c, 42, 14, 66, 20, "night_hi")
    for i, bh in enumerate((6, 10, 14, 18)):
        rect(c, 56 + i * 10, 32 - bh, 6, bh, "leaf" if i % 2 else "screen")
    rect(c, 8, 2, 16, 5, "paper"); rect(c, 120, 1, 14, 6, "paper"); rect(c, 122, 3, 10, 2, "red")
    outline(c)
    return c


def export_scenes(root):
    out = os.path.join(root, "assets", "art", "scenes")
    for name, fn in (("stage", scene_stage), ("auditorium", scene_auditorium), ("booth", scene_booth),
                     ("meetup", scene_meetup), ("studio", scene_studio), ("boardroom", scene_boardroom),
                     ("press", scene_press)):
        write_png(os.path.join(out, f"{name}.png"), fn())
    for name, fn in (("trophy", prop_trophy), ("mic_stand", prop_mic_stand), ("lectern", prop_lectern),
                     ("table_long", prop_table_long), ("counter", prop_counter)):
        write_png(os.path.join(out, f"{name}.png"), fn())


def scenes_sheet(path, scale=2):
    _register_cast()
    c = canvas(SCENE_W * 2 + 12, SCENE_H * 4 + 30, "night_lo")
    scenes = [scene_stage(), scene_auditorium(), scene_booth(), scene_meetup(), scene_studio(), scene_boardroom(), scene_press()]
    for i, sc in enumerate(scenes):
        x = 4 + (i % 2) * (SCENE_W + 4); y = 4 + (i // 2) * (SCENE_H + 6)
        blit(c, sc, x, y)
    x = 4 + SCENE_W + 4; y = 4 + 3 * (SCENE_H + 6)
    for pr in (prop_trophy(), prop_mic_stand(), prop_lectern(), prop_counter()):
        blit(c, pr, x, y); x += len(pr[0]) + 6
    write_png(path, c, scale)


# --- Tela inicial: fundo da cidade (270x480, exibido em 2x) e logo ---------------------
import ast as _ast
import re as _re

PAL.update({
    "sky0": hx("#5fb5ee"), "sky1": hx("#79c4f2"), "sky2": hx("#95d2f6"), "sky3": hx("#b6e1fa"), "sky4": hx("#d6eefc"),
    "cloud": hx("#ffffff"), "cloud_lo": hx("#dcecf7"),
    "far": hx("#9dbfda"), "far_lo": hx("#86a9c6"), "far_win": hx("#c5dbeb"),
    "mid_teal": hx("#3f6b7a"), "mid_teal_hi": hx("#5a8b9c"), "mid_beige": hx("#d9c4a0"), "mid_beige_lo": hx("#b9a27e"),
    "mid_brick": hx("#b8624a"), "mid_brick_lo": hx("#8e4634"), "mid_blue": hx("#4b7fb5"), "mid_blue_hi": hx("#7fb0dc"),
    "mid_gray": hx("#8c96a3"), "mid_gray_lo": hx("#6a737e"),
    "win_lit": hx("#ffe9a3"), "win_dark": hx("#2d3a4d"), "win_glass": hx("#a9d8f0"),
    "side": hx("#c9ccd2"), "side_lo": hx("#a8acb4"), "road": hx("#4a4f5a"), "road_lo": hx("#3a3e47"), "lane": hx("#e8d36a"),
    "tree": hx("#4f9a4a"), "tree_hi": hx("#7dc466"), "tree_lo": hx("#2f6b33"), "trunk": hx("#7a4b2a"),
    "car_y": hx("#f2c53d"), "car_b": hx("#3b7dd8"), "car_r": hx("#d94a3d"), "car_w": hx("#f4f4f6"), "tire": hx("#1f2633"),
    "awning_r": hx("#d94a3d"), "awning_w": hx("#f7f2e8"), "sign_blue": hx("#2c4f8a"), "sign_green": hx("#3d7a4e"), "sign_red": hx("#c43b3b"),
    "logo_y": hx("#f6c02e"), "logo_y_hi": hx("#ffe27a"), "logo_y_lo": hx("#c98d12"),
    "logo_w": hx("#ffffff"), "logo_w_lo": hx("#c9d6e6"), "logo_b": hx("#2c5fb0"), "logo_b_hi": hx("#5c8fe0"),
    "bar1": hx("#4b8fd8"), "bar2": hx("#3cb371"), "bar3": hx("#f2a851"), "bar4": hx("#e05d5d"), "arrow": hx("#3cb371"),
})

TITLE_W, TITLE_H = 270, 480


def _glyphs():
    src = open(os.path.join(ROOT, "tools", "gen_font.py")).read()
    m = _re.search(r"^BASE = (\{.*?^\})", src, _re.S | _re.M)
    return _ast.literal_eval(m.group(1))


def draw_text(c, text, x, y, scale, col, glyphs, spacing=1, hi=None, lo=None, shadow=None):
    """Escreve com a fonte 5x7 do jogo ampliada `scale` vezes. hi/lo pintam brilho no topo e sombra embaixo."""
    for ch in text:
        g = glyphs.get(ch, glyphs.get(ch.upper()))
        if ch == " " or g is None:
            x += (3 if ch == " " else 5) * scale + spacing * scale
            continue
        rows = len(g)
        for gy, row in enumerate(g):
            for gx, bit in enumerate(row):
                if bit != "#":
                    continue
                if shadow:
                    rect(c, x + gx * scale + scale // 2, y + gy * scale + scale // 2, scale, scale, shadow)
                colr = col
                if hi and gy == 0:
                    colr = hi
                elif lo and gy >= rows - 2:
                    colr = lo
                rect(c, x + gx * scale, y + gy * scale, scale, scale, colr)
        x += 5 * scale + spacing * scale
    return x


def _building(c, x, y, w, h, col, col_lo, win, rows_gap=9, cols_gap=8, sign=None, glyphs=None, sign_col="sign_blue"):
    rect(c, x, y, w, h, col)
    rect(c, x + w - 3, y, 3, h, col_lo)
    rect(c, x, y, w, 2, col_lo)
    for wy in range(y + 6, y + h - 6, rows_gap):
        for wx in range(x + 4, x + w - 6, cols_gap):
            rect(c, wx, wy, 4, 5, win)
            put(c, wx, wy, "win_glass")
    if sign and glyphs:
        sw = len(sign) * 6 * 1 + 4
        sx = x + (w - sw) // 2
        rect(c, sx, y + 12, sw, 11, sign_col)
        rect(c, sx, y + 12, sw, 1, "cloud")
        draw_text(c, sign, sx + 2, y + 14, 1, "cloud", glyphs, spacing=1)


def _tree(c, x, base_y, size=10):
    rect(c, x + size // 2 - 1, base_y - 6, 3, 6, "trunk")
    for i, (dx, dy, r) in enumerate(((0, -14, size), (-4, -10, size - 2), (4, -9, size - 3), (0, -20, size - 4))):
        rect(c, x + dx, base_y + dy - r // 2, r, r, "tree")
        put(c, x + dx + 1, base_y + dy - r // 2 + 1, "tree_hi")
        put(c, x + dx + 2, base_y + dy - r // 2 + 1, "tree_hi")
    rect(c, x + 2, base_y - 8, size - 2, 2, "tree_lo")


def _car(c, x, y, col, flip=False):
    rect(c, x, y + 4, 22, 7, col); rect(c, x + 4, y, 13, 5, col); rect(c, x + 5, y + 1, 5, 3, "win_glass"); rect(c, x + 11, y + 1, 5, 3, "win_glass")
    rect(c, x, y + 4, 22, 1, "cloud"); rect(c, x + 3, y + 10, 4, 3, "tire"); rect(c, x + 15, y + 10, 4, 3, "tire")
    put(c, x if flip else x + 21, y + 6, "win_lit")


def _cloud(c, x, y, w):
    rect(c, x, y + 3, w, 5, "cloud"); rect(c, x + 3, y, w - 8, 4, "cloud"); rect(c, x + w // 3, y - 2, w // 3, 3, "cloud")
    rect(c, x, y + 7, w, 1, "cloud_lo")


def title_background():
    g = _glyphs()
    c = canvas(TITLE_W, TITLE_H, "sky1")
    for i, col in enumerate(("sky0", "sky1", "sky2", "sky3", "sky4")):
        rect(c, 0, i * 52, TITLE_W, 52, col)
    for x, y, w in ((10, 26, 40), (120, 14, 52), (215, 40, 44), (60, 70, 34), (170, 90, 30), (230, 120, 36)):
        _cloud(c, x, y, w)
    # skyline distante
    for x, w, h in ((0, 22, 90), (18, 14, 130), (34, 26, 70), (62, 18, 110), (84, 30, 60), (118, 16, 140), (138, 24, 95),
                    (166, 20, 120), (190, 28, 75), (222, 18, 105), (244, 26, 85), (262, 12, 60)):
        rect(c, x, 250 - h, w, h + 10, "far"); rect(c, x + w - 2, 250 - h, 2, h + 10, "far_lo")
        for wy in range(254 - h, 250, 6):
            for wx in range(x + 2, x + w - 3, 5):
                rect(c, wx, wy, 2, 3, "far_win")
    # prédios do meio (com letreiros)
    _building(c, 4, 190, 58, 130, "mid_gray", "mid_gray_lo", "win_dark", sign="MARKETING", glyphs=g, sign_col="sign_blue")
    _building(c, 66, 214, 44, 106, "mid_beige", "mid_beige_lo", "win_dark", sign="IDEAS", glyphs=g, sign_col="sign_blue")
    _building(c, 114, 200, 52, 120, "mid_brick", "mid_brick_lo", "win_lit", sign="BRANDS", glyphs=g, sign_col="sign_green")
    _building(c, 170, 224, 40, 96, "mid_beige", "mid_beige_lo", "win_dark", sign="SEO", glyphs=g, sign_col="sign_red")
    _building(c, 214, 180, 56, 140, "mid_blue", "mid_blue_hi", "win_glass", sign="DIGITAL", glyphs=g, sign_col="sign_blue")
    # calcada, rua
    rect(c, 0, 400, TITLE_W, 22, "side"); rect(c, 0, 400, TITLE_W, 2, "cloud"); rect(c, 0, 420, TITLE_W, 2, "side_lo")
    rect(c, 0, 422, TITLE_W, 58, "road"); rect(c, 0, 422, TITLE_W, 3, "road_lo")
    for x in range(4, TITLE_W, 24):
        rect(c, x, 450, 12, 2, "lane")
    # agência (esquerda) e cafeteria (direita) em primeiro plano
    rect(c, 0, 300, 96, 100, "mid_teal"); rect(c, 92, 300, 4, 100, "mid_teal_hi"); rect(c, 0, 300, 96, 3, "mid_teal_hi")
    for fy in (312, 340, 368):
        for fx in range(6, 88, 22):
            rect(c, fx, fy, 16, 20, "win_glass"); rect(c, fx, fy, 16, 4, "cloud")
            rect(c, fx + 2, fy + 14, 12, 6, "wood")                       # mesa
            person = (("pot_hi", "car_b"), ("hill_lo", "car_r"), ("pot", "leaf"))[(fx // 22 + fy // 28) % 3]
            rect(c, fx + 6, fy + 5, 4, 4, person[0]); rect(c, fx + 5, fy + 9, 6, 5, person[1])   # cabeça e camisa
            rect(c, fx + 6, fy + 5, 4, 2, "wood_lo")                      # cabelo
    rect(c, 8, 384, 80, 12, "sign_blue"); draw_text(c, "AGENCY", 14, 386, 1, "cloud", g, spacing=2)
    rect(c, 178, 330, 92, 70, "mid_beige"); rect(c, 266, 330, 4, 70, "mid_beige_lo")
    for i in range(0, 92, 8):
        rect(c, 178 + i, 344, 8, 10, "awning_r" if (i // 8) % 2 == 0 else "awning_w")
    rect(c, 178, 354, 92, 2, "mid_beige_lo")
    rect(c, 186, 332, 76, 10, "wood_lo"); draw_text(c, "COFFEE", 200, 334, 1, "cloud", g, spacing=2)
    rect(c, 186, 360, 30, 34, "win_lit"); rect(c, 224, 360, 30, 34, "win_lit"); rect(c, 186, 360, 30, 2, "cloud"); rect(c, 224, 360, 30, 2, "cloud")
    rect(c, 236, 372, 8, 22, "wood"); put(c, 242, 384, "metal_hi")
    rect(c, 190, 370, 20, 6, "wood"); rect(c, 192, 366, 6, 4, "mug"); rect(c, 200, 366, 6, 4, "mug")
    # árvores, postes, ponto de ônibus
    for x in (104, 150, 258):
        _tree(c, x, 400, 12)
    for x in (130, 236):
        rect(c, x, 372, 2, 28, "metal_lo"); rect(c, x - 2, 370, 6, 3, "metal_hi"); rect(c, x - 1, 368, 4, 2, "win_lit")
    rect(c, 150, 380, 34, 3, "metal"); rect(c, 150, 383, 2, 17, "metal_lo"); rect(c, 182, 383, 2, 17, "metal_lo"); rect(c, 154, 384, 26, 8, "glass")
    # carros
    _car(c, 30, 432, "car_y"); _car(c, 120, 452, "car_b", True); _car(c, 210, 434, "car_r"); _car(c, 236, 460, "car_w", True)
    return c


def title_logo():
    """'A GROWTH STORY' em blocos: A e STORY em branco com sombra azul, GROWTH em amarelo com contorno."""
    g = _glyphs()
    c = canvas(240, 118)
    # 'A' pequeno
    draw_text(c, "A", 104, 4, 4, "logo_w", g, hi="logo_w", lo="logo_w_lo", shadow="logo_b")
    # GROWTH
    x = 8
    for ch in "GROWTH":
        # contorno grosso: escreve a letra em azul deslocada nas 8 direcoes e depois em amarelo
        for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2), (-2, -2), (2, 2), (-2, 2), (2, -2)):
            draw_text(c, ch, x + dx, 40 + dy, 6, "logo_b", g)
        draw_text(c, ch, x, 43, 6, "logo_y_lo", g)
        draw_text(c, ch, x, 40, 6, "logo_y", g, hi="logo_y_hi", lo="logo_y_lo")
        x += 6 * 6 + 3
    # grafico de barras entre o 'O' e o 'W'? — vai a direita, sobre o H
    for i, (bx, bh, col) in enumerate(((186, 10, "bar1"), (196, 16, "bar2"), (206, 22, "bar3"), (216, 30, "bar4"))):
        rect(c, bx, 36 - bh, 8, bh, col); rect(c, bx, 36 - bh, 8, 2, "cloud")
    for i in range(6):
        put(c, 222 + i, 4 + (5 - i), "arrow"); put(c, 222 + i, 5 + (5 - i), "arrow")
    rect(c, 226, 2, 2, 6, "arrow"); rect(c, 222, 2, 6, 2, "arrow")
    # STORY
    x = 44
    for ch in "STORY":
        for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2), (-2, -2), (2, 2), (-2, 2), (2, -2)):
            draw_text(c, ch, x + dx, 88 + dy, 4, "logo_b", g)
        draw_text(c, ch, x, 90, 4, "logo_w_lo", g)
        draw_text(c, ch, x, 88, 4, "logo_w", g, lo="logo_w_lo")
        x += 4 * 6 + 4
    return c


def export_title(root):
    out = os.path.join(root, "assets", "art", "title")
    write_png(os.path.join(out, "background.png"), title_background())
    write_png(os.path.join(out, "logo.png"), title_logo())


def title_sheet(path, scale=2):
    c = canvas(TITLE_W, TITLE_H)
    blit(c, title_background(), 0, 0)
    blit(c, title_logo(), 15, 40)
    write_png(path, c, scale)


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
    if "--furniture" in sys.argv:
        out = sys.argv[sys.argv.index("--furniture") + 1]
        furniture_sheet(out)
    if "--scenes" in sys.argv:
        out = sys.argv[sys.argv.index("--scenes") + 1]
        scenes_sheet(out)
    if "--title" in sys.argv:
        out = sys.argv[sys.argv.index("--title") + 1]
        title_sheet(out)
    if "--export" in sys.argv:
        export_all(ROOT)
