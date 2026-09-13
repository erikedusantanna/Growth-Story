#!/usr/bin/env python3
"""Gera o logo da tela inicial e os ícones do app a partir das artes de marca.

Ao contrário do resto da arte do jogo (desenhada por código em tools/gen_art.py), o logo e o
ícone vêm prontos, em assets/brand/. Este script só deriva as variações que o jogo e o Android
precisam, sempre a partir dessas fontes, para que dê para regerar tudo depois de trocar a arte:

    python3 tools/gen_brand.py

Saídas:
    assets/art/title/logo.png             logo da tela inicial (largura 512)
    icon.png                              ícone da janela / do editor (128x128)
    assets/icons/launcher_192.png         ícone legado do Android
    assets/icons/adaptive_foreground_432.png  ícone adaptativo: a arte, dentro da área segura
    assets/icons/adaptive_background_432.png  ícone adaptativo: o céu, sangrando até a borda

Sobre o ícone adaptativo: o Android recorta o canvas de 432 px com a máscara do aparelho
(círculo, quadrado arredondado…) e só garante os ~66% centrais. Por isso a arte entra reduzida
no primeiro plano, e o fundo é um degradê do céu dela — assim nada do título é cortado,
qualquer que seja a máscara.
"""

import os
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.exit("Este script precisa do Pillow: pip install Pillow")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRAND = os.path.join(ROOT, "assets", "brand")

LOGO_WIDTH = 512          # a tela tem 540 px de largura
ICON_CANVAS = 432         # canvas do ícone adaptativo do Android
ICON_ART = 306            # a arte dentro dele: cabe na área segura de qualquer máscara
ICON_CORNER_TRIM = 0.035  # corta a moldura arredondada da arte antes de reaproveitá-la


def load(name: str) -> Image.Image:
    path = os.path.join(BRAND, name)
    if not os.path.exists(path):
        sys.exit("arte de marca não encontrada: %s" % path)
    return Image.open(path).convert("RGBA")


def trim(im: Image.Image, threshold: int = 16) -> Image.Image:
    """Corta a margem transparente em volta da arte."""
    mask = im.getchannel("A").point(lambda v: 255 if v > threshold else 0)
    box = mask.getbbox()
    return im.crop(box) if box else im


def fit(im: Image.Image, size: int) -> Image.Image:
    """Redimensiona mantendo a proporção, cabendo num quadrado de `size`."""
    scale = size / max(im.size)
    return im.resize((max(int(im.width * scale), 1), max(int(im.height * scale), 1)), Image.LANCZOS)


def square(im: Image.Image, size: int) -> Image.Image:
    """Centraliza a arte num canvas quadrado transparente."""
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    art = fit(im, size)
    out.paste(art, ((size - art.width) // 2, (size - art.height) // 2), art)
    return out


def sky_gradient(source: Image.Image, size: int) -> Image.Image:
    """Degradê vertical com as cores do céu da própria arte, para o fundo do ícone adaptativo."""
    ref = source.convert("RGB").resize((1, 16), Image.LANCZOS)
    top = ref.getpixel((0, 1))
    bottom = ref.getpixel((0, 6))
    out = Image.new("RGBA", (size, size))
    for y in range(size):
        t = y / (size - 1)
        px = tuple(int(round(top[i] + (bottom[i] - top[i]) * t)) for i in range(3)) + (255,)
        for x in range(size):
            out.putpixel((x, y), px)
    return out


def build_logo() -> None:
    art = trim(load("logo_source.png"))
    scale = LOGO_WIDTH / art.width
    out = art.resize((LOGO_WIDTH, max(int(round(art.height * scale)), 1)), Image.LANCZOS)
    path = os.path.join(ROOT, "assets", "art", "title", "logo.png")
    out.save(path)
    print("logo da tela inicial: %s (%dx%d)" % (path, out.width, out.height))


def build_icons() -> None:
    source = trim(load("icon_source.png"))
    # tira a moldura arredondada: o Android (e o jogo) aplicam o próprio formato
    inset = int(round(min(source.size) * ICON_CORNER_TRIM))
    art = source.crop((inset, inset, source.width - inset, source.height - inset))

    jobs = [
        (os.path.join(ROOT, "icon.png"), 128),
        (os.path.join(ROOT, "assets", "icons", "launcher_192.png"), 192),
    ]
    for path, size in jobs:
        square(source, size).save(path)
        print("ícone: %s (%dx%d)" % (path, size, size))

    foreground = Image.new("RGBA", (ICON_CANVAS, ICON_CANVAS), (0, 0, 0, 0))
    inner = fit(art, ICON_ART)
    foreground.paste(inner, ((ICON_CANVAS - inner.width) // 2, (ICON_CANVAS - inner.height) // 2), inner)
    fg_path = os.path.join(ROOT, "assets", "icons", "adaptive_foreground_432.png")
    foreground.save(fg_path)
    print("ícone adaptativo (frente): %s (arte de %d px)" % (fg_path, ICON_ART))

    bg_path = os.path.join(ROOT, "assets", "icons", "adaptive_background_432.png")
    sky_gradient(art, ICON_CANVAS).save(bg_path)
    print("ícone adaptativo (fundo): %s" % bg_path)


if __name__ == "__main__":
    build_logo()
    build_icons()
