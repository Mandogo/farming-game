"""Art pixel moderne pour Greenhouse Idle — sol, cultures, décors, icônes UI."""
from __future__ import annotations

import math
import random
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "assets" / "textures"
RNG = random.Random(77)

# Tuile iso (bloc terre) — plus de pixels pour un rendu realiste
TW, TH, DEPTH = 80, 40, 22
CH = 140


def canvas(w: int = TW, h: int = CH) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def pset(img: Image.Image, x: int, y: int, c) -> None:
    if 0 <= x < img.width and 0 <= y < img.height and len(c) >= 4 and c[3] > 0:
        img.putpixel((x, y), tuple(c[:4]))


def lerp(a, b, t: float):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


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
    dy = y - oy
    if dy < 0 or dy >= TH:
        return False
    half = TH // 2
    if dy <= half:
        max_span = int((TW // 2 - 1) * (dy / max(half, 1)))
    else:
        max_span = int((TW // 2 - 1) * ((TH - 1 - dy) / max(half, 1)))
    return abs(x - cx) <= max_span


def point_in_poly(x: int, y: int, pts) -> bool:
    """Ray casting pour texture propre des faces laterales."""
    n = len(pts)
    inside = False
    j = n - 1
    for i in range(n):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / max(yj - yi, 1e-6) + xi):
            inside = not inside
        j = i
    return inside


def paint_side(img: Image.Image, pts, base, dark, light) -> None:
    """Face laterale : fill propre + gradient + grains discrets (dans le polygone)."""
    minx = max(0, min(p[0] for p in pts) - 1)
    maxx = min(TW - 1, max(p[0] for p in pts) + 1)
    miny = max(0, min(p[1] for p in pts) - 1)
    maxy = min(CH - 1, max(p[1] for p in pts) + 1)
    hspan = max(maxy - miny, 1)
    for y in range(miny, maxy + 1):
        t = (y - miny) / hspan
        row = lerp(light, dark, t * 0.85)
        for x in range(minx, maxx + 1):
            if not point_in_poly(x, y, pts):
                continue
            r = RNG.random()
            if r < 0.06:
                col = dark
            elif r < 0.10:
                col = light
            elif r < 0.13:
                # petit caillou / grain
                col = (min(255, row[0] + 35), min(255, row[1] + 28), min(255, row[2] + 20), 255)
            else:
                n = RNG.randint(-5, 5)
                col = (
                    max(0, min(255, row[0] + n)),
                    max(0, min(255, row[1] + n // 2)),
                    max(0, min(255, row[2] + n // 3)),
                    255,
                )
            pset(img, x, y, col)


def draw_soil_block(img: Image.Image, locked: bool = False) -> int:
    d = ImageDraw.Draw(img)
    oy = CH - TH - DEPTH - 12
    top = top_pts(oy)
    bl = (top[3][0], top[3][1] + DEPTH)
    br = (top[1][0], top[1][1] + DEPTH)
    bb = (top[2][0], top[2][1] + DEPTH)

    if locked:
        top_c = (88, 94, 84, 255)
        top_light = (112, 118, 106, 255)
        left_c = (52, 56, 50, 255)
        left_dark = (38, 42, 36, 255)
        left_light = (68, 72, 66, 255)
        right_c = (68, 74, 66, 255)
        right_dark = (48, 52, 46, 255)
        right_light = (85, 90, 82, 255)
        edge = (36, 40, 34, 255)
    else:
        # Terre labourée plus foncée pour faire ressortir les graines
        top_c = (78, 48, 28, 255)
        top_light = (98, 62, 36, 255)
        left_c = (58, 36, 20, 255)
        left_dark = (38, 24, 12, 255)
        left_light = (78, 50, 30, 255)
        right_c = (72, 46, 26, 255)
        right_dark = (44, 28, 14, 255)
        right_light = (95, 62, 38, 255)
        edge = (22, 12, 6, 255)

    # Ombre portée sous le bloc
    for i in range(8):
        alpha = 55 - i * 6
        d.ellipse(
            [TW // 2 - 28 - i, bb[1] - 1 + i, TW // 2 + 28 + i, bb[1] + 8 + i],
            fill=(18, 20, 28, max(0, alpha)),
        )

    # Faces laterales propres (plus de spray hors polygone)
    paint_side(img, [top[3], top[2], bb, bl], left_c, left_dark, left_light)
    paint_side(img, [top[1], top[2], bb, br], right_c, right_dark, right_light)

    # Dessus : terre labourée (sillons diagonaux sombres)
    furrow_dark = (42, 26, 14, 255) if not locked else (48, 50, 46, 255)
    furrow_mid = (58, 36, 20, 255) if not locked else (62, 64, 58, 255)
    ridge = (108, 72, 44, 255) if not locked else (105, 108, 100, 255)
    d.polygon(top, fill=top_c)
    for y in range(oy, oy + TH):
        for x in range(TW):
            if not in_diamond(x, y, oy):
                continue
            t = (y - oy) / max(TH - 1, 1)
            nx = (x - TW // 2) / (TW // 2)
            # Sillons iso (diagonales type labour)
            furrow = ((x + y * 2) // 3) % 5
            if furrow == 0:
                base = furrow_dark
            elif furrow == 1:
                base = furrow_mid
            elif furrow == 4:
                base = ridge
            else:
                light = 0.08 - nx * 0.06 - t * 0.08
                base = lerp(top_light, top_c, clampf(t * 0.75 - light, 0.0, 1.0))
            noise = RNG.randint(-5, 5)
            pset(img, x, y, (
                max(0, min(255, base[0] + noise)),
                max(0, min(255, base[1] + noise // 2)),
                max(0, min(255, base[2] + noise // 3)),
                255,
            ))

    # Petites mottes / cailloux discrets
    pebble_cols = [
        (95, 78, 58, 255), (70, 55, 40, 255), (120, 95, 70, 255),
        (55, 42, 30, 255),
    ] if not locked else [(100, 105, 98, 255), (120, 122, 115, 255)]
    for _ in range(7 if not locked else 4):
        px = RNG.randint(TW // 2 - 20, TW // 2 + 20)
        py = RNG.randint(oy + 5, oy + TH - 6)
        if not in_diamond(px, py, oy):
            continue
        col = pebble_cols[RNG.randint(0, len(pebble_cols) - 1)]
        hi = (min(255, col[0] + 18), min(255, col[1] + 14), min(255, col[2] + 10), 255)
        pset(img, px, py, col)
        pset(img, px, py - 1, hi)

    # Contours + highlight arête (pas d'herbe)
    d.line([top[0], top[1], top[2], top[3], top[0]], fill=edge, width=1)
    d.line([top[3], bl, bb, top[2]], fill=edge, width=1)
    d.line([top[1], br, bb], fill=edge, width=1)
    d.line([top[0], top[1]], fill=(140, 110, 70, 90) if not locked else (150, 155, 145, 80), width=1)

    if locked:
        cx2, cy2 = TW // 2, oy + TH // 2
        d.rounded_rectangle([cx2 - 8, cy2 - 2, cx2 + 8, cy2 + 12], radius=2, fill=(48, 52, 58, 250))
        d.arc([cx2 - 7, cy2 - 13, cx2 + 7, cy2 + 1], 200, 340, fill=(170, 175, 185, 255), width=2)
        d.ellipse([cx2 - 1, cy2 + 3, cx2 + 2, cy2 + 6], fill=(220, 200, 80, 255))

    # poussiere fine (discret)
    if not locked:
        for _ in range(4):
            px = RNG.randint(TW // 2 - 20, TW // 2 + 20)
            py = RNG.randint(oy - 10, oy + 6)
            pset(img, px, py, (190, 165, 120, 100) if RNG.random() < 0.5 else (95, 70, 45, 90))

    return oy


def clampf(v: float, a: float, b: float) -> float:
    return max(a, min(b, v))


def crop_palette(kind: str):
    # stem, stem_dark, leaf_light, head, head_hi
    if kind == "wheat":
        return (78, 150, 55, 255), (42, 95, 35, 255), (130, 200, 85, 255), (218, 175, 48, 255), (245, 220, 110, 255)
    if kind == "barley":
        return (90, 160, 60, 255), (48, 105, 38, 255), (150, 210, 100, 255), (230, 195, 95, 255), (250, 230, 150, 255)
    if kind == "oat":
        return (70, 145, 58, 255), (38, 95, 36, 255), (125, 195, 105, 255), (215, 200, 150, 255), (245, 235, 195, 255)
    return (55, 135, 48, 255), (30, 85, 30, 255), (110, 185, 80, 255), (240, 190, 40, 255), (255, 230, 100, 255)


def draw_leaf(img, x, y, left: bool, g, gl, size: int = 3) -> None:
    """Petite feuille laterale."""
    direction = -1 if left else 1
    for i in range(size):
        pset(img, x + direction * (i + 1), y - i // 2, gl if i == 0 else g)
        if i < size - 1:
            pset(img, x + direction * (i + 1), y - i // 2 - 1, g)


def draw_sprout(img: Image.Image, stage: int, oy: int, kind: str) -> None:
    g, gd, gl, head, hhi = crop_palette(kind)
    cx = TW // 2
    ground = oy + TH // 2 - 1

    if stage == 1:
        # germes qui percent la terre
        for dx in (-5, 0, 5):
            x = cx + dx + RNG.randint(-1, 1)
            pset(img, x, ground, gd)
            pset(img, x, ground - 1, g)
            pset(img, x, ground - 2, gl)
            if RNG.random() < 0.5:
                pset(img, x + 1, ground - 2, g)
        return

    if stage == 2:
        # jeunes plantules a 2 feuilles
        for dx in (-8, 0, 8):
            x = cx + dx
            for i in range(5):
                pset(img, x, ground - i, gd if i < 2 else g)
            draw_leaf(img, x, ground - 4, True, g, gl, 3)
            draw_leaf(img, x, ground - 3, False, g, gl, 2)
            pset(img, x, ground - 5, gl)
        return

    if kind == "wheat":
        xs = [-14, -5, 4, 13] if stage == 4 else [-10, -2, 6]
        h = 22 if stage == 4 else 15
        for dx in xs:
            x = cx + dx + RNG.randint(-1, 1)
            lean = 1 if dx > 2 else (-1 if dx < -2 else 0)
            for i in range(h):
                px = x + (i // 8) * lean
                pset(img, px, ground - i, gd if i < 4 else g)
                if 4 < i < h - 6 and i % 4 == 0:
                    draw_leaf(img, px, ground - i, i % 8 == 0, g, gl, 2)
            top = ground - h
            # epi densifié
            ear_h = 8 if stage == 4 else 5
            for i in range(ear_h):
                pset(img, x + lean, top + i, head)
                pset(img, x + lean - 1, top + i, hhi if i % 2 == 0 else head)
                if stage == 4:
                    pset(img, x + lean + 1, top + i, head if i % 2 else (200, 155, 40, 255))
            # barbes (awns)
            if stage == 4:
                for bx in (-1, 0, 1):
                    pset(img, x + lean + bx, top - 1, (190, 150, 45, 255))
                    pset(img, x + lean + bx, top - 2, (175, 135, 40, 255))
                    if abs(bx) == 0:
                        pset(img, x + lean, top - 3, (165, 125, 35, 255))

    elif kind == "barley":
        xs = [-14, -5, 4, 13] if stage == 4 else [-9, 0, 9]
        for dx in xs:
            x = cx + dx
            lean = 1 if dx >= 0 else -1
            h = 18 if stage == 4 else 13
            for i in range(h):
                pset(img, x + (i // 6) * lean, ground - i, gd if i < 3 else g)
            top = ground - h
            # epi ovale + longues barbes
            for oy2 in range(6):
                for ox in range(-2, 3):
                    col = head if abs(ox) < 2 else hhi
                    pset(img, x + lean + ox, top + oy2, col)
            for bx in range(-3, 4):
                for by in range(1, 5 if stage == 4 else 3):
                    pset(img, x + lean + bx, top - by, (205, 175, 90, 255) if by < 3 else (185, 155, 70, 255))

    elif kind == "oat":
        xs = [-11, -2, 8] if stage == 3 else [-14, -5, 4, 13]
        for dx in xs:
            x = cx + dx
            for i in range(16 if stage == 4 else 12):
                pset(img, x, ground - i, gd if i < 3 else g)
            top = ground - (16 if stage == 4 else 12)
            # panicule : grappes ouvertes
            clusters = [(-4, 0), (4, 0), (0, -3), (-3, -3), (3, -3), (-2, 2), (2, 2)]
            if stage == 4:
                clusters += [(-5, -5), (5, -5), (0, -6), (-6, 1), (6, 1)]
            for ox, oy2 in clusters:
                pset(img, x + ox, top + oy2, head)
                pset(img, x + ox, top + oy2 - 1, hhi)
                pset(img, x + ox + 1, top + oy2, (200, 185, 140, 255))

    else:  # corn
        xs = [-10, 10] if stage == 3 else [-14, 0, 14]
        for dx in xs:
            x = cx + dx
            h = 28 if stage == 4 else 20
            for i in range(h):
                pset(img, x, ground - i, gd)
                pset(img, x - 1, ground - i, g)
                if i > 3:
                    pset(img, x + 1, ground - i, (45, 110, 40, 255))
            # grandes feuilles arquees
            leaf_ys = [h // 4, h // 2, (3 * h) // 4]
            for li, ly in enumerate(leaf_ys):
                yy = ground - ly
                for side in (-1, 1):
                    for j in range(5 + (li % 2)):
                        pset(img, x + side * (2 + j), yy - j // 2, gl if j < 2 else g)
                        pset(img, x + side * (2 + j), yy - j // 2 + 1, gd)
            # epi
            ey = ground - h // 2 - 2
            husk = (50, 120, 45, 255)
            for yy in range(10 if stage == 4 else 7):
                for xx in range(5):
                    if xx == 0 or xx == 4:
                        pset(img, x + 2 + xx, ey + yy, husk)
                    else:
                        pset(img, x + 2 + xx, ey + yy, head if (xx + yy) % 2 == 0 else hhi)
            if stage == 4:
                # soies
                for s in range(4):
                    pset(img, x + 3 + (s % 2), ey - 1 - s, (235, 220, 140, 255))
                    pset(img, x + 4, ey - 2 - s, (220, 200, 120, 255))


def make_soil(locked: bool = False) -> Image.Image:
    img = canvas()
    draw_soil_block(img, locked)
    return img


def make_crop(kind: str, stage: int) -> Image.Image:
    """Plante seule (fond transparent) — la terre reste sur soil_empty."""
    img = canvas()
    oy = CH - TH - DEPTH - 12  # meme ancrage que le bloc terre
    draw_sprout(img, stage, oy, kind)
    return img


def make_icon(kind: str) -> Image.Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([1, 1, 30, 30], radius=7, fill=(48, 78, 52, 255), outline=(28, 48, 32, 255), width=2)
    d.rounded_rectangle([3, 3, 28, 14], radius=4, fill=(70, 120, 78, 90))
    d.polygon([(16, 20), (26, 25), (16, 30), (6, 25)], fill=(126, 86, 52, 255), outline=(60, 40, 24, 255))
    g, gd, gl, head, hhi = crop_palette(kind)
    if kind == "corn":
        d.line([(16, 24), (16, 9)], fill=gd, width=2)
        d.ellipse([18, 11, 27, 22], fill=head)
        d.ellipse([19, 12, 23, 16], fill=hhi)
    elif kind == "oat":
        d.line([(16, 26), (16, 13)], fill=g, width=2)
        for ox, oy in [(-5, 0), (5, 0), (0, -4), (-3, -3), (3, -3)]:
            d.ellipse([14 + ox, 11 + oy, 19 + ox, 16 + oy], fill=head)
    elif kind == "barley":
        d.line([(14, 26), (18, 11)], fill=g, width=2)
        d.ellipse([15, 7, 26, 17], fill=head)
        d.ellipse([17, 8, 21, 12], fill=hhi)
    else:
        d.line([(16, 26), (16, 11)], fill=g, width=2)
        d.rounded_rectangle([12, 6, 20, 14], radius=2, fill=head)
        d.point((14, 8), fill=hhi)
        d.point((15, 7), fill=(200, 160, 50, 255))
    return img


# ─── UI icons ───────────────────────────────────────────────

def upscale(img: Image.Image, n: int = 3) -> Image.Image:
    return img.resize((img.width * n, img.height * n), Image.NEAREST)


def icon_coin() -> Image.Image:
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([1, 1, 22, 22], fill=(180, 130, 30, 255))
    d.ellipse([2, 2, 21, 21], fill=(235, 185, 45, 255), outline=(150, 100, 20, 255))
    d.ellipse([5, 5, 18, 18], fill=(255, 220, 80, 255))
    d.ellipse([7, 6, 12, 11], fill=(255, 245, 180, 220))
    d.line([(12, 7), (12, 17)], fill=(150, 100, 20, 255), width=1)
    d.arc([9, 8, 15, 13], 200, 20, fill=(150, 100, 20, 255), width=1)
    d.arc([9, 12, 15, 17], 20, 200, fill=(150, 100, 20, 255), width=1)
    return img


def icon_seed_bag() -> Image.Image:
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(5, 9), (19, 9), (21, 21), (3, 21)], fill=(170, 120, 60, 255), outline=(100, 70, 35, 255))
    d.rectangle([8, 5, 16, 10], fill=(140, 95, 45, 255))
    d.line([(8, 7), (16, 7)], fill=(90, 60, 30, 255), width=1)
    d.ellipse([8, 11, 13, 16], fill=(240, 200, 70, 255))
    d.ellipse([12, 13, 17, 18], fill=(90, 170, 55, 255))
    d.ellipse([10, 15, 15, 20], fill=(250, 220, 90, 255))
    return img


def icon_scythe() -> Image.Image:
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.line([(5, 21), (14, 7)], fill=(130, 85, 45, 255), width=3)
    d.line([(5, 21), (14, 7)], fill=(160, 110, 60, 255), width=1)
    d.arc([7, 1, 22, 16], 195, 50, fill=(210, 220, 230, 255), width=3)
    d.arc([9, 3, 20, 14], 200, 40, fill=(245, 250, 255, 255), width=1)
    return img


def icon_heat() -> Image.Image:
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(12, 2), (18, 12), (14, 12), (17, 22), (6, 10), (11, 10)], fill=(255, 140, 40, 255), outline=(200, 80, 20, 255))
    d.polygon([(12, 6), (15, 12), (13, 12), (14, 18), (9, 11), (12, 11)], fill=(255, 220, 80, 255))
    return img


def icon_combo() -> Image.Image:
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(4, 18), (10, 4), (14, 4), (8, 18)], fill=(255, 200, 50, 255), outline=(180, 120, 20, 255))
    d.polygon([(10, 18), (16, 4), (20, 4), (14, 18)], fill=(255, 160, 40, 255), outline=(180, 100, 20, 255))
    return img


def icon_mission() -> Image.Image:
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([4, 2, 20, 22], radius=2, fill=(245, 235, 200, 255), outline=(120, 100, 60, 255))
    d.rectangle([7, 6, 17, 8], fill=(90, 150, 80, 255))
    d.rectangle([7, 11, 17, 13], fill=(160, 140, 90, 255))
    d.rectangle([7, 16, 14, 18], fill=(160, 140, 90, 255))
    return img


def icon_upgrade() -> Image.Image:
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(12, 3), (20, 11), (16, 11), (16, 21), (8, 21), (8, 11), (4, 11)], fill=(80, 190, 120, 255), outline=(40, 120, 70, 255))
    d.polygon([(12, 6), (17, 11), (14, 11), (14, 18), (10, 18), (10, 11), (7, 11)], fill=(160, 240, 180, 255))
    return img


def icon_prestige() -> Image.Image:
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # étoile
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        r = 10 if i % 2 == 0 else 4
        pts.append((12 + r * math.cos(ang), 12 + r * math.sin(ang)))
    d.polygon(pts, fill=(255, 210, 70, 255), outline=(180, 130, 30, 255))
    return img


def icon_waterer() -> Image.Image:
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([6, 10, 18, 22], fill=(70, 160, 220, 255), outline=(40, 100, 160, 255))
    d.polygon([(12, 3), (16, 10), (8, 10)], fill=(90, 180, 240, 255))
    d.ellipse([9, 13, 13, 17], fill=(180, 230, 255, 200))
    return img


def icon_harvester() -> Image.Image:
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([3, 10, 18, 18], radius=2, fill=(90, 140, 70, 255), outline=(50, 90, 40, 255))
    d.ellipse([14, 8, 22, 16], fill=(70, 75, 80, 255), outline=(40, 45, 50, 255))
    d.ellipse([16, 10, 20, 14], fill=(120, 125, 130, 255))
    d.rectangle([5, 6, 10, 10], fill=(200, 180, 60, 255))
    return img


def icon_planter() -> Image.Image:
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(4, 18), (12, 8), (20, 18)], fill=(140, 100, 55, 255), outline=(90, 60, 30, 255))
    d.ellipse([9, 4, 15, 10], fill=(80, 180, 70, 255))
    d.ellipse([10, 5, 13, 8], fill=(140, 220, 100, 255))
    return img


# ─── Décors / fond ───────────────────────────────────────────

def make_grass_iso() -> Image.Image:
    img = canvas(64, 40)
    d = ImageDraw.Draw(img)
    pts = [(32, 2), (62, 18), (32, 34), (2, 18)]
    d.polygon(pts, fill=(72, 148, 78, 255))
    # texture
    for y in range(40):
        for x in range(64):
            # diamond test approx
            dx = abs(x - 32) / 30
            dy = abs(y - 18) / 16
            if dx + dy > 1.0:
                continue
            r = RNG.random()
            if r < 0.08:
                pset(img, x, y, (52, 120, 58, 255))
            elif r < 0.14:
                pset(img, x, y, (110, 190, 100, 255))
            elif r < 0.17:
                pset(img, x, y, (90, 170, 85, 255))
    # highlight edge
    d.line([pts[0], pts[1]], fill=(140, 210, 120, 160), width=1)
    d.line([pts[0], pts[3]], fill=(90, 170, 90, 100), width=1)
    d.line([pts[1], pts[2], pts[3]], fill=(40, 90, 45, 180), width=1)
    return img


def make_field_bg() -> Image.Image:
    """Fond champ : planète alien — dégradé violet → blanc au centre."""
    w, h = 320, 200
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cx, cy = w / 2.0, h / 2.0
    max_d = math.sqrt(cx * cx + cy * cy)
    violet = (72, 42, 120, 255)
    violet_deep = (40, 22, 72, 255)
    white = (245, 240, 255, 255)
    for y in range(h):
        for x in range(w):
            # distance du centre (0 = centre blanc, 1 = bords violets)
            dx = (x - cx) / cx
            dy = (y - cy) / cy
            dist = math.sqrt(dx * dx + dy * dy * 0.85)
            dist = clampf(dist, 0.0, 1.35) / 1.35
            # soft radial : blanc au centre, violet aux bords
            if dist < 0.35:
                c = lerp(white, (200, 185, 235, 255), dist / 0.35)
            elif dist < 0.7:
                c = lerp((200, 185, 235, 255), violet, (dist - 0.35) / 0.35)
            else:
                c = lerp(violet, violet_deep, (dist - 0.7) / 0.3)
            noise = RNG.randint(-6, 6)
            pset(img, x, y, (
                max(0, min(255, c[0] + noise)),
                max(0, min(255, c[1] + noise)),
                max(0, min(255, c[2] + noise // 2)),
                255,
            ))
    # grains / poussière alien
    for _ in range(90):
        x, y = RNG.randint(0, w - 1), RNG.randint(0, h - 1)
        pset(img, x, y, (220, 200, 255, 180) if RNG.random() < 0.5 else (90, 60, 140, 160))
    # quelques rochers plats
    for _ in range(12):
        x, y = RNG.randint(10, w - 10), RNG.randint(10, h - 10)
        for ox in range(-3, 4):
            for oy in range(-1, 2):
                if abs(ox) + abs(oy) * 2 <= 4:
                    pset(img, x + ox, y + oy, (95, 70, 110, 255))
        pset(img, x - 1, y - 1, (140, 120, 160, 255))
    return img


def make_sky_bg() -> Image.Image:
    """Ciel doux serre / journee — large pour fond plein ecran."""
    w, h = 640, 360
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        t = y / h
        if t < 0.42:
            c = lerp((120, 185, 235, 255), (175, 220, 250, 255), t / 0.42)
        elif t < 0.58:
            c = lerp((175, 220, 250, 255), (200, 230, 185, 255), (t - 0.42) / 0.16)
        else:
            c = lerp((150, 200, 130, 255), (70, 135, 80, 255), (t - 0.58) / 0.42)
        for x in range(w):
            # legere variation horizontale
            wobble = int(4 * math.sin(x * 0.01 + y * 0.02))
            pset(img, x, y, (
                max(0, min(255, c[0] + wobble)),
                max(0, min(255, c[1] + wobble // 2)),
                max(0, min(255, c[2])),
                255,
            ))
    d = ImageDraw.Draw(img)

    def blob_cloud(cx: int, cy: int, parts: list[tuple[int, int, int]]) -> None:
        for ox, oy, r in parts:
            d.ellipse([cx + ox - r, cy + oy - r // 2, cx + ox + r, cy + oy + r // 2], fill=(255, 255, 255, 210))
            d.ellipse([cx + ox - r + 2, cy + oy - r // 2 + 1, cx + ox + r - 3, cy + oy + r // 2 - 2], fill=(245, 250, 255, 180))

    blob_cloud(90, 48, [(-18, 4, 16), (0, 0, 20), (20, 3, 14), (8, -6, 12)])
    blob_cloud(280, 62, [(-22, 2, 18), (0, -2, 22), (24, 4, 15), (-6, -8, 11)])
    blob_cloud(480, 40, [(-14, 2, 14), (4, 0, 18), (22, 3, 12)])
    blob_cloud(580, 70, [(-10, 0, 12), (8, 2, 14)])

    # soleil doux
    sx, sy = 520, 55
    for r, a in ((28, 40), (20, 70), (14, 120)):
        d.ellipse([sx - r, sy - r, sx + r, sy + r], fill=(255, 240, 160, a))
    d.ellipse([sx - 10, sy - 10, sx + 10, sy + 10], fill=(255, 250, 200, 230))

    # collines lointaines (2 couches)
    for x in range(w):
        hill = int(h * 0.50 + 22 * math.sin(x * 0.015) + 12 * math.sin(x * 0.04))
        for y in range(hill, int(h * 0.58)):
            shade = 0 if y > hill + 3 else 18
            pset(img, x, y, (55 + shade, 115 + shade, 75 + shade, 255))
    for x in range(w):
        hill = int(h * 0.56 + 14 * math.sin(x * 0.025 + 1.2) + 8 * math.sin(x * 0.07))
        for y in range(hill, h):
            t = (y - hill) / max(h - hill, 1)
            base = lerp((78, 150, 88, 255), (48, 110, 62, 255), t)
            if RNG.random() < 0.04:
                base = (base[0] + 20, base[1] + 25, base[2] + 10, 255)
            pset(img, x, y, base)

    # serre pixel au fond (verre + structure)
    gx, gy = 400, int(h * 0.46)
    # ombre
    d.ellipse([gx + 20, gy + 68, gx + 170, gy + 82], fill=(30, 60, 35, 60))
    # structure
    d.polygon([(gx, gy + 50), (gx + 90, gy + 8), (gx + 180, gy + 50)], fill=(200, 230, 220, 200), outline=(90, 130, 120, 255))
    d.rectangle([gx + 8, gy + 50, gx + 172, gy + 78], fill=(170, 205, 195, 180), outline=(80, 120, 110, 255))
    # montants
    for mx in (gx + 45, gx + 90, gx + 135):
        d.line([(mx, gy + 50), (mx, gy + 78)], fill=(100, 140, 130, 200), width=1)
    d.line([(gx + 90, gy + 8), (gx + 90, gy + 50)], fill=(100, 140, 130, 220), width=1)
    # reflets verre
    d.line([(gx + 30, gy + 30), (gx + 55, gy + 42)], fill=(255, 255, 255, 120), width=1)
    d.line([(gx + 110, gy + 28), (gx + 140, gy + 42)], fill=(255, 255, 255, 90), width=1)

    # arbres stylises lointains
    for tx, tht in [(60, 28), (120, 22), (200, 30), (560, 24)]:
        base_y = int(h * 0.57)
        d.rectangle([tx - 2, base_y - 8, tx + 2, base_y], fill=(90, 70, 45, 255))
        d.ellipse([tx - tht // 3, base_y - tht, tx + tht // 3, base_y - 4], fill=(50, 120, 65, 255))
        d.ellipse([tx - tht // 4, base_y - tht - 4, tx + tht // 5, base_y - tht // 2], fill=(70, 150, 80, 255))

    return img


def make_panel_frame() -> Image.Image:
    """Petite décoration coin bois pour panels."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(0, 0), (15, 0), (0, 15)], fill=(140, 100, 55, 255))
    d.line([(0, 0), (15, 0)], fill=(200, 160, 90, 255), width=1)
    d.line([(0, 0), (0, 15)], fill=(100, 70, 40, 255), width=1)
    return img


def make_ready_sparkle() -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(8, 1), (10, 6), (15, 8), (10, 10), (8, 15), (6, 10), (1, 8), (6, 6)], fill=(255, 240, 120, 255))
    d.ellipse([6, 6, 10, 10], fill=(255, 255, 220, 255))
    return img


def save(img: Image.Image, name: str, scale: int = 3) -> None:
    upscale(img, scale).save(OUT / f"{name}.png")
    print("wrote", name)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    # Sol / cultures : x2 (base plus detaillee) → ~160x280
    save(make_soil(False), "soil_empty", 2)
    save(make_soil(True), "soil_locked", 2)
    for kind in ("wheat", "barley", "oat", "corn"):
        for s in range(1, 5):
            save(make_crop(kind, s), f"{kind}_{s}", 2)
        save(make_icon(kind), f"icon_{kind}", scale=2)

    save(icon_coin(), "ui_coin", 2)
    save(icon_seed_bag(), "ui_seed_bag", 2)
    save(icon_scythe(), "ui_scythe", 2)
    save(icon_heat(), "ui_heat", 2)
    save(icon_combo(), "ui_combo", 2)
    save(icon_mission(), "ui_mission", 2)
    save(icon_upgrade(), "ui_upgrade", 2)
    save(icon_prestige(), "ui_prestige", 2)
    save(icon_waterer(), "ui_waterer", 2)
    save(icon_harvester(), "ui_harvester", 2)
    save(icon_planter(), "ui_planter", 2)
    save(make_ready_sparkle(), "ui_sparkle", 2)
    save(make_panel_frame(), "ui_corner", 2)
    save(make_grass_iso(), "grass_iso", 2)
    save(make_field_bg(), "field_bg", 2)
    # sky plus grand, scale 2
    save(make_sky_bg(), "sky_bg", 2)
    print("Done ->", OUT)


if __name__ == "__main__":
    main()
