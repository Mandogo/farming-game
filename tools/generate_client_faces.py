"""Portraits clients — cozy opaque pixel, lisible en 28–36px."""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
UI = ROOT / "assets" / "textures" / "ui"


def mix(a: tuple, b: tuple, t: float) -> tuple[int, int, int]:
	return tuple(int(round(a[i] * (1 - t) + b[i] * t)) for i in range(3))


def darker(c: tuple, amount: float = 0.18) -> tuple[int, int, int]:
	return mix(c, (20, 16, 14), amount)


def lighter(c: tuple, amount: float = 0.22) -> tuple[int, int, int]:
	return mix(c, (255, 255, 255), amount)


SKINS = [
	(242, 198, 168),
	(228, 180, 148),
	(210, 158, 122),
	(188, 138, 105),
	(168, 118, 88),
	(238, 205, 178),
]

HAIRS = [
	(58, 42, 34),
	(110, 78, 48),
	(195, 155, 85),
	(42, 42, 50),
	(165, 80, 60),
	(70, 105, 68),
	(118, 85, 148),
	(210, 200, 190),
]

SHIRTS = [
	(70, 140, 165),
	(190, 95, 85),
	(75, 150, 105),
	(180, 140, 70),
	(120, 95, 160),
	(70, 80, 100),
	(205, 150, 100),
	(90, 135, 145),
]

IRISES = [
	(80, 120, 150),
	(90, 130, 90),
	(120, 90, 60),
	(95, 110, 145),
]


def outline(src: Image.Image, color=(36, 28, 24, 230)) -> Image.Image:
	a = src.split()[-1]
	w, h = src.size
	ring = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	px = ring.load()
	alpha = a.load()
	for y in range(h):
		for x in range(w):
			if alpha[x, y] < 20:
				continue
			edge = False
			for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
				nx, ny = x + dx, y + dy
				if not (0 <= nx < w and 0 <= ny < h) or alpha[nx, ny] < 20:
					edge = True
					break
			if edge:
				for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
					nx, ny = x + dx, y + dy
					if 0 <= nx < w and 0 <= ny < h and alpha[nx, ny] < 20:
						px[nx, ny] = color
	out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	out.alpha_composite(ring)
	out.alpha_composite(src)
	return out


def make_face(seed: int) -> Image.Image:
	s = 64
	img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)

	skin = SKINS[seed % len(SKINS)]
	skin_hi = lighter(skin, 0.28)
	skin_sh = darker(skin, 0.22)
	blush = mix(skin, (235, 130, 125), 0.28)
	hair = HAIRS[(seed * 3) % len(HAIRS)]
	hair_hi = lighter(hair, 0.25)
	hair_sh = darker(hair, 0.2)
	shirt = SHIRTS[(seed * 5) % len(SHIRTS)]
	shirt_d = darker(shirt, 0.22)
	iris = IRISES[seed % len(IRISES)]
	style = seed % 5

	# --- shoulders ---
	d.ellipse([5, 49, 58, 76], fill=(*shirt_d, 255))
	d.ellipse([8, 51, 55, 74], fill=(*shirt, 255))
	d.ellipse([24, 54, 41, 66], fill=(*shirt_d, 255))

	# --- neck ---
	d.rectangle([28, 44, 37, 54], fill=(*skin_sh, 255))
	d.rectangle([29, 44, 36, 52], fill=(*skin, 255))

	# --- hair back / sides (behind head) ---
	if style == 0:  # bob
		d.ellipse([11, 8, 54, 40], fill=(*hair, 255))
		d.ellipse([10, 22, 23, 50], fill=(*hair, 255))
		d.ellipse([42, 22, 55, 50], fill=(*hair, 255))
		d.ellipse([12, 24, 22, 48], fill=(*hair_sh, 255))
		d.ellipse([43, 24, 53, 48], fill=(*hair_sh, 255))
	elif style == 1:  # short
		d.ellipse([12, 8, 53, 34], fill=(*hair, 255))
		d.ellipse([11, 20, 20, 40], fill=(*hair, 255))
		d.ellipse([45, 20, 54, 40], fill=(*hair, 255))
	elif style == 2:  # curly
		for cx, cy, r in (
			(20, 14, 10), (32, 9, 12), (45, 14, 10),
			(14, 26, 8), (51, 26, 8), (32, 16, 9),
		):
			d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*hair, 255))
	elif style == 3:  # slick
		d.ellipse([14, 9, 51, 30], fill=(*hair, 255))
		d.ellipse([12, 18, 19, 36], fill=(*hair, 255))
		d.ellipse([46, 18, 53, 36], fill=(*hair, 255))
	else:  # ponytail
		d.ellipse([12, 8, 53, 32], fill=(*hair, 255))
		d.ellipse([43, 26, 58, 48], fill=(*hair, 255))
		d.ellipse([45, 28, 55, 42], fill=(*hair_sh, 255))

	# --- head ---
	d.ellipse([15, 13, 50, 52], fill=(*skin_sh, 255))
	d.ellipse([16, 12, 49, 50], fill=(*skin, 255))

	# ears
	d.ellipse([11, 28, 19, 40], fill=(*skin, 255))
	d.ellipse([46, 28, 54, 40], fill=(*skin, 255))
	d.ellipse([13, 30, 17, 36], fill=(*skin_hi, 255))
	d.ellipse([48, 30, 52, 36], fill=(*skin_hi, 255))

	# --- fringe (forehead only, above eyes) ---
	if style in (0, 1, 4):
		d.chord([17, 12, 48, 32], 200, 340, fill=(*hair, 255))
		d.ellipse([22, 10, 38, 20], fill=(*hair_hi, 255))
	elif style == 2:
		d.ellipse([22, 14, 31, 24], fill=(*hair, 255))
		d.ellipse([34, 14, 43, 24], fill=(*hair, 255))
		d.ellipse([26, 10, 40, 18], fill=(*hair_hi, 255))
	else:
		d.chord([18, 11, 44, 28], 210, 330, fill=(*hair, 255))
		d.ellipse([20, 10, 34, 18], fill=(*hair_hi, 255))

	# soft cheek light (below eyes, left side only — subtle volume)
	d.ellipse([19, 34, 27, 42], fill=(*skin_hi, 255))

	# brows
	brow = darker(hair, 0.15)
	d.line([(21, 27), (28, 26)], fill=(*brow, 255), width=2)
	d.line([(37, 26), (44, 27)], fill=(*brow, 255), width=2)

	# eyes — small, friendly
	ey = 30
	# lids shadow
	d.ellipse([20, ey - 1, 28, ey + 3], fill=(*skin_sh, 255))
	d.ellipse([37, ey - 1, 45, ey + 3], fill=(*skin_sh, 255))
	# whites
	d.ellipse([20, ey, 28, ey + 6], fill=(250, 248, 245, 255))
	d.ellipse([37, ey, 45, ey + 6], fill=(250, 248, 245, 255))
	# iris
	d.ellipse([22, ey + 1, 27, ey + 5], fill=(*iris, 255))
	d.ellipse([39, ey + 1, 44, ey + 5], fill=(*iris, 255))
	# pupil
	d.ellipse([23, ey + 2, 26, ey + 5], fill=(30, 24, 22, 255))
	d.ellipse([40, ey + 2, 43, ey + 5], fill=(30, 24, 22, 255))
	# shine
	d.point((24, ey + 2), fill=(255, 255, 255, 255))
	d.point((41, ey + 2), fill=(255, 255, 255, 255))

	# blush — opaque mix, subtle
	d.ellipse([17, 37, 24, 42], fill=(*blush, 255))
	d.ellipse([41, 37, 48, 42], fill=(*blush, 255))

	# nose
	d.line([(32, 34), (30, 38)], fill=(*skin_sh, 255), width=1)

	# smile (always friendly for shop clients)
	d.arc([25, 39, 40, 48], 20, 160, fill=(175, 90, 85, 255), width=2)

	return outline(img)


def main() -> None:
	UI.mkdir(parents=True, exist_ok=True)
	for i in range(12):
		p = UI / f"client_{i}.png"
		make_face(11 + i * 19).save(p)
		print("wrote", p.name, p.stat().st_size)


if __name__ == "__main__":
	main()
