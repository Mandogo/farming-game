"""Force fonds vraiment transparents (noir, blanc, magenta, damier) sur les icônes UI."""
from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image

UI = Path(r"c:\Users\quent\Documents\Projets\15. New project\greenhouse-idle\assets\textures\ui")
SRC = Path(r"C:\Users\quent\.cursor\projects\c-Users-quent-Documents-Projets-15-New-project-greenhouse-idle\assets")

# Préférer les sources Cursor si présentes, sinon fichiers UI actuels.
NAMES = [
	"coin", "coin_gold", "coin_prestige", "coin_skill",
	"logo", "mission", "prestige", "skill_tree", "lock",
	"mouse_left", "shop_speed", "shop_plot", "shop_frenzy", "shop_money", "shop_click",
	"tab_shop", "tab_prestige", "truck", "chrono", "xp", "combo", "target", "sparkle",
	"btn_check", "btn_cancel", "click_hand", "settings", "fertilizer",
]


def is_magenta(r: int, g: int, b: int) -> bool:
	return r >= 200 and b >= 200 and g <= 80


def is_black(r: int, g: int, b: int) -> bool:
	return r <= 28 and g <= 28 and b <= 28


def is_white(r: int, g: int, b: int) -> bool:
	lum = (r + g + b) / 3.0
	sat = max(r, g, b) - min(r, g, b)
	return lum >= 235 and sat <= 18


def is_checker(r: int, g: int, b: int) -> bool:
	## Damier faux-transparent gris/blanc.
	lum = (r + g + b) / 3.0
	sat = max(r, g, b) - min(r, g, b)
	if sat > 12:
		return False
	return 140 <= lum <= 230 or lum >= 235


def is_bg_pixel(r: int, g: int, b: int) -> bool:
	return is_magenta(r, g, b) or is_black(r, g, b) or is_white(r, g, b) or is_checker(r, g, b)


def flood_clear(im: Image.Image) -> None:
	w, h = im.size
	px = im.load()
	visited = [[False] * w for _ in range(h)]
	q: deque[tuple[int, int]] = deque()
	for x in range(w):
		q.append((x, 0))
		q.append((x, h - 1))
	for y in range(h):
		q.append((0, y))
		q.append((w - 1, y))
	while q:
		x, y = q.popleft()
		if x < 0 or y < 0 or x >= w or y >= h or visited[y][x]:
			continue
		visited[y][x] = True
		r, g, b, a = px[x, y]
		if a == 0:
			for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
				if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
					q.append((nx, ny))
			continue
		if not is_bg_pixel(r, g, b):
			continue
		px[x, y] = (0, 0, 0, 0)
		for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
			if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
				q.append((nx, ny))


def scrub_fringe(im: Image.Image) -> None:
	"""Efface damier / franges / ombres collées au transparent."""
	w, h = im.size
	px = im.load()
	## 1) Tous les pixels damier / gris désaturés (faux transparent).
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if a == 0:
				continue
			if is_magenta(r, g, b) or is_checker(r, g, b):
				px[x, y] = (0, 0, 0, 0)
				continue
			lum = (r + g + b) / 3.0
			sat = max(r, g, b) - min(r, g, b)
			if sat <= 16 and lum >= 100:
				px[x, y] = (0, 0, 0, 0)
	## 2) Ombres noires en bordure du sujet.
	for _ in range(3):
		to_clear: list[tuple[int, int]] = []
		for y in range(h):
			for x in range(w):
				r, g, b, a = px[x, y]
				if a == 0:
					continue
				touch = False
				for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
					if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 0:
						touch = True
						break
				if not touch:
					continue
				if (r <= 45 and g <= 45 and b <= 45) or (a < 200 and r + g + b < 90):
					to_clear.append((x, y))
				elif is_white(r, g, b) or is_checker(r, g, b):
					to_clear.append((x, y))
		for x, y in to_clear:
			px[x, y] = (0, 0, 0, 0)
	## 3) Alpha binaire propre.
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if a == 0:
				continue
			if a < 40:
				px[x, y] = (0, 0, 0, 0)
			elif a < 255:
				px[x, y] = (r, g, b, 255)


def fit(im: Image.Image, size: int = 256) -> Image.Image:
	bb = im.getbbox()
	if not bb:
		return Image.new("RGBA", (size, size), (0, 0, 0, 0))
	c = im.crop(bb)
	c.thumbnail((int(size * 0.92), int(size * 0.92)), Image.Resampling.LANCZOS)
	out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	out.paste(c, ((size - c.width) // 2, (size - c.height) // 2), c)
	return out


def process(path: Path) -> Image.Image:
	im = Image.open(path).convert("RGBA")
	## Remplace magenta plein cadre en transparent avant flood.
	px = im.load()
	w, h = im.size
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if is_magenta(r, g, b):
				px[x, y] = (0, 0, 0, 0)
	flood_clear(im)
	scrub_fringe(im)
	flood_clear(im)  # 2e passe après fringe
	return fit(im)


def main() -> None:
	for name in NAMES:
		src = SRC / f"{name}.png"
		if not src.exists():
			src = UI / f"{name}.png"
		if not src.exists():
			print("MISSING", name)
			continue
		out = process(src)
		dest = UI / f"{name}.png"
		out.save(dest, optimize=True)
		# stats
		px = out.load()
		w, h = out.size
		corners = [px[0, 0][3], px[w - 1, 0][3], px[0, h - 1][3], px[w - 1, h - 1][3]]
		black = sum(
			1
			for y in range(h)
			for x in range(w)
			if px[x, y][3] > 200 and sum(px[x, y][:3]) < 40
		)
		print(f"{name}: corners_a={corners} blackish={black} bbox={out.getbbox()}")
	# alias
	(UI / "coin.png").write_bytes((UI / "coin_gold.png").read_bytes())
	print("coin aliased")


if __name__ == "__main__":
	main()
