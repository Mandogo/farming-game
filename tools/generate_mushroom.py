"""Génère stages + icône champignon (remplace le maïs)."""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
CROPS = ROOT / "assets" / "textures" / "crops"
ICONS = ROOT / "assets" / "textures" / "icons"

CAP = (210, 95, 70)
CAP_H = (240, 140, 100)
CAP_D = (140, 50, 40)
STEM = (235, 220, 190)
STEM_D = (180, 155, 120)
SPOT = (250, 230, 210)
DIRT = (90, 70, 45)


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


def _shroom(d: ImageDraw.ImageDraw, cx: int, ground: int, scale: float, ripe: bool) -> None:
	sw = int(10 * scale)
	sh = int(18 * scale)
	cap_w = int(28 * scale)
	cap_h = int(16 * scale)
	# tige
	d.rectangle([cx - sw // 2, ground - sh, cx + sw // 2, ground], fill=STEM + (255,))
	d.ellipse([cx - sw // 2 - 1, ground - 4, cx + sw // 2 + 1, ground + 2], fill=STEM_D + (255,))
	# chapeau
	cy = ground - sh
	col = CAP if ripe else (120, 160, 90)
	hi = CAP_H if ripe else (160, 200, 120)
	d.ellipse([cx - cap_w // 2, cy - cap_h, cx + cap_w // 2, cy + 4], fill=col + (255,), outline=CAP_D + (255,))
	d.ellipse([cx - cap_w // 3, cy - cap_h + 2, cx, cy - 2], fill=hi + (160,))
	if ripe:
		for ox, oy in ((-6, -6), (4, -8), (-2, -3), (8, -4)):
			r = 2
			d.ellipse([cx + ox - r, cy + oy - r, cx + ox + r, cy + oy + r], fill=SPOT + (220,))


def draw_mushroom(stage: int) -> Image.Image:
	w, h = 160, 280
	img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	cx, ground = w // 2, 171

	if stage == 1:
		for dx in (-12, 4, 14):
			x = cx + dx
			d.ellipse([x - 3, ground - 6, x + 3, ground], fill=DIRT + (255,))
			d.line([(x, ground - 6), (x, ground - 12)], fill=(100, 150, 70, 255), width=2)
		return add_outline(img)

	if stage == 2:
		_shroom(d, cx - 16, ground, 0.55, False)
		_shroom(d, cx + 14, ground, 0.5, False)
		return add_outline(img)

	ripe = stage == 4
	if ripe:
		_shroom(d, cx - 28, ground, 0.75, True)
		_shroom(d, cx + 2, ground, 1.05, True)
		_shroom(d, cx + 30, ground, 0.7, True)
	else:
		_shroom(d, cx - 20, ground, 0.7, False)
		_shroom(d, cx + 18, ground, 0.85, False)
	return add_outline(img)


def icon_mushroom() -> Image.Image:
	img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	# tige
	d.rectangle([26, 34, 38, 56], fill=STEM + (255,))
	d.ellipse([24, 50, 40, 60], fill=STEM_D + (255,))
	# chapeau
	d.ellipse([10, 8, 54, 40], fill=CAP + (255,), outline=CAP_D + (255,))
	d.ellipse([16, 12, 34, 28], fill=CAP_H + (180,))
	for ox, oy in ((18, 18), (32, 14), (42, 22), (28, 24)):
		d.ellipse([ox - 3, oy - 3, ox + 3, oy + 3], fill=SPOT + (230,))
	return add_outline(img)


def main() -> None:
	out_dir = CROPS / "mushroom"
	out_dir.mkdir(parents=True, exist_ok=True)
	ICONS.mkdir(parents=True, exist_ok=True)
	for stage in range(1, 5):
		draw_mushroom(stage).save(out_dir / f"stage_{stage}.png")
	icon_mushroom().save(ICONS / "mushroom.png")
	print("mushroom stages + icon OK")


if __name__ == "__main__":
	main()
