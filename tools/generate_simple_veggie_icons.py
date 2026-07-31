"""Génère uniquement des icônes légumes simples et lisibles."""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "textures" / "icons"

PAL = {
	"tomato": {"body": (230, 50, 40), "hi": (255, 120, 90), "dark": (150, 25, 25), "leaf": (60, 160, 55), "stem": (40, 110, 40)},
	"carrot": {"body": (240, 120, 30), "hi": (255, 180, 80), "dark": (180, 70, 15), "leaf": (70, 175, 60), "stem": (40, 110, 40)},
	"pepper": {"body": (245, 198, 40), "hi": (255, 235, 130), "dark": (195, 140, 18), "leaf": (70, 155, 55), "stem": (55, 130, 50)},
	"eggplant": {"body": (120, 50, 160), "hi": (170, 100, 200), "dark": (70, 25, 100), "leaf": (60, 150, 55), "stem": (40, 110, 40)},
}


def outline(img: Image.Image, color=(15, 12, 10, 230)) -> Image.Image:
	a = img.split()[-1]
	w, h = img.size
	base = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	px = base.load()
	alpha = a.load()
	for y in range(h):
		for x in range(w):
			if alpha[x, y] < 100:
				continue
			for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, 1), (-1, 1), (1, -1)):
				nx, ny = x + dx, y + dy
				if 0 <= nx < w and 0 <= ny < h and alpha[nx, ny] < 100:
					px[nx, ny] = color
	out = Image.alpha_composite(base, img)
	return out


def icon_tomato(d: ImageDraw.ImageDraw, p):
	d.ellipse([10, 14, 54, 58], fill=p["body"] + (255,))
	d.ellipse([16, 18, 34, 36], fill=p["hi"] + (180,))
	# calice en 3 feuilles
	d.polygon([(32, 18), (18, 8), (26, 20)], fill=p["leaf"] + (255,))
	d.polygon([(32, 18), (46, 8), (38, 20)], fill=p["leaf"] + (255,))
	d.polygon([(32, 18), (32, 6), (40, 16)], fill=p["leaf"] + (255,))
	d.rectangle([30, 4, 34, 14], fill=p["stem"] + (255,))


def icon_carrot(d: ImageDraw.ImageDraw, p):
	d.polygon([(32, 14), (48, 24), (36, 60), (28, 60), (16, 24)], fill=p["body"] + (255,))
	d.line([(31, 26), (31, 54)], fill=p["hi"] + (220,), width=3)
	for x2 in (18, 32, 46):
		d.line([(32, 16), (x2, 2)], fill=p["leaf"] + (255,), width=3)


def icon_pepper(d: ImageDraw.ImageDraw, p):
	# poivron jaune lobé + calice
	d.ellipse([16, 16, 48, 54], fill=p["body"] + (255,))
	d.ellipse([8, 26, 28, 52], fill=p["body"] + (255,))
	d.ellipse([36, 26, 56, 52], fill=p["body"] + (255,))
	d.ellipse([22, 46, 42, 58], fill=p["body"] + (255,))
	d.ellipse([18, 22, 32, 38], fill=p["hi"] + (160,))
	d.ellipse([26, 10, 38, 22], fill=p["leaf"] + (255,))
	d.polygon([(32, 14), (20, 6), (28, 16)], fill=p["leaf"] + (255,))
	d.polygon([(32, 14), (44, 6), (36, 16)], fill=p["leaf"] + (255,))
	d.line([(32, 10), (36, 2)], fill=p["stem"] + (255,), width=3)


def icon_eggplant(d: ImageDraw.ImageDraw, p):
	d.ellipse([18, 16, 46, 58], fill=p["body"] + (255,))
	d.ellipse([22, 22, 34, 40], fill=p["hi"] + (160,))
	d.ellipse([16, 8, 48, 24], fill=p["leaf"] + (255,))
	d.rectangle([30, 2, 34, 12], fill=p["stem"] + (255,))


FUNCS = {
	"tomato": icon_tomato,
	"carrot": icon_carrot,
	"pepper": icon_pepper,
	"eggplant": icon_eggplant,
}


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	for kind, fn in FUNCS.items():
		img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
		d = ImageDraw.Draw(img)
		fn(d, PAL[kind])
		img = outline(img)
		path = OUT / f"{kind}.png"
		img.save(path)
		print("wrote", path, path.stat().st_size)


if __name__ == "__main__":
	main()
