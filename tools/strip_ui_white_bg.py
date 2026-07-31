"""Strip white backgrounds from automation / lock UI icons."""
from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image

UI = Path(__file__).resolve().parents[1] / "assets" / "textures" / "ui"
FILES = [
	"lock.png",
	"fertilizer.png",
	"auto_planter.png",
	"auto_harvester.png",
	"auto_delivery.png",
	"shop_speed.png",
	"shop_click.png",
	"shop_frenzy.png",
	"shop_plot.png",
	"player_avatar.png",
	*[f"client_{i}.png" for i in range(12)],
]


def is_bg(
	r: int,
	g: int,
	b: int,
	corner: tuple[int, int, int],
	*,
	lum_min: int,
	thr: int,
) -> bool:
	lum = (r + g + b) / 3.0
	if lum < lum_min:
		return False
	if max(r, g, b) - min(r, g, b) > 14:
		return False
	d = abs(r - corner[0]) + abs(g - corner[1]) + abs(b - corner[2])
	return d <= thr or lum >= max(lum_min, 248)


def remove_bg(im: Image.Image, *, lock_mode: bool = False) -> Image.Image:
	im = im.convert("RGBA")
	w, h = im.size
	px = im.load()
	corner = px[2, 2][:3]
	## Cadenas : corps ~239 vs fond ~254 — seuil plus strict pour ne pas manger le dessin.
	lum_min = 248 if lock_mode else 232
	thr = 14 if lock_mode else 32
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
		r, g, b, _a = px[x, y]
		if not is_bg(r, g, b, corner, lum_min=lum_min, thr=thr):
			continue
		px[x, y] = (r, g, b, 0)
		for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
			if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
				q.append((nx, ny))
	## Frange pâle collée au transparent (sauf cadenas : garder le blanc du corps).
	if not lock_mode:
		for y in range(h):
			for x in range(w):
				r, g, b, a = px[x, y]
				if a == 0:
					continue
				if min(r, g, b) >= 245 and max(r, g, b) - min(r, g, b) <= 8:
					for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
						if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 0:
							px[x, y] = (r, g, b, 0)
							break
	return im


def crop_content(im: Image.Image, pad_ratio: float = 0.06) -> Image.Image:
	bbox = im.getbbox()
	if not bbox:
		return im
	l, t, r, b = bbox
	bw, bh = r - l, b - t
	pad = int(max(bw, bh) * pad_ratio)
	l = max(0, l - pad)
	t = max(0, t - pad)
	r = min(im.width, r + pad)
	b = min(im.height, b + pad)
	return im.crop((l, t, r, b))


def fit_square(im: Image.Image, size: int = 256) -> Image.Image:
	im = im.copy()
	target = int(size * 0.92)
	im.thumbnail((target, target), Image.Resampling.LANCZOS)
	canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	x = (size - im.width) // 2
	y = (size - im.height) // 2
	canvas.paste(im, (x, y), im)
	return canvas


def main() -> None:
	for name in FILES:
		src = UI / name
		lock_mode = name == "lock.png"
		out = remove_bg(Image.open(src), lock_mode=lock_mode)
		out = crop_content(out)
		if lock_mode:
			px = out.load()
			for y in range(out.height):
				for x in range(out.width):
					_r, _g, _b, a = px[x, y]
					if a == 0:
						continue
					px[x, y] = (255, 255, 255, a)
		out = fit_square(out, 256)
		out.save(src, optimize=True)
		px = out.load()
		trans = sum(1 for y in range(out.height) for x in range(out.width) if px[x, y][3] < 10)
		print(f"{name}: {out.size}, transparent={trans}, corner={px[0, 0]}")


if __name__ == "__main__":
	main()
