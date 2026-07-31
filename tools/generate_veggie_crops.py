"""Génère cultures légumes très lisibles : tomate, aubergine, carotte, poivron."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
TEX = ROOT / "assets" / "textures"

CROPS = ("tomato", "eggplant", "carrot", "pepper")

PAL = {
	"tomato": {
		"stem": (55, 140, 50), "leaf": (90, 185, 70),
		"fruit": (220, 55, 45), "fruit_h": (255, 110, 80), "fruit_d": (160, 30, 30),
		"accent": (50, 130, 45),
	},
	"eggplant": {
		"stem": (50, 130, 48), "leaf": (85, 170, 75),
		"fruit": (110, 55, 150), "fruit_h": (160, 95, 195), "fruit_d": (70, 30, 100),
		"accent": (45, 120, 50),
	},
	"carrot": {
		"stem": (55, 145, 50), "leaf": (95, 190, 75),
		"fruit": (235, 120, 35), "fruit_h": (255, 170, 70), "fruit_d": (185, 80, 20),
		"accent": (60, 150, 55),
	},
	"pepper": {
		"stem": (55, 130, 50), "leaf": (90, 185, 70),
		"fruit": (245, 198, 40), "fruit_h": (255, 235, 130), "fruit_d": (195, 140, 18),
		"accent": (70, 155, 55),
	},
}


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


def _ellipse(d, box, fill, outline=None, width=1):
	d.ellipse(box, fill=fill, outline=outline, width=width if outline else 0)


def draw_stage(kind: str, stage: int) -> Image.Image:
	p = PAL[kind]
	w, h = 160, 280
	img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	cx, ground = w // 2, 171

	if stage == 1:
		# germes verts simples
		for dx in (-12, 2, 14):
			x = cx + dx
			d.line([(x, ground), (x, ground - 6)], fill=p["stem"] + (255,), width=2)
			d.ellipse([x - 3, ground - 10, x + 3, ground - 4], fill=p["leaf"] + (255,))
		return add_outline(img)

	if stage == 2:
		for dx in (-18, 0, 18):
			x = cx + dx
			d.line([(x, ground), (x, ground - 16)], fill=p["stem"] + (255,), width=3)
			d.ellipse([x - 10, ground - 22, x - 1, ground - 12], fill=p["leaf"] + (255,))
			d.ellipse([x + 1, ground - 20, x + 10, ground - 10], fill=p["leaf"] + (255,))
		return add_outline(img)

	# stage 3–4 : plant + fruit lisible
	ripe = stage == 4
	if kind == "tomato":
		positions = [(-28, 0), (-6, -4), (16, 0), (34, -2)] if ripe else [(-16, 0), (14, -2)]
		for dx, dy in positions:
			x = cx + dx
			stem_h = 34 if ripe else 26
			d.line([(x, ground), (x, ground - stem_h + dy)], fill=p["stem"] + (255,), width=3)
			d.ellipse([x - 9, ground - stem_h - 4 + dy, x + 1, ground - stem_h + 8 + dy], fill=p["leaf"] + (255,))
			fy = ground - stem_h - 2 + dy
			r = 14 if ripe else 9
			col = p["fruit"] if ripe else (90, 160, 70)
			hi = p["fruit_h"] if ripe else (130, 200, 100)
			_ellipse(d, [x - r, fy - r, x + r, fy + r], col + (255,), p["fruit_d"] + (255,), 2)
			_ellipse(d, [x - r // 2, fy - r // 2, x, fy], hi + (180,))
			# calice
			for ox in (-5, 0, 5):
				d.polygon([(x, fy - r + 2), (x + ox, fy - r - 6), (x + ox // 2, fy - r + 4)], fill=p["accent"] + (255,))

	elif kind == "eggplant":
		positions = [(-26, 0), (0, -2), (26, 0)] if ripe else [(-14, 0), (16, 0)]
		for dx, dy in positions:
			x = cx + dx
			stem_h = 30 if ripe else 22
			d.line([(x, ground), (x, ground - stem_h + dy)], fill=p["stem"] + (255,), width=3)
			d.ellipse([x - 10, ground - stem_h, x + 2, ground - stem_h + 12], fill=p["leaf"] + (255,))
			fy = ground - stem_h + 4 + dy
			bw, bh = (12, 28) if ripe else (8, 18)
			col = p["fruit"] if ripe else (100, 140, 80)
			_ellipse(d, [x - bw, fy, x + bw, fy + bh], col + (255,), p["fruit_d"] + (255,), 2)
			_ellipse(d, [x - bw // 2, fy + 4, x, fy + bh // 2], p["fruit_h"] + (160,))
			# chapeau vert
			d.ellipse([x - 8, fy - 6, x + 8, fy + 6], fill=p["accent"] + (255,))
			d.line([(x, fy - 6), (x, fy - 14)], fill=p["stem"] + (255,), width=2)

	elif kind == "carrot":
		positions = [(-30, 0), (-8, 0), (14, 0), (34, 0)] if ripe else [(-14, 0), (14, 0)]
		for dx, _dy in positions:
			x = cx + dx
			# feuilles
			for ox, oy in ((-6, -22), (0, -28), (6, -22), (-3, -18), (3, -18)):
				d.line([(x, ground - 8), (x + ox, ground + oy)], fill=p["leaf"] + (255,), width=2)
			# racine orange (partiellement hors terre)
			top = ground - 6
			bh = 22 if ripe else 14
			bw = 8 if ripe else 5
			d.polygon(
				[(x - bw, top), (x + bw, top), (x + 2, top + bh), (x - 2, top + bh)],
				fill=p["fruit"] + (255,),
				outline=p["fruit_d"] + (255,),
			)
			d.line([(x - 2, top + 4), (x - 1, top + bh - 4)], fill=p["fruit_h"] + (200,), width=2)

	else:  # pepper (jaune lobé)
		positions = [(-28, 0), (-4, -2), (20, 0), (38, -2)] if ripe else [(-14, 0), (16, 0)]
		for i, (dx, dy) in enumerate(positions):
			x = cx + dx
			stem_h = 28 if ripe else 20
			d.line([(x, ground), (x, ground - stem_h + dy)], fill=p["stem"] + (255,), width=3)
			d.ellipse([x - 8, ground - stem_h - 2 + dy, x + 4, ground - stem_h + 10 + dy], fill=p["leaf"] + (255,))
			fy = ground - stem_h + dy
			col = p["fruit"] if ripe else (80, 150, 70)
			bw, bh = (11, 16) if ripe else (7, 11)
			_ellipse(d, [x - bw, fy - 2, x + bw, fy + bh], col + (255,), p["fruit_d"] + (255,), 2)
			_ellipse(d, [x - bw - 3, fy + 4, x - 1, fy + bh + 1], col + (255,))
			_ellipse(d, [x + 1, fy + 4, x + bw + 3, fy + bh + 1], col + (255,))
			_ellipse(d, [x - bw // 2, fy + 2, x, fy + bh // 2], p["fruit_h"] + (150,))
			d.ellipse([x - 4, fy - 6, x + 4, fy + 2], fill=p["accent"] + (255,))
			d.line([(x, fy - 6), (x + 3, fy - 12)], fill=p["stem"] + (255,), width=2)

	return add_outline(img)


def make_icon(kind: str) -> Image.Image:
	"""Icônes UI très simples : formes grosses, contrastées, sans fond sombre."""
	p = PAL[kind]
	img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)

	if kind == "tomato":
		# Tomate ronde rouge + feuilles
		d.ellipse([10, 14, 54, 58], fill=p["fruit"] + (255,))
		d.ellipse([16, 18, 34, 36], fill=p["fruit_h"] + (200,))
		d.ellipse([8, 14, 56, 60], outline=p["fruit_d"] + (255,), width=3)
		# calice en croix
		for ang in (-18, 0, 18):
			d.polygon([(32, 18), (32 + ang, 6), (32 + ang // 2, 20)], fill=p["leaf"] + (255,))
		d.rectangle([30, 4, 34, 14], fill=p["stem"] + (255,))

	elif kind == "eggplant":
		# Aubergine allongée verticale + chapeau
		d.ellipse([18, 16, 46, 58], fill=p["fruit"] + (255,))
		d.ellipse([22, 22, 34, 40], fill=p["fruit_h"] + (170,))
		d.ellipse([16, 16, 48, 60], outline=p["fruit_d"] + (255,), width=3)
		d.ellipse([18, 8, 46, 24], fill=p["leaf"] + (255,))
		d.rectangle([30, 2, 34, 12], fill=p["stem"] + (255,))

	elif kind == "carrot":
		# Carotte conique pointue + fanes
		d.polygon(
			[(32, 14), (46, 24), (36, 60), (28, 60), (18, 24)],
			fill=p["fruit"] + (255,),
		)
		d.line([(31, 26), (31, 54)], fill=p["fruit_h"] + (220,), width=2)
		# fanes bien visibles
		d.line([(32, 16), (18, 2)], fill=p["leaf"] + (255,), width=3)
		d.line([(32, 16), (32, 0)], fill=p["leaf"] + (255,), width=3)
		d.line([(32, 16), (46, 2)], fill=p["leaf"] + (255,), width=3)
		d.ellipse([28, 10, 36, 18], fill=p["accent"] + (255,))

	else:  # pepper jaune lobé
		body = p["fruit"] + (255,)
		d.ellipse([16, 16, 48, 54], fill=body, outline=p["fruit_d"] + (255,), width=3)
		d.ellipse([8, 26, 28, 52], fill=body)
		d.ellipse([36, 26, 56, 52], fill=body)
		d.ellipse([22, 46, 42, 58], fill=body)
		d.ellipse([18, 22, 32, 38], fill=p["fruit_h"] + (160,))
		d.ellipse([28, 8, 36, 20], fill=p["accent"] + (255,))
		d.polygon([(32, 14), (20, 6), (28, 16)], fill=p["accent"] + (255,))
		d.polygon([(32, 14), (44, 6), (36, 16)], fill=p["accent"] + (255,))
		d.line([(32, 10), (36, 2)], fill=p["stem"] + (255,), width=3)

	return add_outline(img, color=(18, 14, 10, 230))


def main() -> None:
	# Régénère uniquement les icônes (pas les stages de plantes)
	for kind in CROPS:
		ip = TEX / "icons" / f"{kind}.png"
		ip.parent.mkdir(parents=True, exist_ok=True)
		make_icon(kind).save(ip)
		print("wrote", ip.relative_to(ROOT))
	print("Done — icons only.")


if __name__ == "__main__":
	main()
