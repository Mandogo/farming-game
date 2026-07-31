"""Génère 6 stages de pousse opaques (sans blend) pour chaque légume."""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
CROPS = ROOT / "assets" / "textures" / "crops"

STEM = (55, 140, 50)
STEM_D = (35, 100, 40)
LEAF = (90, 185, 70)
LEAF_D = (50, 130, 45)
GROUND_Y = 171


def add_outline(img: Image.Image, color=(18, 12, 8, 230)) -> Image.Image:
	a = img.split()[-1]
	w, h = img.size
	out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	op = out.load()
	alpha = a.load()
	for y in range(h):
		for x in range(w):
			if alpha[x, y] < 128:
				continue
			for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
				nx, ny = x + dx, y + dy
				if 0 <= nx < w and 0 <= ny < h and alpha[nx, ny] < 128:
					op[nx, ny] = color
	final = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	final.alpha_composite(out)
	final.alpha_composite(img)
	return final


def _ell(d, box, fill, outline=None, width=2):
	d.ellipse(box, fill=fill + (255,), outline=(outline + (255,)) if outline else None, width=width if outline else 0)


def _line(d, a, b, col, width=3):
	d.line([a, b], fill=col + (255,), width=width)


def _new() -> tuple[Image.Image, ImageDraw.ImageDraw, int]:
	img = Image.new("RGBA", (160, 280), (0, 0, 0, 0))
	return img, ImageDraw.Draw(img), 80


# ─── germes / feuilles communes ───────────────────────────────────────────────

def stage_sprouts(offsets: tuple[int, ...], stem_h: int, leaf_r: int) -> Image.Image:
	img, d, cx = _new()
	g = GROUND_Y
	for dx in offsets:
		x = cx + dx
		_line(d, (x, g), (x, g - stem_h), STEM, 2)
		_ell(d, [x - leaf_r, g - stem_h - leaf_r, x + leaf_r, g - stem_h + leaf_r // 2], LEAF, LEAF_D, 1)
	return add_outline(img)


def stage_leafy(offsets: tuple[int, ...], stem_h: int) -> Image.Image:
	img, d, cx = _new()
	g = GROUND_Y
	for dx in offsets:
		x = cx + dx
		_line(d, (x, g), (x, g - stem_h), STEM, 3)
		_ell(d, [x - 11, g - stem_h - 4, x - 1, g - stem_h + 8], LEAF, LEAF_D, 1)
		_ell(d, [x + 1, g - stem_h - 2, x + 11, g - stem_h + 10], LEAF, LEAF_D, 1)
	return add_outline(img)


# ─── TOMATE ───────────────────────────────────────────────────────────────────

def tomato(stage: int) -> Image.Image:
	FR, FRH, FRD = (220, 55, 45), (255, 110, 80), (160, 30, 30)
	GR, GRH, GRD = (95, 165, 70), (140, 205, 110), (55, 110, 45)
	OR, ORH, ORD = (230, 140, 50), (255, 185, 90), (170, 90, 30)  # presque mûr

	if stage == 1:
		return stage_sprouts((-12, 2, 14), 7, 3)
	if stage == 2:
		return stage_leafy((-18, 0, 18), 16)

	img, d, cx = _new()
	g = GROUND_Y

	if stage == 3:
		# tiges + tout petits boutons verts
		for dx in (-16, 14):
			x = cx + dx
			_line(d, (x, g), (x, g - 24), STEM, 3)
			_ell(d, [x - 9, g - 28, x + 1, g - 16], LEAF, LEAF_D, 1)
			_ell(d, [x - 4, g - 34, x + 4, g - 26], GR, GRD, 1)
		return add_outline(img)

	if stage == 4:
		# 2 fruits verts moyens
		for dx, dy in ((-16, 0), (14, -2)):
			x = cx + dx
			sh = 28
			_line(d, (x, g), (x, g - sh + dy), STEM, 3)
			_ell(d, [x - 9, g - sh - 4 + dy, x + 1, g - sh + 8 + dy], LEAF, LEAF_D, 1)
			fy = g - sh - 2 + dy
			r = 9
			_ell(d, [x - r, fy - r, x + r, fy + r], GR, GRD, 2)
			_ell(d, [x - r // 2, fy - r // 2, x, fy], GRH, None, 0)
			for ox in (-4, 0, 4):
				d.polygon([(x, fy - r + 2), (x + ox, fy - r - 5), (x + ox // 2, fy - r + 3)], fill=LEAF_D + (255,))
		return add_outline(img)

	if stage == 5:
		# 3 fruits orangés (presque mûrs) — art dédié
		for dx, dy in ((-22, 0), (0, -3), (24, 0)):
			x = cx + dx
			sh = 32
			_line(d, (x, g), (x, g - sh + dy), STEM, 3)
			_ell(d, [x - 9, g - sh - 2 + dy, x + 2, g - sh + 10 + dy], LEAF, LEAF_D, 1)
			fy = g - sh - 2 + dy
			r = 12
			_ell(d, [x - r, fy - r, x + r, fy + r], OR, ORD, 2)
			_ell(d, [x - r // 2, fy - r // 2, x, fy], ORH, None, 0)
			for ox in (-5, 0, 5):
				d.polygon([(x, fy - r + 2), (x + ox, fy - r - 6), (x + ox // 2, fy - r + 4)], fill=LEAF_D + (255,))
		return add_outline(img)

	# stage 6 ripe
	for dx, dy in ((-28, 0), (-6, -4), (16, 0), (34, -2)):
		x = cx + dx
		sh = 34
		_line(d, (x, g), (x, g - sh + dy), STEM, 3)
		_ell(d, [x - 9, g - sh - 4 + dy, x + 1, g - sh + 8 + dy], LEAF, LEAF_D, 1)
		fy = g - sh - 2 + dy
		r = 14
		_ell(d, [x - r, fy - r, x + r, fy + r], FR, FRD, 2)
		_ell(d, [x - r // 2, fy - r // 2, x, fy], FRH, None, 0)
		for ox in (-5, 0, 5):
			d.polygon([(x, fy - r + 2), (x + ox, fy - r - 6), (x + ox // 2, fy - r + 4)], fill=LEAF_D + (255,))
	return add_outline(img)


# ─── AUBERGINE ────────────────────────────────────────────────────────────────

def eggplant(stage: int) -> Image.Image:
	FR, FRH, FRD = (110, 55, 150), (160, 95, 195), (70, 30, 100)
	GR, GRH, GRD = (100, 140, 80), (140, 185, 110), (55, 95, 45)
	PR, PRH, PRD = (130, 70, 140), (175, 110, 180), (80, 40, 95)  # presque violet

	if stage == 1:
		return stage_sprouts((-12, 2, 14), 7, 3)
	if stage == 2:
		return stage_leafy((-18, 0, 18), 16)

	img, d, cx = _new()
	g = GROUND_Y

	if stage == 3:
		for dx in (-14, 16):
			x = cx + dx
			_line(d, (x, g), (x, g - 20), STEM, 3)
			_ell(d, [x - 10, g - 24, x + 2, g - 12], LEAF, LEAF_D, 1)
			_ell(d, [x - 5, g - 22, x + 5, g - 10], GR, GRD, 1)
		return add_outline(img)

	if stage == 4:
		for dx in (-14, 16):
			x = cx + dx
			sh = 22
			_line(d, (x, g), (x, g - sh), STEM, 3)
			_ell(d, [x - 10, g - sh, x + 2, g - sh + 12], LEAF, LEAF_D, 1)
			fy = g - sh + 4
			bw, bh = 8, 18
			_ell(d, [x - bw, fy, x + bw, fy + bh], GR, GRD, 2)
			_ell(d, [x - bw // 2, fy + 4, x, fy + bh // 2], GRH, None, 0)
			_ell(d, [x - 8, fy - 6, x + 8, fy + 6], LEAF_D, None, 0)
			_line(d, (x, fy - 6), (x, fy - 14), STEM, 2)
		return add_outline(img)

	if stage == 5:
		for dx, dy in ((-20, 0), (4, -2), (26, 0)):
			x = cx + dx
			sh = 26
			_line(d, (x, g), (x, g - sh + dy), STEM, 3)
			_ell(d, [x - 10, g - sh, x + 2, g - sh + 12], LEAF, LEAF_D, 1)
			fy = g - sh + 4 + dy
			bw, bh = 10, 24
			_ell(d, [x - bw, fy, x + bw, fy + bh], PR, PRD, 2)
			_ell(d, [x - bw // 2, fy + 4, x, fy + bh // 2], PRH, None, 0)
			_ell(d, [x - 8, fy - 6, x + 8, fy + 6], LEAF_D, None, 0)
			_line(d, (x, fy - 6), (x, fy - 14), STEM, 2)
		return add_outline(img)

	for dx, dy in ((-26, 0), (0, -2), (26, 0)):
		x = cx + dx
		sh = 30
		_line(d, (x, g), (x, g - sh + dy), STEM, 3)
		_ell(d, [x - 10, g - sh, x + 2, g - sh + 12], LEAF, LEAF_D, 1)
		fy = g - sh + 4 + dy
		bw, bh = 12, 28
		_ell(d, [x - bw, fy, x + bw, fy + bh], FR, FRD, 2)
		_ell(d, [x - bw // 2, fy + 4, x, fy + bh // 2], FRH, None, 0)
		_ell(d, [x - 8, fy - 6, x + 8, fy + 6], LEAF_D, None, 0)
		_line(d, (x, fy - 6), (x, fy - 14), STEM, 2)
	return add_outline(img)


# ─── CAROTTE ──────────────────────────────────────────────────────────────────

def carrot(stage: int) -> Image.Image:
	FR, FRH, FRD = (235, 120, 35), (255, 170, 70), (185, 80, 20)
	PALE, PALE_H, PALE_D = (200, 160, 70), (230, 200, 120), (150, 110, 40)

	if stage == 1:
		return stage_sprouts((-12, 2, 14), 7, 3)
	if stage == 2:
		img, d, cx = _new()
		g = GROUND_Y
		for dx in (-14, 0, 14):
			x = cx + dx
			for ox, oy in ((-5, -14), (0, -18), (5, -14)):
				_line(d, (x, g - 4), (x + ox, g + oy), LEAF, 2)
		return add_outline(img)

	img, d, cx = _new()
	g = GROUND_Y

	def _fan(x: int, tall: bool):
		span = ((-6, -22), (0, -28), (6, -22), (-3, -18), (3, -18)) if tall else ((-5, -16), (0, -20), (5, -16))
		for ox, oy in span:
			_line(d, (x, g - 8), (x + ox, g + oy), LEAF, 2)

	if stage == 3:
		for dx in (-14, 14):
			x = cx + dx
			_fan(x, False)
			top = g - 6
			d.polygon([(x - 4, top), (x + 4, top), (x + 1, top + 8), (x - 1, top + 8)], fill=PALE + (255,), outline=PALE_D + (255,))
		return add_outline(img)

	if stage == 4:
		for dx in (-14, 14):
			x = cx + dx
			_fan(x, False)
			top = g - 6
			bh, bw = 14, 5
			d.polygon([(x - bw, top), (x + bw, top), (x + 2, top + bh), (x - 2, top + bh)], fill=PALE + (255,), outline=PALE_D + (255,))
			_line(d, (x - 1, top + 3), (x - 1, top + bh - 3), PALE_H, 2)
		return add_outline(img)

	if stage == 5:
		for dx in (-22, 0, 22):
			x = cx + dx
			_fan(x, True)
			top = g - 6
			bh, bw = 18, 7
			col = (225, 140, 45)
			d.polygon([(x - bw, top), (x + bw, top), (x + 2, top + bh), (x - 2, top + bh)], fill=col + (255,), outline=FRD + (255,))
			_line(d, (x - 2, top + 4), (x - 1, top + bh - 4), FRH, 2)
		return add_outline(img)

	for dx in (-30, -8, 14, 34):
		x = cx + dx
		_fan(x, True)
		top = g - 6
		bh, bw = 22, 8
		d.polygon([(x - bw, top), (x + bw, top), (x + 2, top + bh), (x - 2, top + bh)], fill=FR + (255,), outline=FRD + (255,))
		_line(d, (x - 2, top + 4), (x - 1, top + bh - 4), FRH, 2)
	return add_outline(img)


# ─── POIVRON ──────────────────────────────────────────────────────────────────

def pepper(stage: int) -> Image.Image:
	FR, FRH, FRD = (245, 198, 40), (255, 235, 130), (195, 140, 18)
	GR, GRH, GRD = (85, 155, 65), (130, 195, 100), (50, 105, 40)
	YL, YLH, YLD = (200, 180, 55), (230, 215, 110), (150, 130, 30)

	if stage == 1:
		return stage_sprouts((-12, 2, 14), 7, 3)
	if stage == 2:
		return stage_leafy((-18, 0, 18), 16)

	img, d, cx = _new()
	g = GROUND_Y

	def _pep(x: int, fy: int, scale: float, col, hi, dk):
		bw = int(12 * scale)
		bh = int(15 * scale)
		_ell(d, [x - bw, fy - 2, x + bw, fy + bh], col, dk, 2)
		_ell(d, [x - bw - int(4 * scale), fy + int(3 * scale), x - 1, fy + bh], col, None, 0)
		_ell(d, [x + 1, fy + int(3 * scale), x + bw + int(4 * scale), fy + bh], col, None, 0)
		_ell(d, [x - int(bw * 0.35), fy + int(bh * 0.25), x + int(bw * 0.15), fy + int(bh * 0.75)], dk, None, 0)
		_ell(d, [x - int(7 * scale), fy + int(2 * scale), x - int(1 * scale), fy + int(9 * scale)], hi, None, 0)
		cs = max(3, int(4 * scale))
		_ell(d, [x - cs, fy - cs, x + cs, fy + 2], LEAF_D, None, 0)
		for ox in (-cs, 0, cs):
			d.polygon([(x, fy), (x + ox, fy - cs - 2), (x + ox // 2, fy + 1)], fill=LEAF_D + (255,))
		_line(d, (x, fy - cs), (x, fy - cs - int(6 * scale)), STEM, 2)

	if stage == 3:
		for dx in (-14, 16):
			x = cx + dx
			sh = 18
			_line(d, (x, g), (x, g - sh), STEM, 3)
			_ell(d, [x - 8, g - sh - 2, x + 4, g - sh + 10], LEAF, LEAF_D, 1)
			_pep(x, g - sh, 0.45, GR, GRH, GRD)
		return add_outline(img)

	if stage == 4:
		for dx, dy in ((-14, 0), (16, 0)):
			x = cx + dx
			sh = 20
			_line(d, (x, g), (x, g - sh + dy), STEM, 3)
			_ell(d, [x - 8, g - sh - 2 + dy, x + 4, g - sh + 10 + dy], LEAF, LEAF_D, 1)
			_pep(x, g - sh + dy, 0.7, GR, GRH, GRD)
		return add_outline(img)

	if stage == 5:
		for dx, dy in ((-22, 0), (2, -2), (26, 0)):
			x = cx + dx
			sh = 24
			_line(d, (x, g), (x, g - sh + dy), STEM, 3)
			_ell(d, [x - 8, g - sh - 2 + dy, x + 4, g - sh + 10 + dy], LEAF, LEAF_D, 1)
			_pep(x, g - sh + dy, 0.85, YL, YLH, YLD)
		return add_outline(img)

	for dx, dy in ((-28, 0), (-4, -2), (20, 0), (38, -2)):
		x = cx + dx
		sh = 28
		_line(d, (x, g), (x, g - sh + dy), STEM, 3)
		_ell(d, [x - 8, g - sh - 2 + dy, x + 4, g - sh + 10 + dy], LEAF, LEAF_D, 1)
		_pep(x, g - sh + dy, 1.0, FR, FRH, FRD)
	return add_outline(img)


# ─── CHAMPIGNON ───────────────────────────────────────────────────────────────

def mushroom(stage: int) -> Image.Image:
	CAP, CAP_H, CAP_D = (210, 95, 70), (240, 140, 100), (140, 50, 40)
	ST, ST_D = (235, 220, 190), (180, 155, 120)
	SPOT = (250, 230, 210)
	DIRT = (90, 70, 45)
	UNR, UNR_H = (120, 160, 90), (160, 200, 120)
	MID, MID_H = (180, 130, 70), (210, 165, 110)

	def _shroom(d, cx, ground, scale, mode: str):
		sw = int(10 * scale)
		sh = int(18 * scale)
		cap_w = int(28 * scale)
		cap_h = int(16 * scale)
		d.rectangle([cx - sw // 2, ground - sh, cx + sw // 2, ground], fill=ST + (255,))
		_ell(d, [cx - sw // 2 - 1, ground - 4, cx + sw // 2 + 1, ground + 2], ST_D, None, 0)
		cy = ground - sh
		if mode == "ripe":
			col, hi = CAP, CAP_H
		elif mode == "mid":
			col, hi = MID, MID_H
		else:
			col, hi = UNR, UNR_H
		_ell(d, [cx - cap_w // 2, cy - cap_h, cx + cap_w // 2, cy + 4], col, CAP_D if mode == "ripe" else (60, 90, 40), 1)
		_ell(d, [cx - cap_w // 3, cy - cap_h + 2, cx, cy - 2], hi, None, 0)
		if mode == "ripe":
			for ox, oy in ((-6, -6), (4, -8), (-2, -3), (8, -4)):
				_ell(d, [cx + ox - 2, cy + oy - 2, cx + ox + 2, cy + oy + 2], SPOT, None, 0)

	if stage == 1:
		img, d, cx = _new()
		g = GROUND_Y
		for dx in (-12, 4, 14):
			x = cx + dx
			_ell(d, [x - 3, g - 6, x + 3, g], DIRT, None, 0)
			_line(d, (x, g - 6), (x, g - 12), (100, 150, 70), 2)
		return add_outline(img)

	img, d, cx = _new()
	g = GROUND_Y
	if stage == 2:
		_shroom(d, cx - 16, g, 0.45, "green")
		_shroom(d, cx + 14, g, 0.4, "green")
		return add_outline(img)
	if stage == 3:
		_shroom(d, cx - 18, g, 0.6, "green")
		_shroom(d, cx + 16, g, 0.7, "green")
		return add_outline(img)
	if stage == 4:
		_shroom(d, cx - 20, g, 0.7, "green")
		_shroom(d, cx + 18, g, 0.85, "green")
		return add_outline(img)
	if stage == 5:
		_shroom(d, cx - 24, g, 0.75, "mid")
		_shroom(d, cx + 4, g, 0.95, "mid")
		_shroom(d, cx + 28, g, 0.7, "mid")
		return add_outline(img)
	_shroom(d, cx - 28, g, 0.75, "ripe")
	_shroom(d, cx + 2, g, 1.05, "ripe")
	_shroom(d, cx + 30, g, 0.7, "ripe")
	return add_outline(img)


# ─── BROCOLI ──────────────────────────────────────────────────────────────────

def broccoli(stage: int) -> Image.Image:
	HEAD, HEAD_H, HEAD_D = (45, 150, 55), (90, 195, 85), (25, 105, 40)
	UNR = (95, 160, 85)
	MID = (60, 155, 70)

	if stage == 1:
		return stage_sprouts((-10, 4, 12), 8, 4)

	img, d, cx = _new()
	g = GROUND_Y

	if stage == 2:
		_line(d, (cx, g), (cx, g - 22), STEM, 3)
		_ell(d, [cx - 10, g - 32, cx + 10, g - 16], UNR, HEAD_D, 1)
		_ell(d, [cx - 14, g - 28, cx - 2, g - 16], LEAF, None, 0)
		_ell(d, [cx + 2, g - 28, cx + 14, g - 16], LEAF, None, 0)
		return add_outline(img)

	if stage == 3:
		d.rectangle([cx - 4, g - 32, cx + 4, g], fill=STEM + (255,))
		hy = g - 36
		for dx, dy in ((-8, -2), (0, -8), (8, 0)):
			x, y = cx + dx, hy + dy
			r = 8
			_ell(d, [x - r, y - r, x + r, y + r], UNR, HEAD_D, 1)
		_ell(d, [cx - 20, g - 28, cx - 6, g - 16], LEAF, None, 0)
		return add_outline(img)

	if stage == 4:
		d.rectangle([cx - 5, g - 38, cx + 5, g], fill=STEM + (255,))
		d.rectangle([cx - 7, g - 10, cx + 7, g], fill=STEM_D + (255,))
		hy = g - 42
		for dx, dy in ((-10, -4), (0, -10), (10, -2)):
			x, y = cx + dx, hy + dy
			r = 10
			_ell(d, [x - r, y - r, x + r, y + r], UNR, HEAD_D, 1)
			_ell(d, [x - r // 2, y - r // 2 - 2, x + 2, y], (130, 190, 110), None, 0)
		_ell(d, [cx - 24, g - 30, cx - 8, g - 16], LEAF, None, 0)
		return add_outline(img)

	if stage == 5:
		d.rectangle([cx - 5, g - 44, cx + 5, g], fill=STEM + (255,))
		d.rectangle([cx - 7, g - 10, cx + 7, g], fill=STEM_D + (255,))
		hy = g - 48
		for dx, dy in ((-14, -4), (0, -12), (14, -4), (-6, 4), (6, 4)):
			x, y = cx + dx, hy + dy
			r = 12
			_ell(d, [x - r, y - r, x + r, y + r], MID, HEAD_D, 1)
			_ell(d, [x - r // 2, y - r // 2 - 2, x + 2, y], HEAD_H, None, 0)
		_ell(d, [cx - 26, g - 36, cx - 8, g - 22], LEAF, None, 0)
		return add_outline(img)

	d.rectangle([cx - 5, g - 48, cx + 5, g], fill=STEM + (255,))
	d.rectangle([cx - 7, g - 10, cx + 7, g], fill=STEM_D + (255,))
	hy = g - 52
	for dx, dy in ((-16, -6), (0, -14), (16, -6), (-8, 4), (8, 4)):
		x, y = cx + dx, hy + dy
		r = 14
		_ell(d, [x - r, y - r, x + r, y + r], HEAD, HEAD_D, 1)
		_ell(d, [x - r // 2, y - r // 2 - 2, x + 2, y], HEAD_H, None, 0)
	_ell(d, [cx - 26, g - 40, cx - 8, g - 26], LEAF, None, 0)
	return add_outline(img)


GENERATORS = {
	"tomato": tomato,
	"eggplant": eggplant,
	"carrot": carrot,
	"pepper": pepper,
	"mushroom": mushroom,
	"broccoli": broccoli,
}


def main() -> None:
	for name, fn in GENERATORS.items():
		out = CROPS / name
		out.mkdir(parents=True, exist_ok=True)
		for stage in range(1, 7):
			path = out / f"stage_{stage}.png"
			fn(stage).save(path)
			print("wrote", path.relative_to(ROOT))
	print("Done — 6 opaque stages per crop.")


if __name__ == "__main__":
	main()
