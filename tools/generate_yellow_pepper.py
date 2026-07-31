"""Régénère le poivron en jaune — style simple (comme tomate/carotte)."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
CROPS = ROOT / "assets" / "textures" / "crops" / "pepper"
ICONS = ROOT / "assets" / "textures" / "icons"

BODY = (245, 198, 40)
BODY_H = (255, 230, 120)
BODY_D = (195, 140, 18)
CALYX = (70, 155, 55)
STEM = (55, 130, 50)
LEAF = (90, 185, 70)
UNRIPE = (85, 155, 65)


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


def draw_pepper(d: ImageDraw.ImageDraw, cx: int, fy: int, scale: float, ripe: bool) -> None:
	"""Poivron lobé simple : corps + 2 lobes + calice + tige."""
	bw = int(12 * scale)
	bh = int(15 * scale)
	col = BODY if ripe else UNRIPE
	hi = BODY_H if ripe else (130, 195, 100)
	dk = BODY_D if ripe else (50, 105, 40)

	d.ellipse([cx - bw, fy - 2, cx + bw, fy + bh], fill=col + (255,), outline=dk + (255,), width=2)
	d.ellipse([cx - bw - int(4 * scale), fy + int(3 * scale), cx - 1, fy + bh], fill=col + (255,))
	d.ellipse([cx + 1, fy + int(3 * scale), cx + bw + int(4 * scale), fy + bh], fill=col + (255,))
	# Ombre simple (comme tomate)
	d.ellipse(
		[cx - int(bw * 0.35), fy + int(bh * 0.25), cx + int(bw * 0.15), fy + int(bh * 0.75)],
		fill=dk + (255,),
	)
	d.ellipse(
		[cx - int(7 * scale), fy + int(2 * scale), cx - int(1 * scale), fy + int(9 * scale)],
		fill=hi + (255,),
	)
	# Calice
	cs = max(3, int(4 * scale))
	d.ellipse([cx - cs, fy - cs, cx + cs, fy + 2], fill=CALYX + (255,))
	for ox in (-cs, 0, cs):
		d.polygon([(cx, fy), (cx + ox, fy - cs - 2), (cx + ox // 2, fy + 1)], fill=CALYX + (255,))
	d.line([(cx, fy - cs), (cx, fy - cs - int(6 * scale))], fill=STEM + (255,), width=2)


def draw_stage(stage: int) -> Image.Image:
	w, h = 160, 280
	img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	cx, ground = w // 2, 171

	if stage == 1:
		for dx in (-12, 2, 14):
			x = cx + dx
			d.line([(x, ground), (x, ground - 6)], fill=STEM + (255,), width=2)
			d.ellipse([x - 3, ground - 10, x + 3, ground - 4], fill=LEAF + (255,))
		return add_outline(img)

	if stage == 2:
		for dx in (-18, 0, 18):
			x = cx + dx
			d.line([(x, ground), (x, ground - 16)], fill=STEM + (255,), width=3)
			d.ellipse([x - 10, ground - 22, x - 1, ground - 12], fill=LEAF + (255,))
			d.ellipse([x + 1, ground - 20, x + 10, ground - 10], fill=LEAF + (255,))
		return add_outline(img)

	ripe = stage == 4
	positions = [(-28, 0), (-4, -2), (20, 0), (38, -2)] if ripe else [(-14, 0), (16, 0)]
	for dx, dy in positions:
		x = cx + dx
		stem_h = 28 if ripe else 20
		d.line([(x, ground), (x, ground - stem_h + dy)], fill=STEM + (255,), width=3)
		d.ellipse(
			[x - 8, ground - stem_h - 2 + dy, x + 4, ground - stem_h + 10 + dy],
			fill=LEAF + (255,),
		)
		fy = ground - stem_h + dy
		draw_pepper(d, x, fy, 1.0 if ripe else 0.7, ripe)

	return add_outline(img)


def make_icon() -> Image.Image:
	img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	d.ellipse([16, 16, 48, 54], fill=BODY + (255,), outline=BODY_D + (255,), width=2)
	d.ellipse([10, 26, 28, 52], fill=BODY + (255,))
	d.ellipse([36, 26, 54, 52], fill=BODY + (255,))
	d.ellipse([22, 28, 34, 42], fill=BODY_D + (255,))
	d.ellipse([18, 22, 30, 36], fill=BODY_H + (255,))
	d.ellipse([28, 8, 36, 20], fill=CALYX + (255,))
	d.polygon([(32, 14), (22, 6), (28, 16)], fill=CALYX + (255,))
	d.polygon([(32, 14), (42, 6), (36, 16)], fill=CALYX + (255,))
	d.line([(32, 10), (32, 2)], fill=STEM + (255,), width=3)
	return add_outline(img)


def main() -> None:
	CROPS.mkdir(parents=True, exist_ok=True)
	ICONS.mkdir(parents=True, exist_ok=True)
	for stage in range(1, 5):
		path = CROPS / f"stage_{stage}.png"
		draw_stage(stage).save(path)
		print("wrote", path.relative_to(ROOT))
	ip = ICONS / "pepper.png"
	make_icon().save(ip)
	print("wrote", ip.relative_to(ROOT))


if __name__ == "__main__":
	main()
