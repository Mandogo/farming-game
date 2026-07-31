"""Restructure assets/textures for face-based iso blocks (top + sides)."""
from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
TEX = ROOT / "assets" / "textures"
LEGACY = TEX / "_legacy"


def ensure(p: Path) -> Path:
	p.mkdir(parents=True, exist_ok=True)
	return p


def move_if(src: Path, dst: Path) -> None:
	if not src.exists():
		return
	ensure(dst.parent)
	if dst.exists():
		dst.unlink()
	shutil.move(str(src), str(dst))
	imp = Path(str(src) + ".import")
	if imp.exists():
		imp.unlink()


def copy_if(src: Path, dst: Path) -> None:
	if not src.exists():
		return
	ensure(dst.parent)
	shutil.copy2(src, dst)


def make_soil_faces(name: str, top_rgb: tuple[int, int, int], side_rgb: tuple[int, int, int], seed: int) -> None:
	"""Génère top 128x128 + side 64x48 placeholders pixel art."""
	import random

	rng = random.Random(seed)
	block = ensure(TEX / "blocks" / name)

	top = Image.new("RGBA", (128, 128), (*top_rgb, 255))
	px = top.load()
	for y in range(128):
		for x in range(128):
			n = rng.randint(-18, 18)
			r = max(0, min(255, top_rgb[0] + n))
			g = max(0, min(255, top_rgb[1] + n))
			b = max(0, min(255, top_rgb[2] + n // 2))
			px[x, y] = (r, g, b, 255)
	# sillons légers
	for y in range(8, 120, 10):
		for x in range(128):
			if rng.random() < 0.55:
				c = px[x, y]
				px[x, y] = (max(0, c[0] - 12), max(0, c[1] - 10), max(0, c[2] - 8), 255)
	top.save(block / "top.png")

	side = Image.new("RGBA", (64, 48), (*side_rgb, 255))
	sp = side.load()
	for y in range(48):
		shade = int((y / 47.0) * 22)
		for x in range(64):
			n = rng.randint(-10, 10)
			r = max(0, min(255, side_rgb[0] - shade + n))
			g = max(0, min(255, side_rgb[1] - shade + n))
			b = max(0, min(255, side_rgb[2] - shade + n // 2))
			sp[x, y] = (r, g, b, 255)
	# strates
	d = ImageDraw.Draw(side)
	for y in (12, 24, 36):
		col = tuple(max(0, c - 20) for c in side_rgb) + (255,)
		d.line([(0, y), (63, y)], fill=col)
	side.save(block / "side.png")


def make_grass_faces() -> None:
	make_soil_faces("grass", (78, 140, 70), (48, 90, 45), 11)
	# plus d'herbe sur le dessus
	block = TEX / "blocks" / "grass"
	top = Image.open(block / "top.png").convert("RGBA")
	px = top.load()
	import random

	rng = random.Random(99)
	for _ in range(900):
		x, y = rng.randint(0, 127), rng.randint(0, 127)
		g = rng.choice([(90, 160, 80), (60, 120, 55), (110, 175, 95)])
		px[x, y] = (*g, 255)
	top.save(block / "top.png")


def migrate() -> None:
	ensure(TEX / "blocks")
	ensure(TEX / "crops")
	ensure(TEX / "icons")
	ensure(TEX / "ui")
	ensure(TEX / "backgrounds")
	ensure(LEGACY)

	# Archive anciens iso complets
	for name in ("soil_empty", "soil_locked", "grass_iso"):
		src = TEX / f"{name}.png"
		if src.exists():
			move_if(src, LEGACY / f"{name}.png")

	# Cultures
	for crop in ("wheat", "barley", "oat", "corn"):
		folder = ensure(TEX / "crops" / crop)
		for stage in range(1, 5):
			src = TEX / f"{crop}_{stage}.png"
			move_if(src, folder / f"stage_{stage}.png")

	# Icônes
	for crop in ("wheat", "barley", "oat", "corn"):
		src = TEX / f"icon_{crop}.png"
		move_if(src, TEX / "icons" / f"{crop}.png")

	# UI
	ui_names = [
		"coin", "seed_bag", "scythe", "heat", "mission", "upgrade", "prestige",
		"waterer", "harvester", "planter", "sparkle", "mouse_left", "mouse_right",
		"combo", "corner",
	]
	for n in ui_names:
		src = TEX / f"ui_{n}.png"
		move_if(src, TEX / "ui" / f"{n}.png")

	# Fonds
	move_if(TEX / "sky_bg.png", TEX / "backgrounds" / "sky.png")
	move_if(TEX / "field_bg.png", TEX / "backgrounds" / "field.png")

	# Nettoyer _import (previews / backups)
	imp = TEX / "_import"
	if imp.exists():
		shutil.rmtree(imp, ignore_errors=True)

	# Faces source (placeholders — à remplacer par tes PNG)
	make_soil_faces("soil", (118, 82, 52), (72, 48, 30), 42)
	make_grass_faces()

	print("Restructured under", TEX)


if __name__ == "__main__":
	migrate()
