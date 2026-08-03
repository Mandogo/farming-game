"""Régénère les icônes UI en flat cartoon (contours épais, aplats) — style Crop Express Idle."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

DST = Path(r"c:\Users\quent\Documents\Projets\15. New project\greenhouse-idle\assets\textures\ui")
SIZE = 128
INK = (35, 32, 28, 255)
OUTLINE = 4


def blank() -> Image.Image:
	return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def save(im: Image.Image, name: str) -> None:
	DST.mkdir(parents=True, exist_ok=True)
	path = DST / f"{name}.png"
	im.save(path, optimize=True)
	print("ok", path.name)


def circle(draw: ImageDraw.ImageDraw, cx, cy, r, fill, outline=INK, width=OUTLINE):
	bbox = [cx - r, cy - r, cx + r, cy + r]
	draw.ellipse(bbox, fill=fill, outline=outline, width=width)


def rounded_rect(draw, xy, radius, fill, outline=INK, width=OUTLINE):
	draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def coin(color_a, color_b, glyph: str) -> Image.Image:
	im = blank()
	d = ImageDraw.Draw(im)
	circle(d, 64, 64, 48, color_a)
	circle(d, 64, 64, 36, color_b, width=3)
	# simple glyph mark
	if glyph == "$":
		d.line([(64, 38), (64, 90)], fill=INK, width=7)
		d.arc([48, 44, 80, 64], 200, 20, fill=INK, width=6)
		d.arc([48, 64, 80, 84], 20, 200, fill=INK, width=6)
	elif glyph == "P":
		# star
		pts = []
		for i in range(5):
			a = -math.pi / 2 + i * 2 * math.pi / 5
			pts.append((64 + math.cos(a) * 22, 64 + math.sin(a) * 22))
			a2 = a + math.pi / 5
			pts.append((64 + math.cos(a2) * 10, 64 + math.sin(a2) * 10))
		d.polygon(pts, fill=(255, 236, 160, 255), outline=INK)
	elif glyph == "S":
		# leaf for skill
		d.ellipse([50, 40, 86, 88], fill=(110, 180, 100, 255), outline=INK, width=4)
		d.line([(64, 48), (64, 82)], fill=INK, width=3)
	return im


def icon_logo() -> Image.Image:
	im = blank()
	d = ImageDraw.Draw(im)
	# greenhouse dome
	rounded_rect(d, [22, 48, 106, 108], 10, (232, 244, 236, 255))
	d.chord([22, 18, 106, 78], 180, 0, fill=(210, 235, 245, 255), outline=INK, width=OUTLINE)
	d.line([(64, 18), (64, 108)], fill=INK, width=3)
	d.line([(22, 64), (106, 64)], fill=INK, width=3)
	# plant
	d.ellipse([54, 70, 74, 92], fill=(90, 170, 80, 255), outline=INK, width=3)
	return im


def icon_mission() -> Image.Image:
	im = blank()
	d = ImageDraw.Draw(im)
	rounded_rect(d, [28, 18, 100, 110], 8, (250, 246, 232, 255))
	d.rectangle([40, 36, 88, 44], fill=(120, 160, 100, 255), outline=INK, width=2)
	d.rectangle([40, 54, 88, 62], fill=(180, 190, 170, 255), outline=INK, width=2)
	d.rectangle([40, 72, 72, 80], fill=(180, 190, 170, 255), outline=INK, width=2)
	# clip
	d.ellipse([52, 10, 76, 28], fill=(220, 180, 70, 255), outline=INK, width=3)
	return im


def icon_prestige() -> Image.Image:
	im = blank()
	d = ImageDraw.Draw(im)
	circle(d, 64, 64, 46, (255, 214, 90, 255))
	pts = []
	for i in range(5):
		a = -math.pi / 2 + i * 2 * math.pi / 5
		pts.append((64 + math.cos(a) * 28, 64 + math.sin(a) * 28))
		a2 = a + math.pi / 5
		pts.append((64 + math.cos(a2) * 12, 64 + math.sin(a2) * 12))
	d.polygon(pts, fill=(255, 245, 200, 255), outline=INK)
	return im


def icon_lock() -> Image.Image:
	im = blank()
	d = ImageDraw.Draw(im)
	d.arc([38, 24, 90, 76], 180, 0, fill=INK, width=10)
	rounded_rect(d, [34, 58, 94, 108], 10, (220, 180, 70, 255))
	circle(d, 64, 78, 8, (60, 50, 35, 255), width=0)
	d.rectangle([60, 78, 68, 96], fill=(60, 50, 35, 255))
	return im


def icon_check() -> Image.Image:
	im = blank()
	d = ImageDraw.Draw(im)
	circle(d, 64, 64, 46, (110, 190, 100, 255))
	d.line([(42, 66), (58, 84), (90, 46)], fill=(255, 255, 255, 255), width=10)
	d.line([(42, 66), (58, 84), (90, 46)], fill=INK, width=4)
	return im


def icon_cancel() -> Image.Image:
	im = blank()
	d = ImageDraw.Draw(im)
	circle(d, 64, 64, 46, (220, 100, 90, 255))
	d.line([(44, 44), (84, 84)], fill=(255, 255, 255, 255), width=10)
	d.line([(84, 44), (44, 84)], fill=(255, 255, 255, 255), width=10)
	d.line([(44, 44), (84, 84)], fill=INK, width=4)
	d.line([(84, 44), (44, 84)], fill=INK, width=4)
	return im


def icon_xp() -> Image.Image:
	im = blank()
	d = ImageDraw.Draw(im)
	rounded_rect(d, [30, 30, 98, 98], 16, (120, 190, 255, 255))
	d.polygon([(64, 38), (82, 64), (64, 90), (46, 64)], fill=(230, 245, 255, 255), outline=INK)
	return im


def icon_chrono() -> Image.Image:
	im = blank()
	d = ImageDraw.Draw(im)
	circle(d, 64, 70, 40, (250, 245, 230, 255))
	d.rectangle([54, 22, 74, 34], fill=(180, 140, 70, 255), outline=INK, width=3)
	d.line([(64, 70), (64, 48)], fill=INK, width=5)
	d.line([(64, 70), (84, 70)], fill=INK, width=4)
	return im


def icon_truck() -> Image.Image:
	im = blank()
	d = ImageDraw.Draw(im)
	rounded_rect(d, [18, 48, 78, 88], 8, (110, 170, 100, 255))
	rounded_rect(d, [78, 58, 110, 88], 8, (230, 210, 90, 255))
	circle(d, 40, 96, 12, (60, 60, 60, 255))
	circle(d, 92, 96, 12, (60, 60, 60, 255))
	d.rectangle([86, 64, 102, 76], fill=(180, 220, 235, 255), outline=INK, width=2)
	return im


def icon_combo() -> Image.Image:
	im = blank()
	d = ImageDraw.Draw(im)
	# flame / boost
	d.ellipse([36, 40, 92, 104], fill=(255, 150, 70, 255), outline=INK, width=OUTLINE)
	d.ellipse([48, 52, 80, 92], fill=(255, 220, 120, 255), outline=INK, width=3)
	d.polygon([(64, 28), (74, 52), (54, 52)], fill=(255, 120, 60, 255), outline=INK)
	return im


def icon_target() -> Image.Image:
	im = blank()
	d = ImageDraw.Draw(im)
	circle(d, 64, 64, 46, (250, 245, 230, 255))
	circle(d, 64, 64, 30, (240, 120, 100, 255), width=3)
	circle(d, 64, 64, 14, (250, 245, 230, 255), width=3)
	circle(d, 64, 64, 6, (220, 80, 70, 255), width=0)
	return im


def icon_sparkle() -> Image.Image:
	im = blank()
	d = ImageDraw.Draw(im)
	d.polygon([(64, 20), (72, 56), (108, 64), (72, 72), (64, 108), (56, 72), (20, 64), (56, 56)], fill=(255, 230, 120, 255), outline=INK)
	return im


def icon_mouse_left() -> Image.Image:
	im = blank()
	d = ImageDraw.Draw(im)
	rounded_rect(d, [40, 18, 88, 110], 20, (235, 235, 230, 255))
	d.line([(64, 18), (64, 58)], fill=INK, width=3)
	d.line([(40, 58), (88, 58)], fill=INK, width=3)
	d.rectangle([42, 20, 62, 56], fill=(140, 200, 120, 255))
	return im


def icon_click_hand() -> Image.Image:
	im = blank()
	d = ImageDraw.Draw(im)
	# simple pointing hand
	rounded_rect(d, [48, 20, 78, 70], 12, (255, 220, 180, 255))
	rounded_rect(d, [36, 60, 96, 108], 16, (255, 220, 180, 255))
	d.ellipse([52, 8, 74, 28], fill=(255, 220, 180, 255), outline=INK, width=3)
	return im


def icon_tab(color, mark: str) -> Image.Image:
	im = blank()
	d = ImageDraw.Draw(im)
	rounded_rect(d, [16, 28, 112, 100], 14, color)
	if mark == "shop":
		# cart
		d.rectangle([40, 48, 88, 72], fill=(250, 245, 230, 255), outline=INK, width=3)
		circle(d, 50, 84, 7, (50, 50, 50, 255), width=0)
		circle(d, 78, 84, 7, (50, 50, 50, 255), width=0)
	else:
		# star
		pts = []
		for i in range(5):
			a = -math.pi / 2 + i * 2 * math.pi / 5
			pts.append((64 + math.cos(a) * 20, 64 + math.sin(a) * 18))
			a2 = a + math.pi / 5
			pts.append((64 + math.cos(a2) * 8, 64 + math.sin(a2) * 8))
		d.polygon(pts, fill=(255, 236, 160, 255), outline=INK)
	return im


def icon_skill_tree() -> Image.Image:
	im = blank()
	d = ImageDraw.Draw(im)
	circle(d, 64, 36, 14, (120, 190, 100, 255))
	circle(d, 40, 84, 14, (230, 180, 80, 255))
	circle(d, 88, 84, 14, (100, 170, 220, 255))
	d.line([(64, 50), (40, 70)], fill=INK, width=4)
	d.line([(64, 50), (88, 70)], fill=INK, width=4)
	return im


def icon_shop(kind: str) -> Image.Image:
	im = blank()
	d = ImageDraw.Draw(im)
	bg = {
		"speed": (120, 190, 230, 255),
		"plot": (180, 140, 90, 255),
		"frenzy": (240, 130, 90, 255),
		"money": (240, 200, 70, 255),
		"click": (150, 200, 110, 255),
	}[kind]
	rounded_rect(d, [18, 18, 110, 110], 18, bg)
	if kind == "speed":
		d.polygon([(48, 40), (88, 64), (48, 88)], fill=(255, 255, 255, 255), outline=INK)
	elif kind == "plot":
		d.polygon([(64, 36), (96, 56), (64, 76), (32, 56)], fill=(140, 100, 60, 255), outline=INK)
	elif kind == "frenzy":
		d.polygon([(64, 34), (78, 64), (64, 94), (50, 64)], fill=(255, 230, 140, 255), outline=INK)
	elif kind == "money":
		circle(d, 64, 64, 28, (255, 230, 120, 255))
		d.line([(64, 48), (64, 80)], fill=INK, width=5)
	else:  # click
		rounded_rect(d, [50, 34, 78, 70], 10, (255, 220, 180, 255))
		rounded_rect(d, [40, 66, 90, 98], 14, (255, 220, 180, 255))
	return im


def main() -> None:
	save(coin((255, 210, 70, 255), (255, 230, 140, 255), "$"), "coin")
	save(coin((255, 200, 50, 255), (255, 235, 150, 255), "$"), "coin_gold")
	save(coin((180, 140, 255, 255), (220, 200, 255, 255), "P"), "coin_prestige")
	save(coin((110, 190, 120, 255), (170, 220, 160, 255), "S"), "coin_skill")
	save(icon_logo(), "logo")
	save(icon_mission(), "mission")
	save(icon_prestige(), "prestige")
	save(icon_lock(), "lock")
	save(icon_check(), "btn_check")
	save(icon_cancel(), "btn_cancel")
	save(icon_xp(), "xp")
	save(icon_chrono(), "chrono")
	save(icon_truck(), "truck")
	save(icon_combo(), "combo")
	save(icon_target(), "target")
	save(icon_sparkle(), "sparkle")
	save(icon_mouse_left(), "mouse_left")
	save(icon_click_hand(), "click_hand")
	save(icon_tab((120, 180, 110, 255), "shop"), "tab_shop")
	save(icon_tab((230, 180, 70, 255), "prestige"), "tab_prestige")
	save(icon_skill_tree(), "skill_tree")
	for k in ("speed", "plot", "frenzy", "money", "click"):
		save(icon_shop(k), f"shop_{k}")


if __name__ == "__main__":
	main()
