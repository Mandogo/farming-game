"""Process crop growth stage sprites → transparent 160x280 for plots."""
from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image

SRC = Path(r"C:\Users\quent\.cursor\projects\c-Users-quent-Documents-Projets-15-New-project-greenhouse-idle\assets")
DST = Path(r"c:\Users\quent\Documents\Projets\15. New project\greenhouse-idle\assets\textures\crops")
CROPS = ["tomato", "carrot", "pepper", "eggplant", "mushroom", "broccoli"]
OUT_W, OUT_H = 160, 280


def is_pale_bg(r: int, g: int, b: int, corner: tuple[int, int, int]) -> bool:
	lum = (r + g + b) / 3.0
	sat = max(r, g, b) - min(r, g, b)
	d = abs(r - corner[0]) + abs(g - corner[1]) + abs(b - corner[2])
	if lum >= 245 and sat <= 18:
		return True
	if d <= 42 and lum >= 225 and sat <= 28:
		return True
	if lum >= 235 and sat <= 12:
		return True
	return False


def is_soil(r: int, g: int, b: int) -> bool:
	## Terre brun-mat uniquement — pas fruits / feuilles / chapeaux.
	if g >= r - 5 and g > b + 10:
		return False
	if r > 160 and g < 100 and b < 100:
		return False
	if r > 180 and g > 80 and g < 160 and b < 80:
		return False
	if r > 70 and b > 90 and g < 100:
		return False
	lum = (r + g + b) / 3.0
	sat = max(r, g, b) - min(r, g, b)
	if lum < 35 or lum > 145:
		return False
	if sat > 70:
		return False
	if r >= g >= max(0, b - 8) and (r - b) >= 12 and (r - g) <= 40:
		return True
	return False


def flood_clear(im: Image.Image, predicate) -> None:
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
		if not predicate(r, g, b):
			continue
		px[x, y] = (0, 0, 0, 0)
		for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
			if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
				q.append((nx, ny))


def clear_enclosed_white(im: Image.Image) -> None:
	w, h = im.size
	px = im.load()
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if a == 0:
				continue
			lum = (r + g + b) / 3.0
			sat = max(r, g, b) - min(r, g, b)
			## Blanc pur résiduel uniquement (évite de manger tiges crème champignon).
			if lum >= 248 and sat <= 12:
				px[x, y] = (0, 0, 0, 0)


def remove_bg(im: Image.Image) -> Image.Image:
	im = im.convert("RGBA")
	px = im.load()
	corner = px[2, 2][:3]
	flood_clear(im, lambda r, g, b: is_pale_bg(r, g, b, corner))
	flood_clear(im, is_soil)
	clear_enclosed_white(im)
	w, h = im.size
	px = im.load()
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if a == 0:
				continue
			lum = (r + g + b) / 3.0
			sat = max(r, g, b) - min(r, g, b)
			if lum >= 240 and sat <= 20:
				for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
					if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 0:
						px[x, y] = (0, 0, 0, 0)
						break
			elif a < 40:
				px[x, y] = (0, 0, 0, 0)
			elif a < 255:
				px[x, y] = (r, g, b, 255)
	return im


def _harden_alpha(im: Image.Image) -> Image.Image:
	"""Alpha binaire : évite un halo qui décale le bbox bas selon le stage."""
	px = im.load()
	w, h = im.size
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if a < 50:
				px[x, y] = (0, 0, 0, 0)
			elif a < 255:
				px[x, y] = (r, g, b, 255)
	return im


def fit_portrait(im: Image.Image, out_w: int = OUT_W, out_h: int = OUT_H, stage: int = 6, crop: str = "") -> Image.Image:
	"""
	Contrat avec plot_tile.gd :
	- largeur fixe out_w, contenu centré en X
	- pixels opaques collés en bas (pas de padding bas) → pieds = bas de l'image
	- hauteur = contenu + petit pad haut seulement
	"""
	bbox = im.getbbox()
	if not bbox:
		return Image.new("RGBA", (out_w, 1), (0, 0, 0, 0))
	cropped = _harden_alpha(im.crop(bbox))
	## Progression de taille entre stages (cadre de référence 280).
	stage_h = {1: 0.58, 2: 0.68, 3: 0.78, 4: 0.86, 5: 0.92, 6: 0.96}
	## Multiplicateurs par culture/stage (corrige sources trop larges / trop hautes).
	extra = {
		"pepper": {1: 0.70, 2: 0.74},
		"carrot": {6: 0.92},
	}.get(crop, {}).get(stage, 1.0)
	mul = (0.95 if crop == "carrot" else 1.0) * extra
	max_h = int(out_h * stage_h.get(stage, 0.85) * mul)
	pw = 0.78 if crop == "pepper" and stage == 1 else (0.80 if crop == "pepper" and stage == 2 else 0.94)
	max_w = int(out_w * pw * mul)
	cropped.thumbnail((max_w, max_h), Image.Resampling.LANCZOS)
	cropped = _harden_alpha(cropped)
	bb = cropped.getbbox()
	if not bb:
		return Image.new("RGBA", (out_w, 1), (0, 0, 0, 0))
	cropped = cropped.crop(bb)
	top_pad = 2
	final_h = cropped.height + top_pad
	canvas = Image.new("RGBA", (out_w, final_h), (0, 0, 0, 0))
	x = (out_w - cropped.width) // 2
	## Pieds collés au bord bas — plot_tile ancre ce bord sur le centre dirt.
	canvas.paste(cropped, (x, top_pad), cropped)
	return canvas


def main() -> None:
	for crop in CROPS:
		out_dir = DST / crop
		out_dir.mkdir(parents=True, exist_ok=True)
		for stage in range(1, 7):
			src = SRC / f"{crop}_s{stage}.png"
			if not src.exists():
				print("MISSING", src.name)
				continue
			out = fit_portrait(remove_bg(Image.open(src)), stage=stage, crop=crop)
			dest = out_dir / f"stage_{stage}.png"
			out.save(dest, optimize=True)
			print(f"{crop}/stage_{stage}.png bbox={out.getbbox()}")


if __name__ == "__main__":
	main()
