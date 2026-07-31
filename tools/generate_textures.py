"""Textures iso style reference : terre mottlee + pousses pixel art."""
from __future__ import annotations

import random
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "assets" / "textures"

# Tuile iso plus "bloc cube" comme la ref
TW, TH, DEPTH = 64, 32, 16
CH = 96
RNG = random.Random(42)


def canvas() -> Image.Image:
    return Image.new("RGBA", (TW, CH), (0, 0, 0, 0))


def pset(img: Image.Image, x: int, y: int, c) -> None:
    if 0 <= x < TW and 0 <= y < CH and len(c) >= 4 and c[3] > 0:
        img.putpixel((x, y), c)


def top_pts(oy: int):
    cx = TW // 2
    return [
        (cx, oy),
        (cx + TW // 2 - 1, oy + TH // 2),
        (cx, oy + TH - 1),
        (cx - TW // 2 + 1, oy + TH // 2),
    ]


def in_diamond(x: int, y: int, oy: int) -> bool:
    cx = TW // 2
    # approx diamond test
    dy = y - oy
    if dy < 0 or dy >= TH:
        return False
    # width grows then shrinks
    half = TH // 2
    if dy <= half:
        max_span = int((TW // 2 - 1) * (dy / max(half, 1)))
    else:
        max_span = int((TW // 2 - 1) * ((TH - 1 - dy) / max(half, 1)))
    return abs(x - cx) <= max_span


def draw_soil_block(img: Image.Image, locked: bool = False) -> int:
    d = ImageDraw.Draw(img)
    oy = CH - TH - DEPTH - 6
    top = top_pts(oy)
    bl = (top[3][0], top[3][1] + DEPTH)
    br = (top[1][0], top[1][1] + DEPTH)
    bb = (top[2][0], top[2][1] + DEPTH)

    # Palette ref
    top_c = (110, 78, 48, 255) if not locked else (80, 78, 70, 255)
    top_dark = (88, 60, 36, 255)
    top_light = (130, 95, 60, 255)
    left_c = (72, 48, 30, 255)
    right_c = (90, 60, 36, 255)
    side_dark = (45, 30, 18, 255)
    side_mid = (60, 40, 24, 255)
    edge = (28, 18, 10, 255)

    # Faces laterales
    d.polygon([top[3], top[2], bb, bl], fill=left_c)
    d.polygon([top[1], top[2], bb, br], fill=right_c)

    # Mottling sur les cotes (terre / cailloux)
    for face in ([top[3], top[2], bb, bl], [top[1], top[2], bb, br]):
        minx = min(p[0] for p in face)
        maxx = max(p[0] for p in face)
        miny = min(p[1] for p in face)
        maxy = max(p[1] for p in face)
        for _ in range(55):
            x = RNG.randint(minx, maxx)
            y = RNG.randint(miny, maxy)
            # rough inside check via barycentric-ish skip
            col = side_dark if RNG.random() < 0.55 else side_mid
            if RNG.random() < 0.15:
                col = (20, 14, 8, 255)
            pset(img, x, y, col)
            if RNG.random() < 0.3:
                pset(img, x + 1, y, col)

    # Dessus
    d.polygon(top, fill=top_c)
    for y in range(oy, oy + TH):
        for x in range(TW):
            if not in_diamond(x, y, oy):
                continue
            r = RNG.random()
            if r < 0.08:
                pset(img, x, y, top_dark)
            elif r < 0.14:
                pset(img, x, y, top_light)
            elif r < 0.17:
                pset(img, x, y, (70, 48, 28, 255))

    # Lignes de grille legeres (comme la ref)
    cx = TW // 2
    for i in range(1, 4):
        t = i / 4.0
        y = int(oy + TH * t)
        span = int((TW // 2 - 2) * (1 - abs(t - 0.5) * 2))
        d.line([(cx - span, y), (cx + span, y)], fill=(70, 48, 28, 90), width=1)

    # Contours nets
    d.line([top[0], top[1], top[2], top[3], top[0]], fill=edge, width=1)
    d.line([top[3], bl, bb, top[2]], fill=edge, width=1)
    d.line([top[1], br, bb], fill=edge, width=1)

    if locked:
        cx2, cy2 = TW // 2, oy + TH // 2
        d.rectangle([cx2 - 6, cy2 - 1, cx2 + 6, cy2 + 8], fill=(50, 50, 58, 240))
        d.arc([cx2 - 5, cy2 - 10, cx2 + 5, cy2], 200, 340, fill=(140, 140, 155, 255), width=2)

    # Petites poussieres flottantes (optionnel, leger)
    if not locked:
        for _ in range(4):
            px = RNG.randint(TW // 2 - 18, TW // 2 + 18)
            py = RNG.randint(oy - 10, oy + 6)
            pset(img, px, py, (180, 160, 130, 120) if RNG.random() < 0.5 else (90, 70, 50, 100))

    return oy


def sprout_stage(img: Image.Image, stage: int, oy: int, accent=None) -> None:
    """Pousses style ref : stage 1 dots, 2 mini tige, 3-4 feuilles."""
    cx = TW // 2
    ground = oy + TH // 2 - 2
    g = (90, 190, 70, 255)
    g_dark = (50, 120, 40, 255)
    g_light = (170, 230, 110, 255)
    if accent:
        g, g_dark, g_light = accent

    if stage == 1:
        # 1-3 pixels lime
        for dx in (-2, 0, 2)[: RNG.randint(1, 3)]:
            pset(img, cx + dx, ground, g)
            if RNG.random() < 0.5:
                pset(img, cx + dx, ground - 1, g_light)
        return

    if stage == 2:
        # mini tige + 2 feuilles minuscules
        for dx in (-4, 4):
            x = cx + dx
            pset(img, x, ground, g_dark)
            pset(img, x, ground - 1, g)
            pset(img, x, ground - 2, g)
            pset(img, x - 1, ground - 3, g)
            pset(img, x + 1, ground - 3, g)
            pset(img, x, ground - 3, g_light)
        return

    # stage 3+ : plusieurs pousses a 2 feuilles
    count = 3 if stage == 3 else 5
    xs = [-10, -5, 0, 5, 10][:count]
    h = 5 if stage == 3 else 8
    for dx in xs:
        x = cx + dx + RNG.randint(-1, 1)
        # tige
        for i in range(h):
            pset(img, x, ground - i, g_dark if i < 2 else g)
        # 2 feuilles symetriques
        top = ground - h
        pset(img, x - 1, top, g)
        pset(img, x + 1, top, g)
        pset(img, x - 2, top - 1, g)
        pset(img, x + 2, top - 1, g)
        pset(img, x - 1, top - 1, g_light)
        pset(img, x + 1, top - 1, g_light)
        pset(img, x, top - 1, g_light)
        if stage >= 4:
            # 2e etage de feuilles
            pset(img, x - 2, top - 2, g)
            pset(img, x + 2, top - 2, g)
            pset(img, x, top - 2, g_light)


def crop_accents(kind: str):
    """Couleurs distinctes par cereale, meme silhouette pousse au debut puis tete."""
    if kind == "wheat":
        return (95, 185, 65, 255), (55, 125, 40, 255), (175, 225, 100, 255), (230, 190, 70, 255)
    if kind == "barley":
        return (110, 195, 75, 255), (65, 135, 45, 255), (190, 230, 120, 255), (245, 215, 130, 255)
    if kind == "oat":
        return (85, 175, 70, 255), (50, 120, 45, 255), (160, 220, 130, 255), (220, 205, 155, 255)
    # corn
    return (70, 160, 55, 255), (40, 110, 35, 255), (140, 210, 90, 255), (245, 205, 50, 255)


def draw_mature_head(img, kind, oy, stage):
    """Stages 3-4 : ajoute epis distincts au-dessus des pousses."""
    if stage < 3:
        return
    g, gd, gl, head = crop_accents(kind)
    cx = TW // 2
    ground = oy + TH // 2 - 2
    d = ImageDraw.Draw(img)

    if kind == "wheat":
        xs = [-8, -2, 4, 10] if stage == 4 else [-6, 0, 6]
        for dx in xs:
            x = cx + dx
            top = ground - (12 if stage == 4 else 9)
            for i in range(ground - 3, top, -1):
                pset(img, x, i, gd if i > ground - 6 else g)
            for i in range(5 if stage == 4 else 3):
                pset(img, x, top + i, head)
                pset(img, x - 1, top + i, head)
            if stage == 4:
                pset(img, x, top - 1, (200, 170, 60, 255))
                pset(img, x - 1, top - 2, (200, 170, 60, 255))
                pset(img, x + 1, top - 2, (200, 170, 60, 255))

    elif kind == "barley":
        xs = [-9, -3, 3, 9] if stage == 4 else [-6, 0, 6]
        for dx in xs:
            x = cx + dx
            top = ground - (11 if stage == 4 else 8)
            lean = 1 if dx >= 0 else -1
            for i in range(8):
                pset(img, x + (i // 4) * lean, ground - 2 - i, g)
            d.ellipse([x + lean - 2, top - 1, x + lean + 3, top + 5], fill=head)
            for bx in (-2, 0, 2):
                pset(img, x + lean + bx, top - 2, (210, 185, 100, 255))
                pset(img, x + lean + bx, top - 3, (210, 185, 100, 255))

    elif kind == "oat":
        xs = [-8, 0, 8] if stage == 3 else [-10, -3, 3, 10]
        for dx in xs:
            x = cx + dx
            top = ground - 10
            for i in range(8):
                pset(img, x, ground - 2 - i, g)
            for ox, oy2 in [(-3, 0), (3, 0), (0, -3), (-2, -2), (2, -2)]:
                pset(img, x + ox, top + oy2, head)
                pset(img, x + ox, top + oy2 - 1, (235, 225, 185, 255))

    else:  # corn
        xs = [-6, 6] if stage == 3 else [-8, 0, 8]
        for dx in xs:
            x = cx + dx
            h = 14 if stage == 4 else 11
            for i in range(h):
                pset(img, x, ground - i, gd)
                pset(img, x - 1, ground - i, g)
            # feuilles
            pset(img, x - 3, ground - h // 2, g)
            pset(img, x - 4, ground - h // 2 - 1, g)
            pset(img, x + 3, ground - h // 2, g)
            pset(img, x + 4, ground - h // 2 - 1, gl)
            # epi
            ey = ground - h // 2
            d.ellipse([x + 2, ey - 1, x + 7, ey + 7], fill=head)
            if stage == 4:
                pset(img, x + 4, ey - 2, (230, 210, 120, 255))
                pset(img, x + 5, ey - 3, (230, 210, 120, 255))


def make_soil(locked=False) -> Image.Image:
    img = canvas()
    draw_soil_block(img, locked)
    return img


def make_crop(kind: str, stage: int) -> Image.Image:
    img = canvas()
    oy = draw_soil_block(img, False)
    g, gd, gl, _head = crop_accents(kind)
    if stage <= 2:
        sprout_stage(img, stage, oy, (g, gd, gl))
    else:
        # base pousse + tetes
        sprout_stage(img, 2, oy, (g, gd, gl))
        draw_mature_head(img, kind, oy, stage)
    return img


def make_icon(kind: str) -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([1, 1, 30, 30], radius=6, fill=(42, 32, 22, 255), outline=(28, 18, 10, 255), width=2)
    # mini bloc terre
    d.polygon([(16, 18), (26, 23), (16, 28), (6, 23)], fill=(110, 78, 48, 255))
    g, gd, gl, head = crop_accents(kind)
    if kind == "corn":
        d.line([(16, 22), (16, 10)], fill=gd, width=2)
        d.ellipse([18, 12, 26, 22], fill=head)
    elif kind == "oat":
        d.line([(16, 24), (16, 14)], fill=g, width=1)
        for ox, oy in [(-4, 0), (4, 0), (0, -3)]:
            d.ellipse([14 + ox, 12 + oy, 18 + ox, 16 + oy], fill=head)
    elif kind == "barley":
        d.line([(14, 24), (18, 12)], fill=g, width=1)
        d.ellipse([16, 8, 24, 16], fill=head)
    else:
        d.line([(16, 24), (16, 12)], fill=g, width=1)
        d.rectangle([13, 8, 19, 14], fill=head)
    return img


def save(img: Image.Image, name: str) -> None:
    # x3 nearest pour un rendu crisp type ref
    big = img.resize((img.width * 3, img.height * 3), Image.NEAREST)
    big.save(OUT / f"{name}.png")
    print("wrote", name)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    save(make_soil(False), "soil_empty")
    save(make_soil(True), "soil_locked")
    for kind in ("wheat", "barley", "oat", "corn"):
        for s in range(1, 5):
            save(make_crop(kind, s), f"{kind}_{s}")
        save(make_icon(kind), f"icon_{kind}")
    print("Done", OUT)


if __name__ == "__main__":
    main()
