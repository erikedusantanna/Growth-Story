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
    "eye": hx("#1f2633"), "eye_hi": hx("#ffffff"), "mouth": hx("#b8605c"), "blush": hx("#f2b3a2"),
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
# Cores variaveis: skin, hair, shirt, pants sao nomes registrados por color_set().

def _head_front(c, skin, hair, style, cx=16, top=3):
    # cabeca 20x18 (x 6..25, y top..top+17)
    rect(c, cx - 10, top + 2, 20, 16, skin)
    rect(c, cx - 9, top + 1, 18, 1, skin)
    rect(c, cx + 6, top + 4, 4, 14, skin + "_lo")        # sombra lado direito
    rect(c, cx - 10, top + 15, 20, 3, skin + "_lo")       # queixo
    rect(c, cx - 9, top + 17, 18, 1, skin + "_lo")
    # olhos grandes
    for ex in (cx - 6, cx + 3):
        rect(c, ex, top + 8, 3, 5, "eye")
        put(c, ex, top + 8, "eye_hi")
        put(c, ex + 1, top + 9, "eye_hi")
    rect(c, cx - 1, top + 14, 2, 1, "mouth")
    put(c, cx - 8, top + 13, "blush")
    put(c, cx + 7, top + 13, "blush")
    # cabelo
    rect(c, cx - 10, top, 20, 5, hair)
    rect(c, cx - 11, top + 2, 22, 4, hair)
    rect(c, cx - 9, top - 1, 18, 1, hair)
    rect(c, cx - 8, top + 1, 8, 1, hair + "_hi")
    rect(c, cx - 9, top + 2, 5, 1, hair + "_hi")
    # franja recortada
    for x, h in ((cx - 10, 3), (cx - 7, 2), (cx - 3, 4), (cx + 1, 2), (cx + 4, 3), (cx + 7, 2)):
        rect(c, x, top + 5, 3, h, hair)
    rect(c, cx + 8, top + 5, 3, 6, hair + "_lo")
    rect(c, cx - 11, top + 5, 2, 5, hair)
    if style == "long":
        rect(c, cx - 12, top + 6, 3, 16, hair)
        rect(c, cx + 9, top + 6, 3, 16, hair + "_lo")
        rect(c, cx - 12, top + 20, 3, 5, hair + "_lo")
        rect(c, cx + 9, top + 20, 3, 5, hair + "_lo")
    if style == "bun":
        rect(c, cx - 4, top - 4, 8, 5, hair)
        rect(c, cx - 3, top - 5, 6, 1, hair)
        rect(c, cx - 3, top - 4, 3, 1, hair + "_hi")


def _body_front(c, skin, shirt, pants, cx=16, top=21, sitting=False):
    # tronco 14 de largura
    rect(c, cx - 7, top, 14, 13, shirt)
    rect(c, cx - 7, top, 14, 1, shirt + "_hi")
    rect(c, cx + 4, top + 1, 3, 12, shirt + "_lo")
    rect(c, cx - 1, top, 2, 2, skin)                      # pescoco
    # cracha com cordao
    vline(c, cx - 2, top + 1, top + 5, "lanyard")
    vline(c, cx + 1, top + 1, top + 5, "lanyard")
    rect(c, cx - 2, top + 6, 5, 4, "badge")
    rect(c, cx - 1, top + 7, 2, 1, "lanyard")
    rect(c, cx - 2, top + 9, 5, 1, "badge_lo")
    # bracos
    rect(c, cx - 9, top + 2, 2, 8, shirt)
    rect(c, cx + 7, top + 2, 2, 8, shirt + "_lo")
    rect(c, cx - 9, top + 10, 2, 3, skin)
    rect(c, cx + 7, top + 10, 2, 3, skin + "_lo")
    if sitting:
        rect(c, cx - 7, top + 13, 14, 4, pants)
        rect(c, cx - 7, top + 13, 14, 1, pants + "_hi")
        rect(c, cx - 7, top + 17, 5, 2, "shoe")
        rect(c, cx + 2, top + 17, 5, 2, "shoe")
        return
    # pernas e sapatos
    rect(c, cx - 6, top + 13, 5, 8, pants)
    rect(c, cx + 1, top + 13, 5, 8, pants)
    rect(c, cx - 6, top + 13, 5, 1, pants + "_hi")
    rect(c, cx + 4, top + 13, 2, 8, pants + "_lo")
    rect(c, cx - 6, top + 21, 5, 3, "shoe")
    rect(c, cx + 1, top + 21, 5, 3, "shoe")
    put(c, cx - 6, top + 21, "shoe_hi")
    put(c, cx + 1, top + 21, "shoe_hi")


def character_front(skin, hair, shirt, pants, style="short", sitting=False):
    c = canvas(32, 48)
    _head_front(c, skin, hair, style)
    _body_front(c, skin, shirt, pants, sitting=sitting)
    outline(c)
    return c


def character_back(skin, hair, shirt, pants, style="short"):
    c = canvas(32, 48)
    cx, top = 16, 3
    rect(c, cx - 10, top + 2, 20, 16, skin)
    rect(c, cx - 10, top + 15, 20, 3, skin + "_lo")
    # cabelo cobre a cabeca toda
    rect(c, cx - 11, top + 1, 22, 15, hair)
    rect(c, cx - 10, top, 20, 1, hair)
    rect(c, cx - 9, top - 1, 18, 1, hair)
    rect(c, cx - 8, top + 1, 7, 1, hair + "_hi")
    rect(c, cx + 6, top + 3, 5, 13, hair + "_lo")
    for x, h in ((cx - 11, 2), (cx - 7, 1), (cx - 2, 3), (cx + 3, 1), (cx + 7, 2)):
        rect(c, x, top + 16, 4, h, hair)
    if style == "long":
        rect(c, cx - 11, top + 10, 22, 16, hair)
        rect(c, cx + 6, top + 10, 5, 16, hair + "_lo")
        rect(c, cx - 10, top + 26, 20, 2, hair + "_lo")
    if style == "bun":
        rect(c, cx - 4, top - 4, 8, 5, hair)
        rect(c, cx - 3, top - 5, 6, 1, hair)
        rect(c, cx - 3, top - 4, 3, 1, hair + "_hi")
    # tronco (sem cracha), costas com costura
    t = 21
    rect(c, cx - 7, t, 14, 13, shirt)
    rect(c, cx - 7, t, 14, 1, shirt + "_hi")
    rect(c, cx + 4, t + 1, 3, 12, shirt + "_lo")
    vline(c, cx, t + 2, t + 11, shirt + "_lo")
    rect(c, cx - 9, t + 2, 2, 8, shirt)
    rect(c, cx + 7, t + 2, 2, 8, shirt + "_lo")
    rect(c, cx - 9, t + 10, 2, 3, skin)
    rect(c, cx + 7, t + 10, 2, 3, skin + "_lo")
    rect(c, cx - 6, t + 13, 5, 8, pants)
    rect(c, cx + 1, t + 13, 5, 8, pants)
    rect(c, cx + 4, t + 13, 2, 8, pants + "_lo")
    rect(c, cx - 6, t + 21, 5, 3, "shoe")
    rect(c, cx + 1, t + 21, 5, 3, "shoe")
    outline(c)
    return c


def character_side(skin, hair, shirt, pants, style="short"):
    """Olhando para a esquerda; a direita e o espelho."""
    c = canvas(32, 48)
    cx, top = 15, 3
    # cabeca 16 de largura (x 7..22)
    rect(c, cx - 8, top + 2, 16, 16, skin)
    rect(c, cx - 7, top + 1, 14, 1, skin)
    rect(c, cx + 3, top + 4, 5, 14, skin + "_lo")
    rect(c, cx - 8, top + 15, 16, 3, skin + "_lo")
    # um olho, nariz e boca de perfil
    rect(c, cx - 5, top + 8, 3, 5, "eye")
    put(c, cx - 5, top + 8, "eye_hi")
    put(c, cx - 4, top + 9, "eye_hi")
    put(c, cx - 9, top + 12, skin)
    rect(c, cx - 5, top + 14, 2, 1, "mouth")
    put(c, cx - 7, top + 13, "blush")
    # cabelo: cobre a nuca e o topo
    rect(c, cx - 8, top, 16, 5, hair)
    rect(c, cx - 9, top + 2, 18, 4, hair)
    rect(c, cx - 7, top - 1, 14, 1, hair)
    rect(c, cx - 6, top + 1, 6, 1, hair + "_hi")
    rect(c, cx + 1, top + 5, 8, 11, hair)
    rect(c, cx + 5, top + 5, 4, 11, hair + "_lo")
    for x, h in ((cx - 8, 3), (cx - 5, 2), (cx - 2, 3)):
        rect(c, x, top + 5, 3, h, hair)
    if style == "long":
        rect(c, cx + 2, top + 14, 7, 12, hair)
        rect(c, cx + 5, top + 14, 4, 12, hair + "_lo")
    if style == "bun":
        rect(c, cx + 2, top - 3, 7, 6, hair)
        rect(c, cx + 3, top - 4, 5, 1, hair)
        rect(c, cx + 3, top - 3, 3, 1, hair + "_hi")
    # tronco 10 de largura (x 10..19), um braco na frente
    t = 21
    rect(c, cx - 5, t, 11, 13, shirt)
    rect(c, cx - 5, t, 11, 1, shirt + "_hi")
    rect(c, cx + 3, t + 1, 3, 12, shirt + "_lo")
    rect(c, cx - 1, t, 2, 2, skin)
    vline(c, cx - 4, t + 1, t + 5, "lanyard")
    rect(c, cx - 5, t + 6, 3, 4, "badge")
    rect(c, cx - 5, t + 9, 3, 1, "badge_lo")
    rect(c, cx - 3, t + 3, 3, 8, shirt + "_lo")
    rect(c, cx - 3, t + 11, 3, 3, skin)
    # pernas juntas e sapato
    rect(c, cx - 4, t + 13, 9, 8, pants)
    rect(c, cx - 4, t + 13, 9, 1, pants + "_hi")
    rect(c, cx + 2, t + 14, 3, 7, pants + "_lo")
    rect(c, cx - 6, t + 21, 11, 3, "shoe")
    rect(c, cx - 6, t + 21, 3, 1, "shoe_hi")
    outline(c)
    return c


# --- Prova de estilo ---------------------------------------------------------------
def style_proof(path, scale=3):
    color_set("skin_a", "#f0c49c"); color_set("hair_a", "#5b3a22"); color_set("shirt_a", "#f4f4f6"); color_set("pants_a", "#2f3542")
    color_set("skin_b", "#e5b592"); color_set("hair_b", "#3a2416"); color_set("shirt_b", "#2d3340"); color_set("pants_b", "#1f2430")
    color_set("skin_c", "#8d5a3c"); color_set("hair_c", "#1e1a1a"); color_set("shirt_c", "#3f4756"); color_set("pants_c", "#c9b48f")
    color_set("skin_d", "#f3cdb0"); color_set("hair_d", "#d8702a"); color_set("shirt_d", "#f4f4f6"); color_set("pants_d", "#5c6b3a")

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

    # tapete da ilha (zona) desenhado sob a mobilia
    for y in range(2 * TILE + 4, 6 * TILE + 8):
        for x in range(TILE - 8, 5 * TILE + 8):
            scene[y][x] = "floor_worn"
    for y in range(2 * TILE + 4, 6 * TILE + 8):
        for x in range(6 * TILE + 12, 10 * TILE + 28):
            scene[y][x] = "floor_worn"

    sprites = []   # (bottom_y, x, canvas)
    dk, ch = desk(), chair()
    chars = [
        ("a", "short", "sit"), ("b", "long", "sit"), ("c", "short", "sit"), ("d", "bun", "sit"),
    ]
    islands = [(1, 3), (3, 3), (1, 5), (3, 5), (7, 3), (9, 3), (7, 5), (9, 5)]
    for i, (tx, ty) in enumerate(islands):
        bx, by = tx * TILE, (ty + 1) * TILE
        sprites.append((by - 26, bx + 2, ch))
        if i < 4:
            k, style, _ = chars[i]
            sprites.append((by - 22, bx + 2, character_front(f"skin_{k}", f"hair_{k}", f"shirt_{k}", f"pants_{k}", style, sitting=True)))
        sprites.append((by, bx, dk))
    # divisoria entre as ilhas
    part, cap = partition_tile(), partition_cap()
    px = 5 * TILE + 26
    for y in range(2 * TILE, 6 * TILE, 32):
        sprites.append((y + 32, px, part))
    sprites.append((2 * TILE + 4, px, cap))
    # personagens andando: frente, costas, esquerda e direita
    walkers = [
        ("a", "short", character_front, 7 * TILE + 4, 7 * TILE + 26),
        ("d", "bun", character_back, 11 * TILE + 8, 4 * TILE + 20),
        ("b", "long", character_side, 10 * TILE + 8, 7 * TILE + 20),
        ("c", "short", lambda *a: mirror(character_side(*a)), 3 * TILE + 8, 7 * TILE + 30),
    ]
    for k, style, fn, x, bottom in walkers:
        sprites.append((bottom, x, fn(f"skin_{k}", f"hair_{k}", f"shirt_{k}", f"pants_{k}", style)))
    pl = plant()
    for x, bottom in ((12 * TILE + 12, 3 * TILE + 8), (11 * TILE + 24, 8 * TILE - 4), (5 * TILE + 20, 8 * TILE - 2)):
        sprites.append((bottom, x, pl))

    for bottom, x, spr in sorted(sprites, key=lambda s: s[0]):
        blit_bottom(scene, spr, x, bottom)
    write_png(path, scene, scale)


def sheet(path, scale=3):
    """Ficha: personagem nas 4 direcoes + sentado, e as pecas soltas."""
    color_set("skin_a", "#f0c49c"); color_set("hair_a", "#5b3a22"); color_set("shirt_a", "#f4f4f6"); color_set("pants_a", "#2f3542")
    color_set("skin_d", "#f3cdb0"); color_set("hair_d", "#d8702a"); color_set("shirt_d", "#f4f4f6"); color_set("pants_d", "#5c6b3a")
    c = canvas(300, 130, "floor")
    args_a = ("skin_a", "hair_a", "shirt_a", "pants_a")
    args_d = ("skin_d", "hair_d", "shirt_d", "pants_d")
    x = 6
    for spr in (character_front(*args_a), character_back(*args_a), character_side(*args_a), mirror(character_side(*args_a)),
                character_front(*args_a, sitting=True)):
        blit(c, spr, x, 6); x += 36
    x = 6
    for spr in (character_front(*args_d, style="bun"), character_back(*args_d, style="bun"), character_side(*args_d, style="bun"),
                mirror(character_side(*args_d, style="bun"))):
        blit(c, spr, x, 62); x += 36
    blit(c, desk(), 190, 8)
    blit(c, chair(), 258, 12)
    blit(c, plant(), 200, 76)
    blit(c, partition_tile(), 240, 70)
    blit(c, partition_cap(), 240, 62)
    write_png(path, c, scale)


if __name__ == "__main__":
    if "--proof" in sys.argv:
        out = sys.argv[sys.argv.index("--proof") + 1]
        style_proof(out)
    if "--sheet" in sys.argv:
        out = sys.argv[sys.argv.index("--sheet") + 1]
        sheet(out)
