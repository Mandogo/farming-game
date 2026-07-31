"""Agrandit le contenu des sprites cultures dans le canvas 160x280 (ancré au sol)."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "assets" / "textures" / "crops"
SCALE = 1.45
GROUND_Y = 171  # ligne de sol dans le canvas iso


def enlarge(path: Path) -> None:
	src = Image.open(path).convert("RGBA")
	w, h = src.size
	# bbox contenu
	a = src.split()[-1]
	bbox = a.getbbox()
	if not bbox:
		return
	crop = src.crop(bbox)
	nw = max(1, int(round(crop.width * SCALE)))
	nh = max(1, int(round(crop.height * SCALE)))
	big = crop.resize((nw, nh), Image.Resampling.NEAREST)

	out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	# Centrer horizontalement, bas ancré sur GROUND_Y
	cx = (bbox[0] + bbox[2]) / 2.0
	x = int(round(cx - nw / 2.0))
	y = GROUND_Y - nh
	x = max(0, min(w - nw, x))
	y = max(0, min(h - nh, y))
	out.alpha_composite(big, (x, y))
	out.save(path)
	print(path.name, bbox, "->", (x, y, x + nw, y + nh))


def main() -> None:
	for crop_dir in sorted(ROOT.iterdir()):
		if not crop_dir.is_dir():
			continue
		for stage in crop_dir.glob("stage_*.png"):
			enlarge(stage)


if __name__ == "__main__":
	main()
