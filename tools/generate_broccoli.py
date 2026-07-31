"""Génère stages + icône pour brocoli et s'assure que le maïs a une icône cohérente."""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
CROPS = ROOT / "assets" / "textures" / "crops"
ICONS = ROOT / "assets" / "textures" / "icons"


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


STEM = (55, 140, 55)
STEM_D = (35, 100, 40)
LEAF = (70, 175, 70)
HEAD = (45, 150, 55)
HEAD_H = (90, 195, 85)
HEAD_D = (25, 105, 40)
UNRIPE = (95, 160, 85)


def draw_broccoli(stage: int) -> Image.Image:
	w, h = 160, 280
	img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	cx, ground = w // 2, 171

	if stage == 1:
		for dx in (-10, 4, 12):
			x = cx + dx
			d.line([(x, ground), (x, ground - 8)], fill=STEM + (255,), width=2)
			d.ellipse([x - 4, ground - 14, x + 4, ground - 5], fill=LEAF + (255,))
		return add_outline(img)

	if stage == 2:
		d.line([(cx, ground), (cx, ground - 28)], fill=STEM + (255,), width=4)
		d.ellipse([cx - 14, ground - 40, cx + 14, ground - 18], fill=UNRIPE + (255,))
		d.ellipse([cx - 18, ground - 34, cx - 4, ground - 20], fill=LEAF + (255,))
		d.ellipse([cx + 4, ground - 34, cx + 18, ground - 20], fill=LEAF + (255,))
		return add_outline(img)

	ripe = stage == 4
	stem_h = 48 if ripe else 38
	head_r = 28 if ripe else 18
	d.rectangle([cx - 5, ground - stem_h, cx + 5, ground], fill=STEM + (255,))
	d.rectangle([cx - 7, ground - 10, cx + 7, ground], fill=STEM_D + (255,))

	# Tête en grappes (florettes)
	hy = ground - stem_h - 4
	col = HEAD if ripe else UNRIPE
	hi = HEAD_H if ripe else (130, 190, 110)
	clusters = [(-16, -6), (0, -14), (16, -6), (-8, 4), (8, 4)] if ripe else [(-10, -4), (0, -10), (10, -2)]
	for dx, dy in clusters:
		x, y = cx + dx, hy + dy
		r = head_r // 2 + (3 if ripe else 0)
		d.ellipse([x - r, y - r, x + r, y + r], fill=col + (255,), outline=HEAD_D + (255,))
		d.ellipse([x - r // 2, y - r // 2 - 2, x + 2, y], fill=hi + (160,))

	# Petite feuille latérale
	d.ellipse([cx - 26, ground - stem_h + 8, cx - 8, ground - stem_h + 22], fill=LEAF + (255,))
	return add_outline(img)


def icon_broccoli() -> Image.Image:
	img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	d.rectangle([28, 34, 36, 58], fill=STEM + (255,))
	for cx, cy, r in ((22, 28, 12), (32, 20, 14), (42, 28, 12), (27, 34, 10), (37, 34, 10)):
		d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=HEAD + (255,))
		d.ellipse([cx - r // 2, cy - r // 2 - 1, cx + 2, cy], fill=HEAD_H + (150,))
	return add_outline(img)


def main() -> None:
	out_dir = CROPS / "broccoli"
	out_dir.mkdir(parents=True, exist_ok=True)
	ICONS.mkdir(parents=True, exist_ok=True)
	for stage in range(1, 5):
		draw_broccoli(stage).save(out_dir / f"stage_{stage}.png")
	icon_broccoli().save(ICONS / "broccoli.png")
	print("broccoli stages + icon OK")


if __name__ == "__main__":
	main()
