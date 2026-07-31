"""Icônes UI polish : sac inventaire, check, cancel, touche."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
UI = ROOT / "assets" / "textures" / "ui"


def add_outline(img: Image.Image, color=(16, 10, 6, 230)) -> Image.Image:
	a = img.split()[-1]
	w, h = img.size
	out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	op, alpha = out.load(), a.load()
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


def save(img: Image.Image, name: str) -> None:
	UI.mkdir(parents=True, exist_ok=True)
	p = UI / f"{name}.png"
	img.save(p)
	print("wrote", p.relative_to(ROOT))


def make_seed_bag() -> Image.Image:
	img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	# ombre
	d.ellipse([10, 48, 54, 58], fill=(20, 15, 10, 90))
	# sac
	d.rounded_rectangle([14, 18, 50, 52], radius=8, fill=(160, 110, 55, 255), outline=(90, 55, 25, 255), width=2)
	d.rounded_rectangle([18, 22, 46, 34], radius=4, fill=(190, 140, 75, 200))
	# cordon
	d.arc([22, 12, 42, 28], 200, 340, fill=(70, 50, 30, 255), width=3)
	d.ellipse([28, 10, 36, 18], fill=(210, 170, 80, 255), outline=(120, 80, 30, 255))
	# patch
	d.rounded_rectangle([26, 36, 38, 46], radius=3, fill=(70, 130, 70, 255), outline=(40, 80, 40, 255))
	d.ellipse([29, 38, 35, 44], fill=(255, 220, 80, 255))
	return add_outline(img)


def make_btn_check() -> Image.Image:
	"""Glyphe ✓ uniquement — le fond vient du StyleBox."""
	img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	d.line([(7, 16), (13, 23), (25, 9)], fill=(255, 255, 250, 255), width=3)
	return img


def make_btn_cancel() -> Image.Image:
	"""Glyphe ✕ uniquement — le fond vient du StyleBox."""
	img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	d.line([(9, 9), (23, 23)], fill=(255, 248, 248, 255), width=3)
	d.line([(23, 9), (9, 23)], fill=(255, 248, 248, 255), width=3)
	return img


def make_keycap() -> Image.Image:
	img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	d.rounded_rectangle([2, 2, 29, 29], radius=6, fill=(35, 48, 40, 255), outline=(80, 120, 70, 255), width=2)
	d.rounded_rectangle([5, 4, 26, 14], radius=3, fill=(55, 75, 60, 120))
	return add_outline(img)


def main() -> None:
	save(make_seed_bag(), "seed_bag")
	save(make_btn_check(), "btn_check")
	save(make_btn_cancel(), "btn_cancel")
	save(make_keycap(), "keycap")
	print("Done polish icons.")


if __name__ == "__main__":
	main()
