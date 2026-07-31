"""Génère des faces terre style tuiles plateforme (variantes + détail).

Sortie :
  blocks/soil/     top.png + side.png
  blocks/soil_b/   …
  blocks/soil_c/   …
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BLOCKS = ROOT / "assets" / "textures" / "blocks"

TOP_N = 256
SIDE_W, SIDE_H = 256, 170

TOP_BASE = (108, 74, 46)
EDGE = (32, 20, 12)
CRACK = (48, 30, 18)
HIGH = (158, 118, 78)

SIDE_TOP = (96, 64, 40)
SIDE_MID = (70, 46, 28)
SIDE_DEEP = (44, 28, 18)


def clamp(v: int, a: int = 0, b: int = 255) -> int:
	return max(a, min(b, v))


def shade(rgb: tuple[int, int, int], n: int) -> tuple[int, int, int, int]:
	return (clamp(rgb[0] + n), clamp(rgb[1] + n), clamp(rgb[2] + n // 2), 255)


def mix_rgb(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
	return (
		clamp(int(a[0] + (b[0] - a[0]) * t)),
		clamp(int(a[1] + (b[1] - a[1]) * t)),
		clamp(int(a[2] + (b[2] - a[2]) * t)),
	)


def put(px, x: int, y: int, c, w: int, h: int) -> None:
	if 0 <= x < w and 0 <= y < h:
		px[x, y] = c if len(c) == 4 else (*c[:3], 255)


def draw_pebble(px, cx: int, cy: int, r: int, rng: random.Random, w: int, h: int) -> None:
	base = rng.choice([(128, 122, 114), (108, 98, 90), (148, 138, 126), (92, 86, 78)])
	for dy in range(-r - 1, r + 2):
		for dx in range(-r - 1, r + 2):
			dist = math.sqrt(dx * dx + dy * dy)
			if dist > r + 0.6:
				continue
			if dist > r - 0.2:
				put(px, cx + dx, cy + dy, (*EDGE, 255), w, h)
				continue
			n = 22 if dx + dy < -1 else (-16 if dx + dy > 1 else 0)
			put(px, cx + dx, cy + dy, shade(base, n), w, h)


def stroke_channel(
	px, x0: int, y0: int, x1: int, y1: int, rng: random.Random, w: int, h: int, width: int = 3
) -> None:
	"""Sillon entre mottes : ombre + fond + highlight (relief plateforme)."""
	steps = max(abs(x1 - x0), abs(y1 - y0), 1)
	for i in range(steps + 1):
		t = i / steps
		tx = x0 + (x1 - x0) * t + rng.uniform(-0.8, 0.8)
		ty = y0 + (y1 - y0) * t + rng.uniform(-0.8, 0.8)
		ix, iy = int(tx), int(ty)
		# direction perpendiculaire approximative
		dx = x1 - x0
		dy = y1 - y0
		length = math.hypot(dx, dy) or 1.0
		nx, ny = -dy / length, dx / length
		for k in range(-width, width + 1):
			px_x = int(round(ix + nx * k))
			px_y = int(round(iy + ny * k))
			ak = abs(k) / max(width, 1)
			if k < 0:
				col = shade(EDGE, int(10 * (1 - ak)))
			elif k > 0:
				col = shade(HIGH, int(-25 * ak))
			else:
				col = (*CRACK, 255)
			put(px, px_x, px_y, col, w, h)


def fill_clump(
	px, x0: int, y0: int, x1: int, y1: int, rng: random.Random, w: int, h: int, seed: int
) -> None:
	"""Motte relevée : plus claire au centre, plus sombre aux bords."""
	cx = (x0 + x1) * 0.5
	cy = (y0 + y1) * 0.5
	hw = max((x1 - x0) * 0.5, 1)
	hh = max((y1 - y0) * 0.5, 1)
	base_n = rng.randint(-6, 10)
	for y in range(max(0, y0), min(h, y1)):
		for x in range(max(0, x0), min(w, x1)):
			u = (x - cx) / hw
			v = (y - cy) / hh
			# losange soft pour coller à l'iso
			edge = abs(u) + abs(v)
			if edge > 1.05:
				continue
			lift = (1.0 - edge) * 18 + base_n + rng.randint(-4, 4)
			# grain
			if (x * 17 + y * 31 + seed) % 11 == 0:
				lift -= 8
			t = max(0.0, min(1.0, (lift + 8) / 36.0))
			c = mix_rgb(TOP_BASE, HIGH, t)
			put(px, x, y, shade(c, int(lift * 0.35)), w, h)


def make_top(seed: int) -> Image.Image:
	rng = random.Random(seed)
	img = Image.new("RGBA", (TOP_N, TOP_N), (*TOP_BASE, 255))
	px = img.load()

	# Fond grainé
	for y in range(TOP_N):
		for x in range(TOP_N):
			n = rng.randint(-14, 12)
			wave = int(8 * math.sin((x + seed) * 0.05) * math.cos(y * 0.045))
			px[x, y] = shade(TOP_BASE, n + wave)

	# Grille de mottes irrégulières
	cell = 48
	cells: list[tuple[int, int, int, int]] = []
	for gy in range(-8, TOP_N + cell, cell):
		for gx in range(-8, TOP_N + cell, cell):
			ox = gx + rng.randint(-5, 5)
			oy = gy + rng.randint(-5, 5)
			cw = cell + rng.randint(-6, 10)
			ch = cell + rng.randint(-6, 10)
			cells.append((ox, oy, ox + cw, oy + ch))
			fill_clump(px, ox + 2, oy + 2, ox + cw - 2, oy + ch - 2, rng, TOP_N, TOP_N, seed)

	# Sillons profonds entre mottes
	for ox, oy, x1, y1 in cells:
		if rng.random() < 0.9:
			stroke_channel(px, ox, oy + (y1 - oy) // 2, x1, oy + (y1 - oy) // 2 + rng.randint(-3, 3), rng, TOP_N, TOP_N, 2)
		if rng.random() < 0.9:
			stroke_channel(px, ox + (x1 - ox) // 2, oy, ox + (x1 - ox) // 2 + rng.randint(-3, 3), y1, rng, TOP_N, TOP_N, 2)

	# Cailloux dans / sur les sillons
	for _ in range(36):
		draw_pebble(px, rng.randint(10, TOP_N - 11), rng.randint(10, TOP_N - 11), rng.randint(2, 6), rng, TOP_N, TOP_N)

	# Brindilles
	d = ImageDraw.Draw(img)
	for _ in range(16):
		x0, y0 = rng.randint(12, TOP_N - 12), rng.randint(12, TOP_N - 12)
		x1 = x0 + rng.randint(-22, 22)
		y1 = y0 + rng.randint(-12, 12)
		d.line([(x0, y0), (x1, y1)], fill=shade((88, 68, 42), rng.randint(-8, 6)), width=1)

	# Touffes d'herbe plus visibles
	for _ in range(30):
		gx, gy = rng.randint(6, TOP_N - 7), rng.randint(6, TOP_N - 7)
		gcol = rng.choice([(68, 128, 52), (52, 108, 42), (88, 148, 68)])
		put(px, gx, gy, (*EDGE, 255), TOP_N, TOP_N)
		put(px, gx, gy - 1, (*gcol, 255), TOP_N, TOP_N)
		put(px, gx, gy - 2, shade(gcol, 18), TOP_N, TOP_N)
		if rng.random() < 0.55:
			put(px, gx + 1, gy - 1, (*gcol, 255), TOP_N, TOP_N)
			put(px, gx - 1, gy - 1, shade(gcol, -10), TOP_N, TOP_N)

	# Cadre tuile (bord sombre)
	rim = 7
	for y in range(TOP_N):
		for x in range(TOP_N):
			edge_d = min(x, y, TOP_N - 1 - x, TOP_N - 1 - y)
			if edge_d >= rim:
				continue
			t = 1.0 - edge_d / rim
			c = px[x, y]
			px[x, y] = (
				clamp(int(c[0] * (1 - 0.5 * t))),
				clamp(int(c[1] * (1 - 0.5 * t))),
				clamp(int(c[2] * (1 - 0.45 * t))),
				255,
			)

	return img


def make_side(seed: int) -> Image.Image:
	rng = random.Random(seed + 1000)
	img = Image.new("RGBA", (SIDE_W, SIDE_H), (*SIDE_MID, 255))
	px = img.load()

	layer_ys = [0, 26, 55, 90, 128, SIDE_H]
	layer_cols = [SIDE_TOP, (104, 74, 46), SIDE_MID, (58, 40, 26), SIDE_DEEP]

	for li in range(len(layer_cols)):
		y0 = layer_ys[li]
		y1 = layer_ys[li + 1]
		base = layer_cols[li]
		for y in range(y0, y1):
			t = (y - y0) / max(y1 - y0, 1)
			for x in range(SIDE_W):
				wave = int(5 * math.sin(x * 0.035 + li + seed * 0.07))
				# « briques » verticales irrégulières
				brick = 14 if ((x + li * 9) // 28) % 2 == 0 else 0
				n = rng.randint(-9, 9) + int(-10 * t) + wave - brick // 3
				px[x, y] = shade(base, n)

	# Joints horizontaux épais entre strates
	for li, yb in enumerate(layer_ys[1:-1]):
		for x in range(SIDE_W):
			yy = yb + int(3 * math.sin(x * 0.08 + li)) + rng.randint(-1, 1)
			put(px, x, yy - 1, shade(HIGH, -30), SIDE_W, SIDE_H)
			put(px, x, yy, (*EDGE, 255), SIDE_W, SIDE_H)
			put(px, x, yy + 1, shade(CRACK, 8), SIDE_W, SIDE_H)
			if rng.random() < 0.25:
				draw_pebble(px, x, yy + rng.randint(2, 6), rng.randint(2, 3), rng, SIDE_W, SIDE_H)

	# Joints verticaux (blocs côte à côte)
	for vx in range(20, SIDE_W, 36):
		ox = vx + rng.randint(-4, 4)
		for y in range(SIDE_H):
			if rng.random() < 0.15:
				continue
			put(px, ox, y, shade(EDGE, rng.randint(0, 8)), SIDE_W, SIDE_H)
			put(px, ox + 1, y, shade(HIGH, -35), SIDE_W, SIDE_H)

	for _ in range(22):
		draw_pebble(px, rng.randint(8, SIDE_W - 9), rng.randint(18, SIDE_H - 10), rng.randint(2, 5), rng, SIDE_W, SIDE_H)

	d = ImageDraw.Draw(img)
	for _ in range(12):
		x0 = rng.randint(0, SIDE_W - 1)
		y0 = rng.randint(6, 45)
		pts = [(x0, y0)]
		x, y = x0, y0
		for _s in range(rng.randint(3, 7)):
			x += rng.randint(-7, 7)
			y += rng.randint(5, 14)
			pts.append((clamp(x, 0, SIDE_W - 1), clamp(y, 0, SIDE_H - 1)))
		d.line(pts, fill=shade((118, 98, 68), -4), width=1)

	# Bande sous le dessus
	for y in range(0, 7):
		for x in range(SIDE_W):
			c = px[x, y]
			f = 0.5 + y * 0.07
			px[x, y] = (clamp(int(c[0] * f)), clamp(int(c[1] * f)), clamp(int(c[2] * f)), 255)

	for y in range(SIDE_H):
		for x in (0, 1, 2, SIDE_W - 3, SIDE_W - 2, SIDE_W - 1):
			c = px[x, y]
			t = 0.5 if x in (0, SIDE_W - 1) else 0.72
			px[x, y] = (clamp(int(c[0] * t)), clamp(int(c[1] * t)), clamp(int(c[2] * t)), 255)

	return img


def save_variant(name: str, seed: int) -> None:
	folder = BLOCKS / name
	folder.mkdir(parents=True, exist_ok=True)
	make_top(seed).save(folder / "top.png")
	make_side(seed).save(folder / "side.png")
	print("wrote", folder.relative_to(ROOT))


def main() -> None:
	BLOCKS.mkdir(parents=True, exist_ok=True)
	save_variant("soil", 42)
	save_variant("soil_b", 77)
	save_variant("soil_c", 131)
	print("Done.")


if __name__ == "__main__":
	main()
