"""Gera data/offices.json e data/regions.json: 5 regiões do World Map, cada uma com 3 ou 4
níveis de escritório (mais mesas). Os layouts seguem as regras dos escritórios desenhados à mão
(ilhas de 2x2 mesas com tapete e divisória, ala de convivência à direita, segunda fileira de mesas
nos escritórios grandes). Posições em tiles de 32 px; a linha 0 é a parede.

    python3 tools/gen_layouts.py
"""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# capacidade -> (ilhas de cima com N mesas cada, mesas na fileira de baixo)
TEMPLATES = {
    4: ([4], 0), 6: ([4, 2], 0), 8: ([4, 4], 0), 10: ([4, 4, 2], 0), 12: ([4, 4, 4], 0),
    14: ([4, 4, 4], 2), 16: ([4, 4, 4], 4), 18: ([4, 4, 4], 6), 20: ([4, 4, 4, 4], 4),
    22: ([4, 4, 4, 4], 6), 25: ([4, 4, 4, 4, 4], 5), 28: ([4, 4, 4, 4, 4], 8),
}
TINTS = ["cool", "green", "purple", "warm", "cool", "green"]

REGIONS = [
    {"id": "bairro", "name": "Bairro Criativo", "tier": 1, "tier_name": "Locais",
     "desc": "Negócios locais e pequenas empresas. Onde tudo começa.",
     "move_cost": 0, "rep_required": 0, "rent": [0, 1500, 2000], "capacities": [4, 6, 8],
     "expansion_costs": [0, 3000, 6000],
     "level_names": ["Quarto improvisado", "Sala no bairro", "Estúdio no bairro"],
     "map_pos": [60, 560], "has_rival": False},
    {"id": "centro", "name": "Centro Regional", "tier": 2, "tier_name": "Regionais",
     "desc": "Empresas em crescimento com presença regional.",
     "move_cost": 40000, "rep_required": 15, "rent": [4000, 4600, 5200], "capacities": [8, 10, 12],
     "expansion_costs": [0, 12000, 18000],
     "level_names": ["Sala no centro", "Escritório no centro", "Andar no centro"],
     "map_pos": [120, 440], "has_rival": True},
    {"id": "capital", "name": "Capital", "tier": 3, "tier_name": "Nacionais",
     "desc": "Marcas conhecidas, atuação nacional.",
     "move_cost": 150000, "rep_required": 35, "rent": [10000, 11500, 13000, 14500], "capacities": [12, 14, 16, 18],
     "expansion_costs": [0, 30000, 45000, 60000],
     "level_names": ["Escritório na capital", "Andar na capital", "Sede na capital", "Torre na capital"],
     "map_pos": [150, 320], "has_rival": True},
    {"id": "distrito", "name": "Distrito das Marcas", "tier": 4, "tier_name": "Grandes marcas",
     "desc": "Grandes empresas, alto investimento.",
     "move_cost": 450000, "rep_required": 55, "rent": [25000, 28750, 32500], "capacities": [18, 20, 22],
     "expansion_costs": [0, 90000, 120000],
     "level_names": ["Andar no distrito", "Sede no distrito", "Torre no distrito"],
     "map_pos": [200, 200], "has_rival": True},
    {"id": "global", "name": "Hub Global", "tier": 5, "tier_name": "Globais",
     "desc": "Marcas globais e parcerias estratégicas. Projetos complexos.",
     "move_cost": 1200000, "rep_required": 75, "rent": [60000, 69000, 78000], "capacities": [22, 25, 28],
     "expansion_costs": [0, 200000, 260000],
     "level_names": ["Sede global", "Torre global", "Campus global"],
     "map_pos": [215, 80], "has_rival": False},
]


def layout(capacity, region_idx):
    islands, bottom = TEMPLATES[capacity]
    n = len(islands)
    lounge_w = 5 if n == 1 else (3 if n == 2 else 4)
    lx = 5 * n
    width = lx + lounge_w
    height = 7 if capacity <= 4 else (8 if capacity <= 10 else (9 if bottom == 0 else 10))
    desks, zones, dividers = [], [], []
    for i, count in enumerate(islands):
        x0 = 5 * i + 1 if n == 1 else 5 * i
        pts = [[x0, 3], [x0 + 2, 3], [x0, 5], [x0 + 2, 5]][:count]
        desks.extend(pts)
        zh = 4 if count == 4 else 2.2
        zones.append({"rect": [x0 - 0.3 if n > 1 else x0 - 0.8, 2, 4.6 if n > 1 else 5.4, zh], "tint": TINTS[i % len(TINTS)]})
        if i >= 1:
            dividers.append({"x": 5 * i - 0.6, "y0": 2, "y1": 6})
    if bottom:
        groups = [3] * (bottom // 3) + ([bottom % 3] if bottom % 3 else [])
        gx = 0
        for gi, g in enumerate(groups):
            for k in range(g):
                desks.append([gx + 2 * k, 8])
            zones.append({"rect": [gx - 0.2 if gx > 0 else 0, 6.2, 2 * g + 0.4, 3.8], "tint": TINTS[(gi + 3) % len(TINTS)]})
            if gi >= 1:
                dividers.append({"x": gx - 0.6, "y0": 6, "y1": 10})
            gx += 2 * g + 1
    # ala de convivência (coluna da direita)
    zones.append({"rect": [lx - 0.2, 2, lounge_w + 0.2, height - 2], "tint": "lounge"})
    if n >= 3:
        dividers.append({"x": lx - 0.6, "y0": 2, "y1": height - 3})
    props, spots, decor = [], [], []
    if lounge_w >= 4:
        props += [{"type": "coffee", "pos": [lx + 2, 4]}, {"type": "cooler", "pos": [lx + 3, 4]}]
        props.append({"type": "sofa", "pos": [lx + 1, height - 2]})
        if height >= 9:
            props.append({"type": "meeting_table", "pos": [lx, 6]})
        spots = [[lx + 2, 5], [lx + 1, height - 1]]
        decor = [[lx + 3, 6], [width - 1, height - 1]]
    elif lounge_w == 3:
        props += [{"type": "cooler", "pos": [lx + 1, 3]}, {"type": "coffee", "pos": [lx + 1, 5]}]
        spots = [[lx + 2, 5], [lx + 1, height - 1]]
        decor = [[lx + 2, 3], [lx, height - 1]]
    else:  # n == 1: canto do café como no quarto improvisado
        props += [{"type": "coffee", "pos": [width - 2, 4]}, {"type": "plant", "pos": [width - 1, height - 1]}]
        spots = [[width - 2, 5]]
        decor = [[width - 4, height - 1], [0, height - 1], [width - 4, 3], [3, height - 1]]
    if bottom == 0 and n >= 2:
        decor += [[0, height - 1], [3, height - 1]]
    elif bottom:
        decor += [[lx + 1, 3], [lx, height - 1]]
    props.append({"type": "plant", "pos": [width - 1, 2]}) if lounge_w >= 3 else None
    wall = [{"type": "window", "x": 1}]
    if width >= 13:
        wall.append({"type": "window", "x": 4})
    wall.append({"type": "whiteboard", "x": 7 if width >= 13 else 4})
    if width >= 14:
        wall.append({"type": "shelf", "x": 10})
    if width >= 20:
        wall.append({"type": "window", "x": 14})
    if width >= 26:
        wall.append({"type": "shelf", "x": 19})
    if width >= 29:
        wall.append({"type": "window", "x": 23})
    wall.append({"type": "door", "x": width - 2})
    wall_slots = [width - 5] if width >= 12 else [6]
    season_slot = [lx + 0.5, 2] if lounge_w >= 3 else [0, 2]
    out = {"width": width, "height": height, "desks": desks, "zones": zones, "dividers": dividers, "props": props,
           "wall": wall, "spots": spots, "decor_slots": decor, "wall_slots": wall_slots, "season_slot": season_slot}
    if region_idx >= 2:
        out["hr_room"] = {"width": 5, "desk": [1, 4], "plant": [3, height - 2], "sign_x": 1.5}
    return out


def main():
    offices, regions = [], []
    level = 1
    for ri, r in enumerate(REGIONS):
        first = level
        levels = []
        for k, cap in enumerate(r["capacities"]):
            entry = {"level": level, "region": ri + 1, "region_level": k + 1, "name": r["level_names"][k],
                     "capacity": cap, "rent": r["rent"][k], "upgrade_cost": r["expansion_costs"][k], "rep_required": 0}
            entry.update(layout(cap, ri))
            offices.append(entry)
            levels.append(level)
            level += 1
        regions.append({"id": r["id"], "region": ri + 1, "name": r["name"], "tier": r["tier"], "tier_name": r["tier_name"],
                        "desc": r["desc"], "move_cost": r["move_cost"], "rep_required": r["rep_required"],
                        "first_level": first, "levels": levels, "map_pos": r["map_pos"], "has_rival": r["has_rival"]})
    with open(os.path.join(ROOT, "data", "offices.json"), "w", encoding="utf-8") as fh:
        json.dump({"comment": "Gerado por tools/gen_layouts.py — não editar à mão.", "offices": offices}, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    with open(os.path.join(ROOT, "data", "regions.json"), "w", encoding="utf-8") as fh:
        json.dump({"comment": "Gerado por tools/gen_layouts.py — regiões do World Map.", "moving_days": 7,
                   "moving_productivity": 0.85, "regions": regions}, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    for o in offices:
        print(o["level"], o["region"], o["name"], "cap", o["capacity"], "w×h", o["width"], o["height"], "mesas", len(o["desks"]))


if __name__ == "__main__":
    main()
