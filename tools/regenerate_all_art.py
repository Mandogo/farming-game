"""Régénère TOUTES les textures du jeu dans le style détaillé des blocs terre.

Sorties structurées :
  blocks/grass/
  crops/<kind>/stage_N.png
  icons/<kind>.png
  ui/*.png
  backgrounds/sky.png , field.png

Usage : py tools/regenerate_all_art.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
TEX = ROOT / "assets" / "textures"

# ── helpers ──────────────────────────────────────────────────


def clamp(v: int, a: int = 0, b: int = 255) -> int:
	return max(a, min(b, v))


def shade(rgb, n: int):
	r, g, b = rgb[:3]
	return (clamp(r + n), clamp(g + n), clamp(b + n // 2), 255 if len(rgb) < 4 else rgb[3])


def put(px, x: int, y: int, c, w: int, h: int) -> None:
	if 0 <= x < w and 0 <= y < h:
		px[x, y] = c if len(c) == 4 else (*c[:3], 255)


def mix(a, b, t: float):
	return tuple(clamp(int(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def add_outline(src: Image.Image, color=(18, 12, 8, 235)) -> Image.Image:
	a = src.split()[-1]
	w, h = src.size
	alpha = a.load()
	outline = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	op = outline.load()
	for y in range(h):
		for x in range(w):
			if alpha[x, y] < 128:
				continue
			for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
				nx, ny = x + dx, y + dy
				if 0 <= nx < w and 0 <= ny < h and alpha[nx, ny] < 128:
					op[nx, ny] = color
	out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	out.alpha_composite(outline)
	out.alpha_composite(src)
	return out


def draw_pebble(px, cx, cy, r, rng, w, h, palette=None) -> None:
	base = palette or rng.choice([(128, 122, 114), (108, 98, 90), (148, 138, 126), (92, 86, 78)])
	edge = (32, 20, 12, 255)
	for dy in range(-r - 1, r + 2):
		for dx in range(-r - 1, r + 2):
			dist = math.sqrt(dx * dx + dy * dy)
			if dist > r + 0.6:
				continue
			if dist > r - 0.15:
				put(px, cx + dx, cy + dy, edge, w, h)
			else:
				n = 20 if dx + dy < -1 else (-14 if dx + dy > 1 else 0)
				put(px, cx + dx, cy + dy, shade(base, n), w, h)


# ── grass faces ──────────────────────────────────────────────


def make_grass_top(seed: int = 99) -> Image.Image:
	rng = random.Random(seed)
	n = 256
	base = (62, 128, 58)
	hi = (110, 175, 95)
	dk = (38, 90, 42)
	img = Image.new("RGBA", (n, n), (*base, 255))
	px = img.load()
	for y in range(n):
		for x in range(n):
			wave = int(12 * math.sin(x * 0.06 + seed) * math.cos(y * 0.05))
			px[x, y] = shade(base, rng.randint(-14, 12) + wave)

	# Touffes / mottes d'herbe
	cell = 36
	for gy in range(-4, n + cell, cell):
		for gx in range(-4, n + cell, cell):
			ox, oy = gx + rng.randint(-4, 4), gy + rng.randint(-4, 4)
			for y in range(max(0, oy), min(n, oy + cell)):
				for x in range(max(0, ox), min(n, ox + cell)):
					u = (x - (ox + cell / 2)) / (cell / 2)
					v = (y - (oy + cell / 2)) / (cell / 2)
					edge = abs(u) + abs(v)
					if edge > 1.0:
						continue
					lift = int((1 - edge) * 16)
					c = mix(base, hi, (lift + 6) / 28)
					put(px, x, y, shade(c, lift // 2 + rng.randint(-3, 3)), n, n)

	# Brins d'herbe individuels
	for _ in range(900):
		x, y = rng.randint(2, n - 3), rng.randint(4, n - 2)
		hgt = rng.randint(3, 7)
		col = rng.choice([(72, 150, 65), (50, 120, 48), (95, 170, 80), (40, 100, 40)])
		for i in range(hgt):
			lean = rng.choice([-1, 0, 0, 1]) if i > 2 else 0
			put(px, x + lean, y - i, shade(col, 8 if i == hgt - 1 else 0), n, n)
		put(px, x, y, (*dk, 255), n, n)

	# Fleurs / cailloux rares
	for _ in range(40):
		draw_pebble(px, rng.randint(8, n - 9), rng.randint(8, n - 9), rng.randint(2, 4), rng, n, n)
	for _ in range(25):
		fx, fy = rng.randint(6, n - 7), rng.randint(6, n - 7)
		fc = rng.choice([(240, 220, 90), (255, 160, 170), (250, 250, 255)])
		put(px, fx, fy, (*fc, 255), n, n)
		put(px, fx, fy - 1, shade(fc, -20), n, n)

	# Bord tuile
	for y in range(n):
		for x in range(n):
			ed = min(x, y, n - 1 - x, n - 1 - y)
			if ed < 6:
				t = 1 - ed / 6
				c = px[x, y]
				px[x, y] = (clamp(int(c[0] * (1 - 0.45 * t))), clamp(int(c[1] * (1 - 0.4 * t))), clamp(int(c[2] * (1 - 0.4 * t))), 255)
	return img


def make_grass_side(seed: int = 99) -> Image.Image:
	rng = random.Random(seed + 50)
	w, h = 256, 170
	img = Image.new("RGBA", (w, h), (48, 90, 45, 255))
	px = img.load()
	# Bande herbe en haut
	for y in range(h):
		for x in range(w):
			if y < 18:
				col = (70, 140, 60) if y < 8 else (55, 115, 50)
				px[x, y] = shade(col, rng.randint(-10, 10) + (8 - y))
			elif y < 50:
				t = (y - 18) / 32
				col = mix((90, 70, 45), (70, 48, 30), t)
				px[x, y] = shade(col, rng.randint(-8, 8))
			elif y < 100:
				t = (y - 50) / 50
				col = mix((70, 48, 30), (50, 34, 20), t)
				px[x, y] = shade(col, rng.randint(-8, 8))
			else:
				t = (y - 100) / max(h - 100, 1)
				col = mix((50, 34, 20), (36, 24, 14), t)
				px[x, y] = shade(col, rng.randint(-6, 6))

	for yb in (18, 50, 100):
		for x in range(w):
			yy = yb + int(2 * math.sin(x * 0.08)) + rng.randint(-1, 1)
			put(px, x, yy, (28, 18, 10, 255), w, h)

	for _ in range(20):
		draw_pebble(px, rng.randint(6, w - 7), rng.randint(30, h - 10), rng.randint(2, 4), rng, w, h)

	# Brins qui dépassent en haut
	for x in range(0, w, 3):
		if rng.random() < 0.55:
			hgt = rng.randint(4, 10)
			col = rng.choice([(80, 160, 70), (55, 130, 55)])
			for i in range(hgt):
				put(px, x + rng.choice([-1, 0, 1]), 10 - i, shade(col, i), w, h)

	for y in range(h):
		for x in (0, 1, w - 2, w - 1):
			c = px[x, y]
			px[x, y] = (clamp(int(c[0] * 0.55)), clamp(int(c[1] * 0.55)), clamp(int(c[2] * 0.55)), 255)
	return img


# ── crops ────────────────────────────────────────────────────

PALETTES = {
	"wheat": {
		"stem": (70, 145, 52), "stem_d": (38, 95, 32), "leaf": (120, 195, 80),
		"head": (220, 175, 48), "head_h": (248, 225, 120), "head_d": (175, 130, 35),
	},
	"barley": {
		"stem": (82, 155, 58), "stem_d": (45, 105, 36), "leaf": (140, 205, 95),
		"head": (232, 198, 100), "head_h": (252, 235, 160), "head_d": (190, 150, 70),
	},
	"oat": {
		"stem": (65, 140, 55), "stem_d": (35, 92, 34), "leaf": (118, 190, 100),
		"head": (220, 205, 155), "head_h": (245, 238, 200), "head_d": (175, 160, 110),
	},
	"corn": {
		"stem": (50, 130, 45), "stem_d": (28, 85, 30), "leaf": (105, 185, 78),
		"head": (242, 195, 45), "head_h": (255, 235, 110), "head_d": (190, 145, 30),
	},
}


def _stem(px, x, ground, h, lean, p, w, img_h, thick=1) -> None:
	for i in range(h):
		sx = x + (i // 7) * lean
		col = p["stem_d"] if i < 3 else p["stem"]
		put(px, sx, ground - i, shade(col, 0), w, img_h)
		if thick >= 2:
			put(px, sx - 1, ground - i, shade(p["stem"], 8), w, img_h)
		if thick >= 3:
			put(px, sx + 1, ground - i, shade(p["stem_d"], 0), w, img_h)


def _leaf(px, x, y, left: bool, p, w, h, size=4) -> None:
	d = -1 if left else 1
	for i in range(size):
		lx, ly = x + d * (i + 1), y - i // 2
		put(px, lx, ly, shade(p["leaf"] if i < 2 else p["stem"], 6 - i), w, h)
		put(px, lx, ly + 1, shade(p["stem_d"], 0), w, h)
		if i < size - 1:
			put(px, lx, ly - 1, shade(p["leaf"], 12), w, h)


def draw_crop_stage(kind: str, stage: int, seed: int = 0) -> Image.Image:
	"""Sprite 160×280 ancré au sol (y=171), détail enrichi."""
	rng = random.Random(hash((kind, stage, seed)) & 0xFFFFFFFF)
	w, h = 160, 280
	img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	px = img.load()
	p = PALETTES[kind]
	cx = w // 2
	ground = 171

	if stage == 1:
		for dx in (-14, -2, 12):
			x = cx + dx + rng.randint(-1, 1)
			# germe avec volume
			put(px, x, ground, shade(p["stem_d"], 0), w, h)
			put(px, x, ground - 1, shade(p["stem"], 0), w, h)
			put(px, x, ground - 2, shade(p["leaf"], 0), w, h)
			put(px, x, ground - 3, shade(p["leaf"], 15), w, h)
			put(px, x + 1, ground - 2, shade(p["stem"], 0), w, h)
			put(px, x - 1, ground - 1, shade(p["stem_d"], 0), w, h)
		return add_outline(img)

	if stage == 2:
		for dx in (-20, 0, 20):
			x = cx + dx
			_stem(px, x, ground, 9, 0, p, w, h, thick=2)
			_leaf(px, x, ground - 6, True, p, w, h, 4)
			_leaf(px, x, ground - 5, False, p, w, h, 3)
			put(px, x, ground - 9, shade(p["leaf"], 18), w, h)
			put(px, x + 1, ground - 9, shade(p["leaf"], 5), w, h)
		return add_outline(img)

	# stages 3–4
	if kind == "wheat":
		xs = [-28, -10, 8, 26] if stage == 4 else [-20, -2, 16]
		hh = 38 if stage == 4 else 26
		for dx in xs:
			x = cx + dx + rng.randint(-1, 1)
			lean = 1 if dx > 4 else (-1 if dx < -4 else 0)
			_stem(px, x, ground, hh, lean, p, w, h, thick=2)
			for li in range(4, hh - 10, 5):
				_leaf(px, x + (li // 7) * lean, ground - li, li % 10 < 5, p, w, h, 3)
			top = ground - hh
			ear_h = 12 if stage == 4 else 7
			for i in range(ear_h):
				yy = top + i
				sx = x + lean
				put(px, sx, yy, shade(p["head"], 0), w, h)
				put(px, sx - 1, yy, shade(p["head_h"] if i % 2 == 0 else p["head"], 0), w, h)
				put(px, sx + 1, yy, shade(p["head_d"] if i % 2 else p["head"], 0), w, h)
				if stage == 4 and i % 2 == 0:
					put(px, sx - 2, yy, shade(p["head_d"], 0), w, h)
			if stage == 4:
				for bx in (-1, 0, 1):
					put(px, x + lean + bx, top - 1, shade(p["head_d"], 0), w, h)
					put(px, x + lean + bx, top - 2, shade(p["head_d"], -10), w, h)
				put(px, x + lean, top - 3, shade(p["head_d"], -15), w, h)

	elif kind == "barley":
		xs = [-28, -10, 8, 26] if stage == 4 else [-18, 0, 18]
		for dx in xs:
			x = cx + dx
			lean = 1 if dx >= 0 else -1
			hh = 32 if stage == 4 else 22
			_stem(px, x, ground, hh, lean, p, w, h, thick=2)
			_leaf(px, x, ground - hh // 2, True, p, w, h, 3)
			_leaf(px, x, ground - hh // 3, False, p, w, h, 3)
			top = ground - hh
			for oy2 in range(8 if stage == 4 else 5):
				for ox in range(-3, 4):
					if abs(ox) == 3 and oy2 in (0, 7):
						continue
					col = p["head_h"] if abs(ox) < 2 and oy2 % 2 == 0 else p["head"]
					if abs(ox) == 3:
						col = p["head_d"]
					put(px, x + lean + ox, top + oy2, shade(col, 0), w, h)
			awn = 7 if stage == 4 else 4
			for bx in range(-4, 5):
				for by in range(1, awn):
					if abs(bx) + by // 2 > 5:
						continue
					put(px, x + lean + bx, top - by, shade(p["head_d"] if by > 3 else p["head"], -by * 2), w, h)

	elif kind == "oat":
		xs = [-26, -8, 10, 26] if stage == 4 else [-18, 0, 18]
		for dx in xs:
			x = cx + dx
			hh = 28 if stage == 4 else 20
			_stem(px, x, ground, hh, 0, p, w, h, thick=2)
			_leaf(px, x, ground - hh // 2, True, p, w, h, 3)
			top = ground - hh
			clusters = [(-5, 0), (5, 0), (0, -4), (-4, -4), (4, -4), (-3, 3), (3, 3)]
			if stage == 4:
				clusters += [(-7, -6), (7, -6), (0, -8), (-6, 2), (6, 2), (-2, -7), (2, -7)]
			for ox, oy2 in clusters:
				put(px, x + ox, top + oy2, shade(p["head"], 0), w, h)
				put(px, x + ox, top + oy2 - 1, shade(p["head_h"], 0), w, h)
				put(px, x + ox + 1, top + oy2, shade(p["head_d"], 0), w, h)
				put(px, x + ox - 1, top + oy2, shade(p["head"], -8), w, h)

	else:  # corn
		xs = [-24, 0, 24] if stage == 4 else [-18, 18]
		for dx in xs:
			x = cx + dx
			hh = 48 if stage == 4 else 34
			_stem(px, x, ground, hh, 0, p, w, h, thick=3)
			for li, ly in enumerate([hh // 5, hh // 2, (3 * hh) // 4]):
				yy = ground - ly
				for side in (-1, 1):
					for j in range(7 + (li % 2)):
						lx = x + side * (2 + j)
						ly2 = yy - j // 2
						put(px, lx, ly2, shade(p["leaf"] if j < 3 else p["stem"], 4), w, h)
						put(px, lx, ly2 + 1, shade(p["stem_d"], 0), w, h)
						put(px, lx, ly2 - 1, shade(p["leaf"], 12), w, h)
			ey = ground - hh // 2 - 2
			husk = (48, 115, 42)
			eh = 14 if stage == 4 else 10
			for yy in range(eh):
				for xx in range(6):
					if xx in (0, 5):
						put(px, x + 2 + xx, ey + yy, shade(husk, 0), w, h)
					else:
						col = p["head_h"] if (xx + yy) % 2 == 0 else p["head"]
						put(px, x + 2 + xx, ey + yy, shade(col, 0), w, h)
			if stage == 4:
				for s in range(5):
					put(px, x + 4 + (s % 2), ey - 1 - s, shade((235, 220, 140), 0), w, h)
					put(px, x + 5, ey - 2 - s, shade((220, 200, 120), 0), w, h)

	return add_outline(img)


def make_crop_icon(kind: str) -> Image.Image:
	rng = random.Random(hash(kind) & 0xFFFF)
	img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	# badge
	d.rounded_rectangle([2, 2, 61, 61], radius=12, fill=(42, 72, 48, 255), outline=(22, 40, 26, 255), width=2)
	d.rounded_rectangle([5, 5, 58, 28], radius=8, fill=(70, 120, 78, 70))
	# mini terre
	d.polygon([(32, 42), (52, 50), (32, 58), (12, 50)], fill=(118, 80, 48, 255), outline=(60, 38, 22, 255))
	p = PALETTES[kind]
	# plante
	plant = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
	pp = plant.load()
	if kind == "corn":
		_stem(pp, 28, 52, 28, 0, p, 64, 64, 3)
		for yy in range(12):
			for xx in range(5):
				put(pp, 32 + xx, 22 + yy, shade(p["head"] if (xx + yy) % 2 else p["head_h"], 0), 64, 64)
		_leaf(pp, 28, 40, True, p, 64, 64, 5)
		_leaf(pp, 28, 34, False, p, 64, 64, 5)
	elif kind == "oat":
		_stem(pp, 32, 54, 22, 0, p, 64, 64, 2)
		for ox, oy in [(-6, 0), (6, 0), (0, -5), (-4, -4), (4, -4), (-5, 3), (5, 3)]:
			put(pp, 32 + ox, 28 + oy, shade(p["head"], 0), 64, 64)
			put(pp, 32 + ox, 27 + oy, shade(p["head_h"], 0), 64, 64)
	elif kind == "barley":
		_stem(pp, 30, 54, 24, 1, p, 64, 64, 2)
		for oy in range(10):
			for ox in range(-3, 4):
				put(pp, 32 + ox, 24 + oy, shade(p["head_h"] if abs(ox) < 2 else p["head"], 0), 64, 64)
		for bx in range(-3, 4):
			put(pp, 32 + bx, 22, shade(p["head_d"], 0), 64, 64)
			put(pp, 32 + bx, 20, shade(p["head_d"], -8), 64, 64)
	else:
		_stem(pp, 32, 54, 24, 0, p, 64, 64, 2)
		_leaf(pp, 32, 42, True, p, 64, 64, 4)
		for i in range(10):
			put(pp, 32, 22 + i, shade(p["head"], 0), 64, 64)
			put(pp, 31, 22 + i, shade(p["head_h"] if i % 2 == 0 else p["head"], 0), 64, 64)
			put(pp, 33, 22 + i, shade(p["head_d"], 0), 64, 64)
		put(pp, 32, 20, shade(p["head_d"], 0), 64, 64)
	img.alpha_composite(add_outline(plant, (12, 8, 5, 230)))
	_ = rng
	return img


# ── UI icons ─────────────────────────────────────────────────


def _ui_canvas(size=48) -> tuple[Image.Image, ImageDraw.ImageDraw]:
	img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	return img, ImageDraw.Draw(img)


def icon_coin() -> Image.Image:
	img, d = _ui_canvas()
	d.ellipse([4, 4, 43, 43], fill=(150, 105, 25, 255))
	d.ellipse([6, 6, 41, 41], fill=(235, 185, 45, 255), outline=(160, 110, 20, 255), width=2)
	d.ellipse([12, 12, 35, 35], fill=(255, 220, 90, 255))
	d.ellipse([14, 13, 24, 22], fill=(255, 245, 180, 200))
	d.line([(24, 14), (24, 34)], fill=(150, 100, 20, 255), width=2)
	d.arc([18, 16, 30, 26], 200, 20, fill=(150, 100, 20, 255), width=2)
	d.arc([18, 24, 30, 34], 20, 200, fill=(150, 100, 20, 255), width=2)
	return add_outline(img, (40, 25, 8, 220))


def icon_seed_bag() -> Image.Image:
	img, d = _ui_canvas()
	d.polygon([(10, 16), (38, 16), (42, 42), (6, 42)], fill=(168, 118, 58, 255), outline=(95, 65, 32, 255), width=2)
	d.rectangle([16, 8, 32, 18], fill=(140, 95, 45, 255), outline=(90, 60, 28, 255))
	d.line([(16, 12), (32, 12)], fill=(90, 60, 28, 255), width=1)
	# graines
	for cx, cy, col in [(18, 24, (240, 200, 70)), (28, 26, (90, 170, 55)), (22, 32, (250, 220, 90)), (30, 34, (70, 150, 48))]:
		d.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=(*col, 255), outline=(40, 30, 15, 255))
	return add_outline(img)


def icon_scythe() -> Image.Image:
	img, d = _ui_canvas()
	d.line([(10, 42), (28, 12)], fill=(100, 65, 35, 255), width=5)
	d.line([(10, 42), (28, 12)], fill=(155, 105, 55, 255), width=2)
	d.arc([14, 4, 44, 32], 195, 55, fill=(200, 210, 225, 255), width=5)
	d.arc([18, 8, 40, 28], 200, 45, fill=(245, 250, 255, 255), width=2)
	return add_outline(img)


def icon_heat() -> Image.Image:
	img, d = _ui_canvas()
	d.polygon([(24, 4), (36, 22), (28, 22), (34, 44), (12, 20), (22, 20)], fill=(255, 130, 35, 255), outline=(180, 70, 15, 255), width=2)
	d.polygon([(24, 12), (30, 24), (26, 24), (28, 36), (18, 22), (24, 22)], fill=(255, 220, 80, 255))
	return add_outline(img, (80, 30, 10, 220))


def icon_mission() -> Image.Image:
	img, d = _ui_canvas()
	d.rounded_rectangle([8, 4, 40, 44], radius=3, fill=(248, 238, 205, 255), outline=(110, 90, 55, 255), width=2)
	d.rectangle([14, 12, 34, 16], fill=(80, 150, 75, 255))
	d.rectangle([14, 22, 34, 26], fill=(160, 140, 95, 255))
	d.rectangle([14, 32, 28, 36], fill=(160, 140, 95, 255))
	d.polygon([(30, 2), (38, 2), (38, 14), (34, 10), (30, 14)], fill=(200, 60, 55, 255), outline=(120, 30, 25, 255))
	return add_outline(img)


def icon_upgrade() -> Image.Image:
	img, d = _ui_canvas()
	d.polygon([(24, 6), (40, 22), (32, 22), (32, 42), (16, 42), (16, 22), (8, 22)], fill=(70, 185, 115, 255), outline=(35, 110, 65, 255), width=2)
	d.polygon([(24, 12), (34, 22), (28, 22), (28, 36), (20, 36), (20, 22), (14, 22)], fill=(140, 230, 170, 255))
	return add_outline(img)


def icon_prestige() -> Image.Image:
	img, d = _ui_canvas()
	pts = []
	for i in range(10):
		ang = math.radians(-90 + i * 36)
		r = 18 if i % 2 == 0 else 8
		pts.append((24 + r * math.cos(ang), 24 + r * math.sin(ang)))
	d.polygon(pts, fill=(255, 210, 70, 255), outline=(170, 120, 25, 255), width=2)
	d.ellipse([18, 18, 30, 30], fill=(255, 245, 180, 255))
	return add_outline(img, (90, 60, 15, 220))


def icon_waterer() -> Image.Image:
	img, d = _ui_canvas()
	d.ellipse([10, 18, 34, 42], fill=(65, 155, 215, 255), outline=(35, 95, 150, 255), width=2)
	d.ellipse([14, 22, 24, 30], fill=(160, 220, 255, 180))
	d.polygon([(28, 14), (42, 10), (40, 18), (30, 20)], fill=(90, 100, 110, 255), outline=(50, 55, 60, 255))
	for i, yy in enumerate((8, 14, 20)):
		d.ellipse([38, yy, 42, yy + 5], fill=(100, 190, 255, 200 - i * 40))
	return add_outline(img)


def icon_harvester() -> Image.Image:
	img, d = _ui_canvas()
	d.rounded_rectangle([8, 20, 36, 36], radius=3, fill=(85, 140, 70, 255), outline=(45, 85, 40, 255), width=2)
	d.ellipse([28, 14, 44, 30], fill=(70, 75, 80, 255), outline=(40, 45, 50, 255), width=2)
	d.ellipse([32, 18, 40, 26], fill=(110, 115, 120, 255))
	d.rectangle([12, 14, 20, 22], fill=(200, 180, 60, 255), outline=(120, 100, 30, 255))
	return add_outline(img)


def icon_planter() -> Image.Image:
	img, d = _ui_canvas()
	d.polygon([(8, 38), (24, 16), (40, 38)], fill=(135, 95, 50, 255), outline=(85, 55, 28, 255), width=2)
	d.ellipse([18, 8, 30, 20], fill=(75, 175, 65, 255), outline=(40, 100, 35, 255), width=2)
	d.ellipse([20, 10, 26, 16], fill=(140, 220, 100, 255))
	return add_outline(img)


def icon_sparkle() -> Image.Image:
	img, d = _ui_canvas(32)
	d.polygon([(16, 2), (19, 12), (30, 16), (19, 20), (16, 30), (13, 20), (2, 16), (13, 12)], fill=(255, 240, 120, 255), outline=(180, 140, 40, 255))
	d.ellipse([12, 12, 20, 20], fill=(255, 255, 220, 255))
	return add_outline(img, (100, 70, 20, 200))


def icon_corner() -> Image.Image:
	img, d = _ui_canvas(32)
	d.polygon([(0, 0), (31, 0), (0, 31)], fill=(145, 105, 55, 255))
	d.line([(0, 0), (31, 0)], fill=(210, 170, 100, 255), width=2)
	d.line([(0, 0), (0, 31)], fill=(95, 65, 35, 255), width=2)
	return img


def icon_mouse(left: bool) -> Image.Image:
	img, d = _ui_canvas(32)
	d.rounded_rectangle([6, 2, 25, 29], radius=7, fill=(48, 52, 58, 255), outline=(190, 195, 200, 255), width=2)
	if left:
		d.rectangle([6, 2, 15, 14], fill=(85, 200, 110, 255))
	else:
		d.rectangle([16, 2, 25, 14], fill=(240, 190, 70, 255))
	d.line([(16, 2), (16, 14)], fill=(190, 195, 200, 255), width=1)
	return add_outline(img)


def icon_combo() -> Image.Image:
	img, d = _ui_canvas()
	d.polygon([(8, 38), (18, 8), (26, 8), (16, 38)], fill=(255, 200, 50, 255), outline=(170, 110, 20, 255), width=2)
	d.polygon([(20, 38), (30, 8), (38, 8), (28, 38)], fill=(255, 155, 40, 255), outline=(170, 90, 20, 255), width=2)
	return add_outline(img)


# ── backgrounds ──────────────────────────────────────────────


def make_sky() -> Image.Image:
	rng = random.Random(2024)
	w, h = 960, 540
	img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	px = img.load()
	for y in range(h):
		t = y / h
		if t < 0.4:
			c = mix((115, 180, 235), (175, 220, 250), t / 0.4)
		elif t < 0.55:
			c = mix((175, 220, 250), (200, 228, 190), (t - 0.4) / 0.15)
		else:
			c = mix((150, 195, 125), (68, 130, 78), (t - 0.55) / 0.45)
		for x in range(w):
			n = rng.randint(-3, 3) + int(3 * math.sin(x * 0.008 + y * 0.01))
			px[x, y] = (clamp(c[0] + n), clamp(c[1] + n // 2), clamp(c[2]), 255)

	d = ImageDraw.Draw(img)

	def cloud(cx, cy, parts):
		for ox, oy, r in parts:
			d.ellipse([cx + ox - r, cy + oy - r // 2, cx + ox + r, cy + oy + r // 2], fill=(255, 255, 255, 200))
			d.ellipse([cx + ox - r + 3, cy + oy - r // 2 + 2, cx + ox + r - 4, cy + oy + r // 2 - 3], fill=(240, 248, 255, 160))

	cloud(120, 70, [(-28, 6, 26), (0, 0, 32), (30, 5, 22), (10, -10, 18)])
	cloud(420, 90, [(-34, 4, 28), (0, -4, 34), (36, 6, 24), (-10, -12, 16)])
	cloud(720, 55, [(-22, 3, 22), (6, 0, 28), (32, 5, 18)])
	cloud(860, 100, [(-16, 0, 18), (12, 3, 20)])

	# soleil
	sx, sy = 780, 80
	for r, a in ((48, 35), (34, 60), (22, 110)):
		d.ellipse([sx - r, sy - r, sx + r, sy + r], fill=(255, 240, 160, a))
	d.ellipse([sx - 16, sy - 16, sx + 16, sy + 16], fill=(255, 250, 200, 235))

	# collines texturées
	for x in range(w):
		hill = int(h * 0.48 + 28 * math.sin(x * 0.01) + 14 * math.sin(x * 0.028))
		for y in range(hill, int(h * 0.58)):
			sh = 14 if y <= hill + 2 else 0
			px[x, y] = (55 + sh, 118 + sh, 72 + sh, 255)
	for x in range(w):
		hill = int(h * 0.55 + 18 * math.sin(x * 0.018 + 1.1) + 10 * math.sin(x * 0.05))
		for y in range(hill, h):
			t = (y - hill) / max(h - hill, 1)
			base = mix((75, 148, 85), (45, 105, 58), t)
			if (x * 13 + y * 7) % 17 == 0:
				base = (clamp(base[0] + 18), clamp(base[1] + 22), clamp(base[2] + 8))
			px[x, y] = (*base, 255)

	# serre
	gx, gy = 600, int(h * 0.42)
	d.ellipse([gx + 30, gy + 100, gx + 250, gy + 120], fill=(30, 55, 32, 50))
	d.polygon([(gx, gy + 70), (gx + 130, gy + 10), (gx + 260, gy + 70)], fill=(195, 225, 215, 210), outline=(80, 120, 110, 255))
	d.rectangle([gx + 12, gy + 70, gx + 248, gy + 112], fill=(165, 200, 190, 190), outline=(70, 110, 100, 255))
	for mx in (gx + 70, gx + 130, gx + 190):
		d.line([(mx, gy + 70), (mx, gy + 112)], fill=(90, 130, 120, 210), width=2)
	d.line([(gx + 130, gy + 10), (gx + 130, gy + 70)], fill=(90, 130, 120, 220), width=2)
	d.line([(gx + 40, gy + 42), (gx + 80, gy + 60)], fill=(255, 255, 255, 130), width=2)

	# arbres
	for tx, tht in [(80, 40), (160, 32), (280, 44), (880, 36)]:
		by = int(h * 0.56)
		d.rectangle([tx - 3, by - 10, tx + 3, by], fill=(90, 68, 42, 255))
		d.ellipse([tx - tht // 3, by - tht, tx + tht // 3, by - 4], fill=(48, 118, 62, 255))
		d.ellipse([tx - tht // 4, by - tht - 6, tx + tht // 5, by - tht // 2], fill=(70, 150, 80, 255))
	return img


def make_field() -> Image.Image:
	"""Fond champ : prairie douce texturée (pas violet)."""
	rng = random.Random(88)
	w, h = 640, 400
	img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	px = img.load()
	for y in range(h):
		t = y / h
		c = mix((185, 220, 160), (95, 155, 90), t)
		for x in range(w):
			n = rng.randint(-8, 8)
			# sillons diagonaux légers
			furrow = 10 if ((x + y // 2) % 28) < 3 else 0
			px[x, y] = (clamp(c[0] + n - furrow), clamp(c[1] + n - furrow // 2), clamp(c[2] + n // 2), 255)

	for _ in range(200):
		x, y = rng.randint(0, w - 1), rng.randint(0, h - 1)
		put(px, x, y, shade((70, 140, 60), rng.randint(0, 20)), w, h)
	for _ in range(40):
		draw_pebble(px, rng.randint(5, w - 6), rng.randint(5, h - 6), rng.randint(2, 5), rng, w, h)
	return img


# ── main ─────────────────────────────────────────────────────


def save(img: Image.Image, path: Path) -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	img.save(path)
	print("wrote", path.relative_to(ROOT))


def main() -> None:
	# Herbe
	save(make_grass_top(), TEX / "blocks" / "grass" / "top.png")
	save(make_grass_side(), TEX / "blocks" / "grass" / "side.png")

	# Cultures (légumes) — générateur dédié pour silhouettes lisibles
	from generate_veggie_crops import draw_stage as veg_stage, make_icon as veg_icon, CROPS as VEG_CROPS
	for kind in VEG_CROPS:
		folder = TEX / "crops" / kind
		for stage in range(1, 5):
			save(veg_stage(kind, stage), folder / f"stage_{stage}.png")
		save(veg_icon(kind), TEX / "icons" / f"{kind}.png")

	# UI
	ui = {
		"coin": icon_coin,
		"seed_bag": icon_seed_bag,
		"scythe": icon_scythe,
		"heat": icon_heat,
		"mission": icon_mission,
		"upgrade": icon_upgrade,
		"prestige": icon_prestige,
		"waterer": icon_waterer,
		"harvester": icon_harvester,
		"planter": icon_planter,
		"sparkle": icon_sparkle,
		"corner": icon_corner,
		"combo": icon_combo,
		"mouse_left": lambda: icon_mouse(True),
		"mouse_right": lambda: icon_mouse(False),
	}
	for name, fn in ui.items():
		save(fn(), TEX / "ui" / f"{name}.png")

	# Fonds
	save(make_sky(), TEX / "backgrounds" / "sky.png")
	save(make_field(), TEX / "backgrounds" / "field.png")

	# Passe moderne (cultures + ciel + logo plus riches)
	try:
		from modernize_visuals import main as modernize_main
		modernize_main()
	except Exception as e:
		print("modernize_visuals skipped:", e)

	print("Done — all art regenerated.")


if __name__ == "__main__":
	main()
