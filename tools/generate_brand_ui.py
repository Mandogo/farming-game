"""Logo, monnaie thématique et icônes shop — Greenhouse Idle.

Sortie : assets/textures/ui/*.png + icon.svg (projet)
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
UI = ROOT / "assets" / "textures" / "ui"
OUTLINE = (18, 12, 8, 235)


def clamp(v: int, a: int = 0, b: int = 255) -> int:
	return max(a, min(b, v))


def shade(rgb, n: int):
	return (clamp(rgb[0] + n), clamp(rgb[1] + n), clamp(rgb[2] + n // 2), 255)


def add_outline(src: Image.Image, color=OUTLINE) -> Image.Image:
	a = src.split()[-1]
	w, h = src.size
	alpha = a.load()
	outline = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	op = outline.load()
	for y in range(h):
		for x in range(w):
			if alpha[x, y] < 128:
				continue
			for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
				nx, ny = x + dx, y + dy
				if 0 <= nx < w and 0 <= ny < h and alpha[nx, ny] < 128:
					op[nx, ny] = color
	out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	out.alpha_composite(outline)
	out.alpha_composite(src)
	return out


def canvas(n: int = 64) -> tuple[Image.Image, ImageDraw.ImageDraw]:
	img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
	return img, ImageDraw.Draw(img)


def save(img: Image.Image, name: str) -> None:
	UI.mkdir(parents=True, exist_ok=True)
	path = UI / f"{name}.png"
	img.save(path)
	print("wrote", path.relative_to(ROOT))


# ── Logo marque ──────────────────────────────────────────────


def make_logo() -> Image.Image:
	"""Serre + pousse dorée — badge circulaire distinctif."""
	img, d = canvas(64)
	# Fond badge
	d.ellipse([2, 2, 61, 61], fill=(28, 72, 48, 255))
	d.ellipse([5, 5, 58, 58], fill=(46, 110, 72, 255))
	d.ellipse([8, 8, 55, 32], fill=(70, 145, 95, 90))

	# Serre (structure verre)
	# toit
	d.polygon([(16, 34), (32, 14), (48, 34)], fill=(170, 220, 210, 230), outline=(55, 100, 95, 255))
	# murs
	d.rectangle([18, 34, 46, 50], fill=(145, 200, 190, 210), outline=(55, 100, 95, 255))
	# montants
	d.line([(32, 14), (32, 50)], fill=(70, 115, 105, 255), width=2)
	d.line([(18, 34), (46, 34)], fill=(70, 115, 105, 255), width=1)
	d.line([(25, 34), (25, 50)], fill=(80, 125, 115, 200), width=1)
	d.line([(39, 34), (39, 50)], fill=(80, 125, 115, 200), width=1)
	# reflet
	d.line([(20, 28), (28, 22)], fill=(255, 255, 255, 160), width=2)

	# Pousse au centre (devant le verre)
	d.line([(32, 48), (32, 30)], fill=(40, 120, 50, 255), width=3)
	d.line([(32, 48), (32, 30)], fill=(70, 170, 70, 255), width=1)
	d.ellipse([24, 24, 32, 34], fill=(90, 190, 80, 255))
	d.ellipse([32, 22, 42, 34], fill=(110, 205, 95, 255))
	d.ellipse([26, 26, 30, 30], fill=(160, 230, 130, 255))

	# Base terre
	d.ellipse([20, 48, 44, 56], fill=(110, 75, 45, 255))
	d.ellipse([22, 49, 36, 54], fill=(140, 100, 60, 255))

	# Petit soleil / heat accent
	d.ellipse([46, 10, 56, 20], fill=(255, 220, 90, 230))
	d.ellipse([48, 12, 53, 17], fill=(255, 245, 180, 255))

	return add_outline(img, (12, 28, 18, 255))


# ── Monnaie : graine d'or ────────────────────────────────────


def make_coin() -> Image.Image:
	"""Pièce = graine dorée (pas de $ générique)."""
	img, d = canvas(64)
	# Ombre
	d.ellipse([8, 10, 56, 58], fill=(120, 80, 20, 255))
	# Corps ovale graine
	d.ellipse([10, 8, 54, 56], fill=(210, 155, 40, 255))
	d.ellipse([12, 10, 52, 54], fill=(245, 195, 55, 255))
	# Rainure centrale (grain)
	d.ellipse([28, 14, 36, 50], fill=(185, 130, 30, 255))
	d.ellipse([29, 16, 35, 48], fill=(255, 220, 90, 255))
	# Highlight
	d.ellipse([16, 14, 28, 26], fill=(255, 245, 180, 200))
	# Petit germe émergent en haut
	d.line([(32, 16), (32, 6)], fill=(55, 140, 55, 255), width=2)
	d.ellipse([26, 4, 32, 12], fill=(90, 185, 75, 255))
	d.ellipse([32, 3, 40, 12], fill=(110, 200, 90, 255))
	# Contour intérieur
	d.arc([14, 12, 50, 52], 20, 200, fill=(160, 110, 25, 255), width=2)
	return add_outline(img, (70, 45, 10, 240))


# ── Icônes shop ──────────────────────────────────────────────


def make_shop_speed() -> Image.Image:
	"""Graine + flèche bleue vers le haut."""
	img, d = canvas(64)
	d.rounded_rectangle([2, 2, 61, 61], radius=12, fill=(34, 72, 48, 255), outline=(18, 42, 28, 255), width=2)
	# graine
	d.ellipse([10, 28, 34, 54], fill=(92, 140, 55, 255))
	d.ellipse([12, 30, 28, 48], fill=(120, 175, 70, 255))
	d.ellipse([14, 32, 22, 40], fill=(200, 230, 140, 200))
	d.polygon([(22, 26), (28, 34), (16, 34)], fill=(75, 115, 45, 255))
	# flèche bleue
	blue = (70, 150, 230, 255)
	blue_h = (160, 210, 255, 255)
	d.rectangle([40, 28, 48, 52], fill=blue)
	d.rectangle([42, 28, 46, 50], fill=blue_h)
	d.polygon([(44, 8), (58, 28), (30, 28)], fill=blue)
	d.polygon([(44, 12), (52, 26), (36, 26)], fill=blue_h)
	return add_outline(img)


def make_shop_plot() -> Image.Image:
	"""Parcelle iso + +."""
	img, d = canvas(64)
	d.rounded_rectangle([4, 4, 59, 59], radius=12, fill=(55, 42, 30, 255), outline=(30, 22, 14, 255), width=2)
	# losange terre
	d.polygon([(32, 16), (52, 28), (32, 40), (12, 28)], fill=(118, 80, 48, 255), outline=(60, 38, 22, 255))
	d.polygon([(12, 28), (32, 40), (32, 52), (12, 40)], fill=(78, 52, 30, 255), outline=(50, 32, 18, 255))
	d.polygon([(52, 28), (32, 40), (32, 52), (52, 40)], fill=(95, 65, 38, 255), outline=(50, 32, 18, 255))
	# sillons
	d.line([(22, 24), (42, 34)], fill=(90, 58, 32, 255), width=1)
	d.line([(26, 22), (46, 32)], fill=(90, 58, 32, 255), width=1)
	# +
	d.rectangle([46, 8, 54, 22], fill=(90, 200, 100, 255))
	d.rectangle([42, 12, 58, 18], fill=(90, 200, 100, 255))
	return add_outline(img)


def make_shop_frenzy() -> Image.Image:
	"""Double drop — deux pousses jumelles (clonage)."""
	img, d = canvas(64)
	d.rounded_rectangle([4, 4, 59, 59], radius=12, fill=(40, 58, 36, 255), outline=(24, 36, 22, 255), width=2)

	def sprout(cx: int, base_y: int = 48) -> None:
		# tige
		d.line([(cx, base_y), (cx, base_y - 18)], fill=(48, 120, 55, 255), width=3)
		d.line([(cx, base_y), (cx, base_y - 18)], fill=(70, 170, 75, 255), width=1)
		# feuille gauche
		d.ellipse([cx - 14, base_y - 28, cx - 1, base_y - 12], fill=(70, 175, 80, 255), outline=(35, 100, 45, 255), width=1)
		d.ellipse([cx - 11, base_y - 25, cx - 3, base_y - 16], fill=(130, 220, 120, 200))
		# feuille droite
		d.ellipse([cx + 1, base_y - 28, cx + 14, base_y - 12], fill=(55, 155, 70, 255), outline=(35, 100, 45, 255), width=1)
		d.ellipse([cx + 3, base_y - 25, cx + 11, base_y - 16], fill=(120, 210, 115, 180))
		# bourgeon sommet
		d.ellipse([cx - 4, base_y - 34, cx + 4, base_y - 24], fill=(95, 200, 95, 255), outline=(40, 110, 50, 255), width=1)

	# deux pousses côte à côte = double / clone
	sprout(22)
	sprout(42)
	# petit "x2" discret en bas
	d.rounded_rectangle([40, 44, 56, 56], radius=4, fill=(255, 220, 90, 255), outline=(160, 120, 30, 255), width=1)
	d.line([(43, 47), (43, 53)], fill=(90, 60, 15, 255), width=2)
	d.line([(46, 47), (53, 47)], fill=(90, 60, 15, 255), width=2)
	d.line([(46, 50), (51, 50)], fill=(90, 60, 15, 255), width=2)
	d.line([(46, 53), (53, 53)], fill=(90, 60, 15, 255), width=2)
	return add_outline(img)


def make_shop_money() -> Image.Image:
	"""Missions +$ — sac de graines + pièce."""
	img, d = canvas(64)
	d.rounded_rectangle([4, 4, 59, 59], radius=12, fill=(48, 58, 40, 255), outline=(28, 36, 24, 255), width=2)
	d.polygon([(14, 28), (40, 28), (44, 52), (10, 52)], fill=(160, 115, 55, 255), outline=(95, 65, 30, 255), width=2)
	d.rectangle([20, 18, 34, 30], fill=(135, 95, 45, 255), outline=(90, 60, 28, 255))
	d.ellipse([36, 12, 56, 32], fill=(245, 195, 55, 255), outline=(160, 110, 25, 255), width=2)
	d.ellipse([40, 16, 48, 24], fill=(255, 240, 160, 200))
	return add_outline(img)


def make_upgrade() -> Image.Image:
	img, d = canvas(64)
	d.rounded_rectangle([4, 4, 59, 59], radius=12, fill=(30, 70, 50, 255), outline=(18, 45, 32, 255), width=2)
	d.polygon([(32, 8), (50, 28), (40, 28), (40, 52), (24, 52), (24, 28), (14, 28)], fill=(70, 195, 120, 255), outline=(30, 110, 65, 255), width=2)
	d.polygon([(32, 16), (42, 28), (36, 28), (36, 44), (28, 44), (28, 28), (22, 28)], fill=(150, 235, 180, 255))
	return add_outline(img)


def make_prestige() -> Image.Image:
	img, d = canvas(64)
	d.rounded_rectangle([4, 4, 59, 59], radius=12, fill=(45, 35, 70, 255), outline=(28, 20, 48, 255), width=2)
	pts = []
	for i in range(10):
		ang = math.radians(-90 + i * 36)
		r = 20 if i % 2 == 0 else 9
		pts.append((32 + r * math.cos(ang), 32 + r * math.sin(ang)))
	d.polygon(pts, fill=(255, 215, 80, 255), outline=(160, 110, 30, 255), width=2)
	d.ellipse([24, 24, 40, 40], fill=(255, 245, 190, 255))
	# mini pousse
	d.line([(32, 38), (32, 28)], fill=(55, 140, 60, 255), width=2)
	return add_outline(img, (40, 25, 10, 230))


def make_heat() -> Image.Image:
	img, d = canvas(64)
	d.rounded_rectangle([4, 4, 59, 59], radius=12, fill=(70, 35, 20, 255), outline=(45, 20, 10, 255), width=2)
	d.polygon([(32, 6), (46, 28), (36, 28), (44, 56), (16, 26), (28, 26)], fill=(255, 125, 35, 255), outline=(180, 60, 15, 255), width=2)
	d.polygon([(32, 16), (40, 30), (34, 30), (38, 46), (24, 28), (32, 28)], fill=(255, 220, 90, 255))
	return add_outline(img, (90, 35, 10, 230))


def make_mission() -> Image.Image:
	img, d = canvas(64)
	d.rounded_rectangle([4, 4, 59, 59], radius=12, fill=(55, 48, 32, 255), outline=(35, 30, 18, 255), width=2)
	d.rounded_rectangle([14, 8, 50, 54], radius=3, fill=(250, 240, 210, 255), outline=(110, 90, 50, 255), width=2)
	d.rectangle([20, 18, 44, 22], fill=(70, 150, 70, 255))
	d.rectangle([20, 28, 44, 32], fill=(160, 140, 95, 255))
	d.rectangle([20, 38, 36, 42], fill=(160, 140, 95, 255))
	d.polygon([(40, 4), (52, 4), (52, 18), (46, 14), (40, 18)], fill=(210, 55, 50, 255), outline=(130, 30, 25, 255))
	return add_outline(img)


def make_seed_bag() -> Image.Image:
	img, d = canvas(64)
	d.rounded_rectangle([4, 4, 59, 59], radius=12, fill=(50, 42, 30, 255), outline=(30, 24, 16, 255), width=2)
	d.polygon([(14, 24), (50, 24), (54, 54), (10, 54)], fill=(170, 120, 58, 255), outline=(95, 65, 32, 255), width=2)
	d.rectangle([22, 12, 42, 26], fill=(140, 95, 45, 255), outline=(90, 60, 28, 255))
	d.line([(22, 18), (42, 18)], fill=(90, 60, 28, 255), width=2)
	for cx, cy, col in [(22, 34, (245, 200, 70)), (34, 36, (85, 170, 55)), (28, 44, (250, 220, 95)), (40, 44, (70, 150, 50))]:
		d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=(*col, 255), outline=(40, 28, 12, 255))
	return add_outline(img)


def make_scythe() -> Image.Image:
	img, d = canvas(64)
	d.rounded_rectangle([4, 4, 59, 59], radius=12, fill=(42, 48, 40, 255), outline=(24, 28, 22, 255), width=2)
	d.line([(12, 52), (36, 14)], fill=(100, 65, 35, 255), width=6)
	d.line([(12, 52), (36, 14)], fill=(160, 110, 60, 255), width=2)
	d.arc([20, 4, 58, 40], 195, 55, fill=(200, 210, 225, 255), width=6)
	d.arc([24, 8, 54, 36], 200, 45, fill=(245, 250, 255, 255), width=2)
	return add_outline(img)


def make_waterer() -> Image.Image:
	img, d = canvas(64)
	d.rounded_rectangle([4, 4, 59, 59], radius=12, fill=(30, 55, 75, 255), outline=(18, 35, 50, 255), width=2)
	d.ellipse([12, 22, 42, 52], fill=(60, 155, 220, 255), outline=(30, 90, 145, 255), width=2)
	d.ellipse([16, 26, 28, 36], fill=(160, 220, 255, 180))
	d.polygon([(34, 18), (54, 10), (52, 22), (38, 26)], fill=(85, 95, 105, 255), outline=(45, 50, 55, 255))
	for i, yy in enumerate((8, 16, 24)):
		d.ellipse([48, yy, 56, yy + 8], fill=(110, 200, 255, 210 - i * 50))
	return add_outline(img)


def make_harvester() -> Image.Image:
	img, d = canvas(64)
	d.rounded_rectangle([4, 4, 59, 59], radius=12, fill=(40, 55, 35, 255), outline=(22, 32, 18, 255), width=2)
	d.rounded_rectangle([10, 26, 42, 46], radius=4, fill=(80, 145, 70, 255), outline=(40, 85, 40, 255), width=2)
	d.ellipse([34, 16, 56, 38], fill=(70, 75, 82, 255), outline=(40, 45, 50, 255), width=2)
	d.ellipse([40, 22, 50, 32], fill=(120, 125, 132, 255))
	d.rectangle([14, 14, 26, 26], fill=(220, 190, 60, 255), outline=(130, 100, 30, 255))
	d.ellipse([16, 16, 22, 22], fill=(255, 230, 120, 255))
	return add_outline(img)


def make_planter() -> Image.Image:
	img, d = canvas(64)
	d.rounded_rectangle([4, 4, 59, 59], radius=12, fill=(48, 40, 28, 255), outline=(28, 22, 14, 255), width=2)
	d.polygon([(10, 48), (32, 20), (54, 48)], fill=(135, 95, 50, 255), outline=(85, 55, 28, 255), width=2)
	d.ellipse([22, 8, 42, 28], fill=(70, 175, 65, 255), outline=(35, 100, 35, 255), width=2)
	d.ellipse([26, 12, 36, 22], fill=(140, 220, 100, 255))
	d.line([(32, 28), (32, 40)], fill=(50, 120, 45, 255), width=2)
	return add_outline(img)


def make_sparkle() -> Image.Image:
	img, d = canvas(48)
	d.polygon([(24, 2), (28, 18), (44, 24), (28, 30), (24, 46), (20, 30), (4, 24), (20, 18)], fill=(255, 240, 120, 255), outline=(180, 140, 40, 255))
	d.ellipse([18, 18, 30, 30], fill=(255, 255, 220, 255))
	return add_outline(img, (100, 70, 20, 200))


def write_project_icon_svg() -> None:
	"""Icône Godot : serre + pousse (même identité que le logo UI)."""
	svg = """<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#3d8b5f"/>
      <stop offset="100%" stop-color="#1e4d34"/>
    </linearGradient>
    <linearGradient id="glass" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#d8f5ef"/>
      <stop offset="100%" stop-color="#7eb8ae"/>
    </linearGradient>
  </defs>
  <rect width="128" height="128" rx="28" fill="url(#bg)"/>
  <circle cx="64" cy="64" r="52" fill="#2d6a4f"/>
  <circle cx="64" cy="64" r="46" fill="#40916c"/>
  <!-- serre -->
  <polygon points="32,72 64,28 96,72" fill="url(#glass)" stroke="#2d5a52" stroke-width="3"/>
  <rect x="36" y="72" width="56" height="28" fill="#8fc4b8" stroke="#2d5a52" stroke-width="3"/>
  <line x1="64" y1="28" x2="64" y2="100" stroke="#3d6e66" stroke-width="3"/>
  <line x1="50" y1="72" x2="50" y2="100" stroke="#4a7a72" stroke-width="2"/>
  <line x1="78" y1="72" x2="78" y2="100" stroke="#4a7a72" stroke-width="2"/>
  <line x1="40" y1="55" x2="52" y2="45" stroke="#ffffff" stroke-width="3" stroke-opacity="0.55"/>
  <!-- pousse -->
  <line x1="64" y1="96" x2="64" y2="58" stroke="#2d6a4f" stroke-width="5" stroke-linecap="round"/>
  <ellipse cx="54" cy="56" rx="10" ry="12" fill="#74c69d"/>
  <ellipse cx="74" cy="52" rx="12" ry="14" fill="#95d5b2"/>
  <!-- terre -->
  <ellipse cx="64" cy="100" rx="26" ry="8" fill="#7f5539"/>
  <!-- soleil -->
  <circle cx="98" cy="30" r="12" fill="#ffd166"/>
  <circle cx="98" cy="30" r="7" fill="#fff3b0"/>
</svg>
"""
	path = ROOT / "icon.svg"
	path.write_text(svg, encoding="utf-8")
	print("wrote icon.svg")


def main() -> None:
	save(make_logo(), "logo")
	save(make_coin(), "coin")
	save(make_shop_speed(), "shop_speed")
	save(make_shop_plot(), "shop_plot")
	save(make_shop_frenzy(), "shop_frenzy")
	save(make_shop_money(), "shop_money")
	save(make_upgrade(), "upgrade")
	save(make_prestige(), "prestige")
	save(make_heat(), "heat")
	save(make_mission(), "mission")
	save(make_seed_bag(), "seed_bag")
	save(make_scythe(), "scythe")
	save(make_waterer(), "waterer")
	save(make_harvester(), "harvester")
	save(make_planter(), "planter")
	save(make_sparkle(), "sparkle")
	write_project_icon_svg()
	print("Done.")


if __name__ == "__main__":
	main()
