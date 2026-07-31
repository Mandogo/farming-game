"""Icônes monnaies : or (pièces), bleu (compétences), rose (prestige)."""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "textures" / "ui"


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


def coin(body, hi, dark, mark) -> Image.Image:
	img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	d.ellipse([2, 2, 29, 29], fill=body + (255,), outline=dark + (255,), width=2)
	d.ellipse([6, 6, 25, 25], fill=hi + (255,))
	d.ellipse([9, 8, 15, 14], fill=(255, 255, 255, 90))
	# marque centrale (cercle / point)
	d.ellipse([13, 12, 19, 20], outline=mark + (255,), width=2)
	d.line([(16, 10), (16, 22)], fill=mark + (255,), width=2)
	return add_outline(img)


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	# Or — pièces
	coin((220, 170, 40), (255, 215, 80), (150, 100, 18), (150, 100, 18)).save(OUT / "coin_gold.png")
	# Bleu — compétences
	coin((55, 130, 210), (120, 190, 255), (25, 70, 130), (20, 55, 110)).save(OUT / "coin_skill.png")
	# Rose — prestige
	coin((210, 70, 140), (255, 140, 190), (130, 30, 80), (120, 25, 70)).save(OUT / "coin_prestige.png")
	print("wrote coin_gold, coin_skill, coin_prestige")


if __name__ == "__main__":
	main()
