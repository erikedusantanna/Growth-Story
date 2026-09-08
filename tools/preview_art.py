#!/usr/bin/env python3
"""Monta uma cena de prévia (PNG ampliado) a partir da arte gerada, para conferir sem abrir o Godot.
Uso: python3 tools/preview_art.py saida.png
"""
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(__file__))
import gen_art as ga  # noqa: E402


def rgba(ch, tint=None):
    r, g, b, a = ga.P[ch]
    if tint and ch == "W":
        r, g, b = tint
    return (r, g, b, a)


def blit(img, layer, x0, y0, tint=None):
    for y, row in enumerate(layer):
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            px, py = x0 + x, y0 + y
            if 0 <= py < len(img) and 0 <= px < len(img[0]):
                img[py][px] = rgba(ch, tint)


def frame_of(sheet_fn, idx):
    return sheet_fn()[idx] if callable(sheet_fn) else sheet_fn[idx]


def character(img, x, y, frame, hair_style, skin, hair, shirt):
    body = ga.body_frame(["idle", "walk_a", "walk_b", "sit"][frame])
    hf = ga.hair_frame(hair_style, None)
    merged = [row[:] for row in body]
    for yy in range(32):
        for xx in range(24):
            if hf[yy][xx] != ".":
                merged[yy][xx] = "H"
    ol = ga.outline([merged])[0]
    blit(img, ol, x, y)
    blit(img, ga.split_layer(body, "S"), x, y, skin)
    blit(img, ga.split_layer(body, "nNh", as_white=False), x, y)
    blit(img, ga.split_layer(body, "T"), x, y, shirt)
    blit(img, ga.split_layer(hf, "H"), x, y, hair)
    blit(img, ga.split_layer(body, "eu", as_white=False), x, y)


def save(img, path, scale):
    h, w = len(img), len(img[0])
    raw = bytearray()
    for row in img:
        line = bytearray([0])
        for px in row:
            line.extend(bytes(px) * scale)
        for _ in range(scale):
            raw.extend(line)

    def chunk(tag, data):
        body = struct.pack(">I", len(data)) + tag + data
        return body + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w * scale, h * scale, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)


def main(out):
    W, H = 176, 128
    img = [[(0, 0, 0, 0)] * W for _ in range(H)]
    wall, floor = ga.wall_tile(), ga.floor_tile()
    for x in range(0, W, 16):
        blit(img, wall, x, 0)
        for y in range(32, H, 16):
            blit(img, floor, x, y)
    blit(img, ga.window(), 8, 6)
    blit(img, ga.whiteboard(), 40, 6)
    blit(img, ga.door(), 150, 2)
    blit(img, ga.shelf(), 120, 4)
    # mesas com cadeira e pessoa sentada
    for i, (dx, skin, hair, shirt, style) in enumerate((
            (8, (238, 195, 154), (89, 56, 34), (228, 87, 46), 0),
            (56, (198, 150, 110), (30, 24, 28), (59, 111, 216), 1),
            (104, (120, 80, 50), (240, 200, 70), (60, 179, 113), 2))):
        dy = 84
        blit(img, ga.chair(), dx + 8, dy - 28 - 13)
        character(img, dx + 4, dy - 12 - 32, 3, style, skin, hair, shirt)
        blit(img, ga.desk(), dx, dy - 28)
    # pessoa andando, sofá, planta, café
    character(img, 20, 88, 1, 3, (238, 195, 154), (140, 70, 40), (142, 108, 224))
    blit(img, ga.sofa(), 72, 100)
    blit(img, ga.plant(), 150, 92)
    blit(img, ga.coffee_machine(), 130, 60)
    blit(img, ga.water_cooler(), 116, 62)
    # ícones
    for i, name in enumerate(("attr_creativity", "attr_strategy", "attr_performance", "attr_communication",
                              "attr_management", "attr_technology", "coin", "rep")):
        blit(img, ga.icon(ga.ICONS[name]), 2 + i * 12, 116)
    save(img, out, 4)
    print("prévia em", out)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "preview.png")
