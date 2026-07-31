"""Modernise l'art : ciel, champ, cultures, logo — style cozy contemporain.

Usage : py tools/modernize_visuals.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
TEX = ROOT / "assets" / "textures"

CROPS = ("tomato", "eggplant", "carrot", "pepper")

PAL = {
	"tomato": {
		"stem": (48, 128, 58), "leaf": (78, 168, 72), "leaf_d": (42, 110, 48), "leaf_h": (120, 200, 95),
		"fruit": (214, 58, 48), "fruit_h": (255, 130, 95), "fruit_d": (150, 28, 28),
		"calyx": (52, 125, 48),
	},
	"eggplant": {
		"stem": (46, 120, 55), "leaf": (72, 155, 78), "leaf_d": (40, 100, 48), "leaf_h": (110, 185, 100),
		"fruit": (98, 48, 138), "fruit_h": (155, 100, 185), "fruit_d": (58, 28, 88),
		"calyx": (48, 118, 52),
	},
	"carrot": {
		"stem": (50, 135, 55), "leaf": (85, 175, 78), "leaf_d": (45, 115, 50), "leaf_h": (125, 205, 100),
		"fruit": (232, 118, 38), "fruit_h": (255, 175, 85), "fruit_d": (175, 75, 22),
		"calyx": (55, 140, 55),
	},
	"pepper": {
		"stem": (55, 130, 50), "leaf": (90, 185, 70), "leaf_d": (45, 110, 40), "leaf_h": (120, 200, 95),
		"fruit": (245, 198, 40), "fruit_h": (255, 235, 130), "fruit_d": (195, 140, 18),
		"calyx": (70, 155, 55), "fruit_alt": (255, 215, 70),
	},
}


def clamp(v: int, a: int = 0, b: int = 255) -> int:
	return max(a, min(b, v))


def mix(a, b, t: float):
	n = min(len(a), len(b), 3)
	return tuple(clamp(int(a[i] + (b[i] - a[i]) * t)) for i in range(n))


def rgba(c, a: int = 255):
	return (*c[:3], a)


def soft_outline(src: Image.Image, color=(28, 36, 24, 200), widen: int = 1) -> Image.Image:
	a = src.split()[-1]
	mask = a.point(lambda p: 255 if p > 20 else 0)
	outline = Image.new("RGBA", src.size, (0, 0, 0, 0))
	for dx in range(-widen, widen + 1):
		for dy in range(-widen, widen + 1):
			if dx == 0 and dy == 0:
				continue
			if abs(dx) + abs(dy) > widen + 0.5:
				continue
			layer = Image.new("RGBA", src.size, (0, 0, 0, 0))
			layer.paste(color, (dx, dy), mask)
			outline = Image.alpha_composite(outline, layer)
	out = Image.alpha_composite(outline, src)
	return out


def ellipse_shaded(d: ImageDraw.ImageDraw, box, base, hi, dark, soft=True):
	x0, y0, x1, y1 = [int(v) for v in box]
	if x1 < x0:
		x0, x1 = x1, x0
	if y1 < y0:
		y0, y1 = y1, y0
	d.ellipse([x0, y0, x1, y1], fill=rgba(base))
	# volume : anneau bas-droit plus doux (pas un « trou »)
	bw = max(2, (x1 - x0) // 5)
	bh = max(2, (y1 - y0) // 5)
	mx = int(x0 + (x1 - x0) * 0.38)
	my = int(y0 + (y1 - y0) * 0.42)
	if mx + bw < x1 and my + bh < y1:
		d.ellipse([mx, my, x1 - 1, y1 - 1], fill=rgba(mix(base, dark, 0.55), 70 if soft else 110))
	# highlight haut-gauche
	hx0 = int(x0 + (x1 - x0) * 0.16)
	hy0 = int(y0 + (y1 - y0) * 0.12)
	hx1 = int(x0 + (x1 - x0) * 0.55)
	hy1 = int(y0 + (y1 - y0) * 0.50)
	if hx1 > hx0 and hy1 > hy0:
		d.ellipse([hx0, hy0, hx1, hy1], fill=rgba(hi, 150))
	sx0 = int(x0 + (x1 - x0) * 0.30)
	sy0 = int(y0 + (y1 - y0) * 0.22)
	d.ellipse([sx0, sy0, sx0 + 5, sy0 + 4], fill=(255, 255, 255, 140))


def leaf(d, tip, base, p, flip=1):
	bx, by = base
	tx, ty = tip
	mid_x = (bx + tx) // 2 + flip * 8
	mid_y = (by + ty) // 2
	d.polygon([(bx, by), (mid_x, mid_y - 4), (tx, ty), (mid_x - flip * 3, mid_y + 5)], fill=rgba(p["leaf"]))
	d.line([(bx, by), (tx, ty)], fill=rgba(p["leaf_d"]), width=1)
	d.ellipse([tx - 3, ty - 2, tip[0] + 3, tip[1] + 3], fill=rgba(p["leaf_h"], 160))


def ground_shadow(d, cx, ground, w=36, a=55):
	d.ellipse([cx - w, ground - 4, cx + w, ground + 8], fill=(40, 55, 35, a))


# ── cultures ─────────────────────────────────────────────────


def draw_stage(kind: str, stage: int) -> Image.Image:
	p = PAL[kind]
	w, h = 160, 280
	img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	cx, ground = w // 2, 171

	if stage == 1:
		ground_shadow(d, cx, ground, 18, 40)
		for dx in (-10, 2, 12):
			x = cx + dx
			d.line([(x, ground), (x, ground - 8)], fill=rgba(p["stem"]), width=2)
			d.ellipse([x - 4, ground - 14, x + 4, ground - 5], fill=rgba(p["leaf"]))
			d.ellipse([x - 2, ground - 13, x + 1, ground - 9], fill=rgba(p["leaf_h"], 180))
		return soft_outline(img)

	if stage == 2:
		ground_shadow(d, cx, ground, 28, 48)
		for dx in (-20, 0, 20):
			x = cx + dx
			d.line([(x, ground), (x, ground - 22)], fill=rgba(p["stem"]), width=3)
			leaf(d, (x - 12, ground - 28), (x, ground - 14), p, -1)
			leaf(d, (x + 12, ground - 26), (x, ground - 12), p, 1)
			d.ellipse([x - 5, ground - 30, x + 5, ground - 20], fill=rgba(p["leaf"]))
		return soft_outline(img)

	ripe = stage == 4
	ground_shadow(d, cx, ground, 42 if ripe else 34, 60)
	scale = 1.35  # plantes plus imposantes sans passer par enlarge NEAREST

	if kind == "tomato":
		# buisson
		for dx, dh in ((-22, 38), (-6, 46), (10, 44), (26, 36)):
			x = cx + int(dx * scale)
			hh = int(dh * scale)
			d.line([(x, ground), (x, ground - hh)], fill=rgba(p["stem"]), width=4)
			leaf(d, (x - 16, ground - hh + 4), (x, ground - hh + 20), p, -1)
			leaf(d, (x + 16, ground - hh + 6), (x, ground - hh + 18), p, 1)
		positions = [(-30, -42), (-8, -52), (14, -50), (34, -40)] if ripe else [(-16, -38), (14, -40)]
		for dx, dy in positions:
			x = cx + int(dx * scale)
			fy = ground + int(dy * scale)
			r = 18 if ripe else 11
			col = p["fruit"] if ripe else (95, 155, 70)
			hi = p["fruit_h"] if ripe else (130, 190, 100)
			dk = p["fruit_d"] if ripe else (55, 110, 45)
			ellipse_shaded(d, [x - r, fy - r, x + r, fy + r], col, hi, dk)
			for ox in (-7, 0, 7):
				d.polygon([(x, fy - r + 2), (x + ox, fy - r - 8), (x + ox // 2, fy - r + 5)], fill=rgba(p["calyx"]))

	elif kind == "eggplant":
		for dx, dh in ((-18, 34), (0, 42), (20, 36)):
			x = cx + int(dx * scale)
			hh = int(dh * scale)
			d.line([(x, ground), (x, ground - hh)], fill=rgba(p["stem"]), width=4)
			leaf(d, (x - 18, ground - hh + 2), (x, ground - hh + 18), p, -1)
			leaf(d, (x + 16, ground - hh + 4), (x, ground - hh + 16), p, 1)
		positions = [(-28, -40), (0, -50), (28, -42)] if ripe else [(-14, -34), (16, -36)]
		for dx, dy in positions:
			x = cx + int(dx * scale)
			fy = ground + int(dy * scale)
			bw, bh = (15, 34) if ripe else (9, 20)
			col = p["fruit"] if ripe else (100, 145, 80)
			hi = p["fruit_h"] if ripe else (130, 180, 100)
			dk = p["fruit_d"] if ripe else (60, 100, 50)
			ellipse_shaded(d, [x - bw, fy, x + bw, fy + bh], col, hi, dk)
			d.ellipse([x - 10, fy - 8, x + 10, fy + 6], fill=rgba(p["calyx"]))
			d.line([(x, fy - 8), (x, fy - 18)], fill=rgba(p["stem"]), width=2)

	elif kind == "carrot":
		positions = [(-32, 0), (-10, 0), (12, 0), (34, 0)] if ripe else [(-14, 0), (14, 0)]
		for dx, _ in positions:
			x = cx + int(dx * scale)
			for ox, oy in ((-10, -30), (-2, -40), (8, -32), (2, -24), (-6, -22)):
				d.line([(x, ground - 6), (x + ox, ground + oy)], fill=rgba(p["leaf"]), width=3)
				d.ellipse([x + ox - 4, ground + oy - 4, x + ox + 4, ground + oy + 3], fill=rgba(p["leaf_h"], 180))
			top = ground - 4
			bh = 30 if ripe else 18
			bw = 10 if ripe else 6
			d.polygon(
				[(x - bw, top), (x + bw, top), (x + 2, top + bh), (x - 2, top + bh)],
				fill=rgba(p["fruit"]),
			)
			d.line([(x - bw, top), (x + 2, top + bh)], fill=rgba(mix(p["fruit"], p["fruit_d"], 0.5)), width=1)
			d.line([(x - 2, top + 3), (x - 1, top + bh - 5)], fill=rgba(p["fruit_h"], 200), width=2)

	else:  # pepper
		for dx, dh in ((-24, 32), (-4, 40), (16, 38), (34, 30)):
			x = cx + int(dx * scale)
			hh = int(dh * scale)
			d.line([(x, ground), (x, ground - hh)], fill=rgba(p["stem"]), width=4)
			leaf(d, (x - 14, ground - hh + 4), (x, ground - hh + 16), p, -1)
			leaf(d, (x + 14, ground - hh + 6), (x, ground - hh + 14), p, 1)
		positions = [(-30, -38), (-6, -48), (18, -46), (38, -36)] if ripe else [(-14, -32), (16, -34)]
		for i, (dx, dy) in enumerate(positions):
			x = cx + int(dx * scale)
			fy = ground + int(dy * scale)
			if ripe:
				col = p["fruit"] if i % 2 == 0 else p["fruit_alt"]
			else:
				col = (85, 150, 70)
			hi = p["fruit_h"] if ripe else (125, 185, 100)
			dk = p["fruit_d"] if ripe else (50, 105, 45)
			bw, bh = (14, 20) if ripe else (8, 12)
			ellipse_shaded(d, [x - bw, fy - 2, x + bw, fy + bh], col, hi, dk)
			d.ellipse([x - 6, fy - 9, x + 6, fy + 2], fill=rgba(p["calyx"] if ripe else p["stem"]))
			d.line([(x, fy - 9), (x, fy - 16)], fill=rgba(p["stem"]), width=2)

	return soft_outline(img)


def make_icon(kind: str) -> Image.Image:
	p = PAL[kind]
	img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	d.rounded_rectangle([1, 1, 62, 62], radius=16, fill=(236, 245, 232, 255), outline=(88, 140, 98, 220), width=2)
	d.ellipse([8, 48, 56, 58], fill=(60, 90, 55, 35))

	if kind == "tomato":
		ellipse_shaded(d, [14, 16, 50, 52], p["fruit"], p["fruit_h"], p["fruit_d"])
		for ox in (-8, 0, 8):
			d.polygon([(32, 18), (32 + ox, 7), (32 + ox // 2, 20)], fill=rgba(p["calyx"]))
	elif kind == "eggplant":
		ellipse_shaded(d, [20, 12, 44, 54], p["fruit"], p["fruit_h"], p["fruit_d"])
		d.ellipse([22, 8, 42, 20], fill=rgba(p["calyx"]))
	elif kind == "carrot":
		d.polygon([(32, 10), (46, 20), (38, 56), (26, 56), (18, 20)], fill=rgba(p["fruit"]))
		d.line([(30, 18), (29, 50)], fill=rgba(p["fruit_h"], 200), width=2)
		for ox in (-9, 0, 9):
			d.line([(32, 14), (32 + ox, 3)], fill=rgba(p["leaf"]), width=2)
	else:
		ellipse_shaded(d, [18, 16, 46, 52], p["fruit"], p["fruit_h"], p["fruit_d"])
		d.ellipse([26, 8, 38, 20], fill=rgba(p["calyx"]))

	return soft_outline(img)


# ── fonds ────────────────────────────────────────────────────


def make_sky() -> Image.Image:
	rng = random.Random(42)
	w, h = 1280, 720
	img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	px = img.load()

	for y in range(h):
		t = y / h
		if t < 0.35:
			c = mix((118, 178, 228), (168, 210, 242), t / 0.35)
		elif t < 0.52:
			c = mix((168, 210, 242), (210, 228, 200), (t - 0.35) / 0.17)
		elif t < 0.62:
			c = mix((190, 215, 165), (120, 168, 105), (t - 0.52) / 0.10)
		else:
			c = mix((105, 158, 95), (62, 118, 78), (t - 0.62) / 0.38)
		for x in range(w):
			n = rng.randint(-2, 2)
			# voile chaud soleil
			warm = max(0, int(18 * (1.0 - abs(x / w - 0.78) * 2.2) * max(0, 1.0 - t * 1.4)))
			px[x, y] = (clamp(c[0] + n + warm), clamp(c[1] + n + warm // 2), clamp(c[2] + n - warm // 3), 255)

	d = ImageDraw.Draw(img)

	# soleil doux
	sx, sy = 980, 110
	for r, a in ((90, 28), (60, 45), (36, 80), (22, 140)):
		d.ellipse([sx - r, sy - r, sx + r, sy + r], fill=(255, 236, 170, a))
	d.ellipse([sx - 18, sy - 18, sx + 18, sy + 18], fill=(255, 248, 210, 240))

	def soft_cloud(cx, cy, scale=1.0):
		parts = [(-34, 4, 30), (-10, -8, 36), (18, 0, 32), (40, 6, 22), (5, 10, 24)]
		for ox, oy, r in parts:
			rr = int(r * scale)
			d.ellipse(
				[cx + ox - rr, cy + oy - rr // 2, cx + ox + rr, cy + oy + rr // 2],
				fill=(255, 255, 255, 175),
			)
		for ox, oy, r in parts[:3]:
			rr = int(r * scale * 0.7)
			d.ellipse(
				[cx + ox - rr + 4, cy + oy - rr // 2 + 3, cx + ox + rr - 2, cy + oy + rr // 2 - 2],
				fill=(235, 245, 255, 90),
			)

	soft_cloud(160, 95, 1.1)
	soft_cloud(480, 70, 0.95)
	soft_cloud(720, 110, 0.75)
	soft_cloud(1100, 85, 0.85)

	# collines soft
	for layer, (base_y, amp, col_a, col_b, seed) in enumerate([
		(0.46, 32, (78, 148, 95), (58, 125, 78), 1.0),
		(0.54, 22, (68, 138, 88), (48, 112, 68), 2.2),
		(0.62, 14, (58, 122, 78), (42, 98, 60), 0.7),
	]):
		for x in range(w):
			hill = int(h * base_y + amp * math.sin(x * 0.008 + seed) + amp * 0.4 * math.sin(x * 0.023 + seed))
			for y in range(hill, h if layer == 2 else int(h * (base_y + 0.14))):
				if y >= h:
					break
				tt = (y - hill) / max(40, 1)
				c = mix(col_a, col_b, min(1.0, tt))
				if (x * 11 + y * 5 + layer * 3) % 29 == 0:
					c = (clamp(c[0] + 16), clamp(c[1] + 20), clamp(c[2] + 8))
				px[x, y] = (*c, 255)

	# serre moderne (structure verre)
	gx, gy = 720, int(h * 0.38)
	d.ellipse([gx + 20, gy + 118, gx + 280, gy + 142], fill=(35, 55, 40, 45))
	# toit
	d.polygon([(gx, gy + 78), (gx + 150, gy + 8), (gx + 300, gy + 78)], fill=(210, 235, 225, 200))
	d.polygon([(gx, gy + 78), (gx + 150, gy + 8), (gx + 300, gy + 78)], outline=(70, 115, 105, 255))
	# corps
	d.rectangle([gx + 14, gy + 78, gx + 286, gy + 128], fill=(175, 210, 200, 175))
	d.rectangle([gx + 14, gy + 78, gx + 286, gy + 128], outline=(65, 110, 100, 230))
	for mx in (gx + 80, gx + 150, gx + 220):
		d.line([(mx, gy + 78), (mx, gy + 128)], fill=(80, 125, 115, 200), width=2)
	d.line([(gx + 150, gy + 8), (gx + 150, gy + 78)], fill=(80, 125, 115, 210), width=2)
	# reflet
	d.line([(gx + 40, gy + 40), (gx + 95, gy + 68)], fill=(255, 255, 255, 140), width=3)
	d.line([(gx + 55, gy + 95), (gx + 55, gy + 118)], fill=(255, 255, 255, 70), width=2)

	# arbres
	for tx, tht in [(90, 48), (180, 38), (300, 52), (1180, 42), (1080, 36)]:
		by = int(h * 0.58)
		d.rectangle([tx - 4, by - 12, tx + 4, by + 2], fill=(88, 64, 40, 255))
		d.ellipse([tx - tht // 2, by - tht, tx + tht // 2, by - 2], fill=(48, 122, 68, 255))
		d.ellipse([tx - tht // 3, by - tht - 8, tx + tht // 4, by - tht // 2], fill=(72, 155, 88, 255))
		d.ellipse([tx - 6, by - tht // 2, tx + 10, by - 8], fill=(95, 175, 105, 120))

	# brume bas
	fog = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	fd = ImageDraw.Draw(fog)
	for i in range(6):
		yy = int(h * 0.55 + i * 18)
		fd.rectangle([0, yy, w, h], fill=(220, 235, 215, 12 + i * 4))
	img = Image.alpha_composite(img, fog)
	return img.filter(ImageFilter.SMOOTH_MORE)


def make_field() -> Image.Image:
	rng = random.Random(77)
	w, h = 800, 500
	img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	px = img.load()
	for y in range(h):
		t = y / h
		c = mix((198, 222, 168), (108, 158, 95), t)
		# léger dégradé radial chaud au centre
		for x in range(w):
			cx = abs(x / w - 0.5) * 2
			warm = int(12 * (1.0 - cx) * (1.0 - t * 0.5))
			n = rng.randint(-5, 5)
			furrow = 8 if ((x + int(y * 0.55)) % 36) < 2 else 0
			px[x, y] = (
				clamp(c[0] + n + warm - furrow),
				clamp(c[1] + n + warm // 2 - furrow // 2),
				clamp(c[2] + n // 2 - furrow // 3),
				255,
			)
	# herbe fine
	d = ImageDraw.Draw(img)
	for _ in range(320):
		x, y = rng.randint(0, w - 1), rng.randint(0, h - 1)
		col = (70 + rng.randint(0, 40), 140 + rng.randint(0, 40), 70 + rng.randint(0, 20), 180)
		d.line([(x, y), (x + rng.randint(-1, 1), y - rng.randint(2, 6))], fill=col, width=1)
	# cailloux discrets
	for _ in range(28):
		x, y = rng.randint(8, w - 8), rng.randint(8, h - 8)
		r = rng.randint(2, 5)
		base = rng.choice([(130, 125, 118), (110, 105, 98), (145, 138, 128)])
		d.ellipse([x - r, y - r, x + r, y + r], fill=(*base, 220))
		d.ellipse([x - r, y - r, x, y], fill=(clamp(base[0] + 25), clamp(base[1] + 25), clamp(base[2] + 20), 160))
	return img


def make_logo() -> Image.Image:
	img = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	d.ellipse([2, 2, 93, 93], fill=(232, 244, 228, 255), outline=(70, 130, 88, 255), width=3)
	# serre
	d.polygon([(22, 58), (48, 22), (74, 58)], fill=(190, 225, 215, 240), outline=(60, 110, 100, 255))
	d.rectangle([26, 58, 70, 74], fill=(155, 200, 190, 220), outline=(55, 105, 95, 255))
	d.line([(48, 22), (48, 58)], fill=(70, 120, 110, 220), width=2)
	d.line([(36, 38), (42, 48)], fill=(255, 255, 255, 160), width=2)
	# plante
	d.ellipse([38, 68, 58, 78], fill=(110, 80, 48, 255))
	d.line([(48, 70), (48, 48)], fill=(55, 130, 60, 255), width=3)
	d.ellipse([36, 42, 48, 54], fill=(85, 175, 80, 255))
	d.ellipse([48, 40, 60, 52], fill=(105, 195, 95, 255))
	# soleil
	d.ellipse([64, 18, 78, 32], fill=(255, 220, 100, 240))
	return soft_outline(img, (40, 70, 50, 180), 1)


def make_coin() -> Image.Image:
	img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	d.ellipse([4, 6, 42, 44], fill=(40, 50, 30, 50))
	ellipse_shaded(d, [4, 2, 44, 42], (232, 186, 55), (255, 230, 140), (170, 120, 30))
	d.ellipse([12, 10, 36, 34], outline=(190, 140, 40, 220), width=2)
	d.text((18, 12), "$", fill=(150, 100, 25, 255))  # fallback if no font metrics
	# dollar-like mark without relying on font
	d.rectangle([22, 12, 26, 32], fill=(180, 120, 30, 255))
	d.arc([14, 14, 34, 24], 20, 200, fill=(255, 240, 180, 255), width=3)
	d.arc([14, 22, 34, 32], 200, 20, fill=(180, 120, 30, 255), width=3)
	return soft_outline(img)


def make_sparkle() -> Image.Image:
	img = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	d.polygon([(20, 2), (23, 15), (38, 20), (23, 25), (20, 38), (17, 25), (2, 20), (17, 15)], fill=(255, 236, 120, 255))
	d.ellipse([14, 14, 26, 26], fill=(255, 255, 230, 230))
	return soft_outline(img, (160, 120, 40, 180))


def make_water_drop() -> Image.Image:
	img = Image.new("RGBA", (28, 28), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	d.polygon([(14, 2), (24, 16), (14, 26), (4, 16)], fill=(70, 170, 230, 230))
	d.ellipse([8, 12, 16, 20], fill=(180, 230, 255, 180))
	return soft_outline(img, (30, 80, 120, 180))


def save(img: Image.Image, path: Path) -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	img.save(path)
	print("wrote", path.relative_to(ROOT))


def main() -> None:
	for kind in CROPS:
		folder = TEX / "crops" / kind
		for stage in range(1, 5):
			save(draw_stage(kind, stage), folder / f"stage_{stage}.png")
		save(make_icon(kind), TEX / "icons" / f"{kind}.png")

	save(make_sky(), TEX / "backgrounds" / "sky.png")
	save(make_field(), TEX / "backgrounds" / "field.png")
	save(make_logo(), TEX / "ui" / "logo.png")
	save(make_coin(), TEX / "ui" / "coin.png")
	save(make_sparkle(), TEX / "ui" / "sparkle.png")
	save(make_water_drop(), TEX / "ui" / "water_drop.png")
	print("Done — visuals modernized.")


if __name__ == "__main__":
	main()
