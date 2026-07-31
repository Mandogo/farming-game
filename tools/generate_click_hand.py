"""Main clic d'un seul tenant — polygone continu, hotspot (40, 28)."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[1] / "assets" / "textures" / "ui" / "click_hand.png"
SIZE = 128
HOTSPOT = (40, 28)

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

# Glow derrière le hotspot
glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
cx, cy = HOTSPOT
gd.ellipse([cx - 26, cy - 26, cx + 26, cy + 26], fill=(255, 215, 70, 75))
glow = glow.filter(ImageFilter.GaussianBlur(5))
img = Image.alpha_composite(img, glow)
d = ImageDraw.Draw(img)

# Anneaux
for r, a in [(22, 110), (16, 160), (10, 210)]:
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 230, 100, a), width=3)
d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=(255, 250, 210, 230))
d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=(255, 255, 255, 255))

skin = (255, 210, 165, 255)
outline = (110, 70, 40, 255)
nail = (255, 235, 215, 255)

# Silhouette main CONTINUÉE (index → paume → doigts → pouce)
# Coords : pointe index juste sous le hotspot
hand = [
    # pointe index (sous cercle)
    (34, 30), (46, 30),
    # côté droit index descendant vers paume
    (48, 48), (52, 62),
    # majeurs repliés (côté droit)
    (64, 58), (78, 62), (92, 70), (102, 78), (104, 92),
    # bas paume
    (96, 112), (70, 118), (48, 112),
    # pouce
    (38, 100), (32, 88), (36, 76),
    # côté gauche index remontant
    (34, 70), (32, 52), (34, 30),
]
d.polygon(hand, fill=skin, outline=outline)
# Contour plus épais
d.line(hand + [hand[0]], fill=outline, width=3)

# Détails doigts (traits internes, sans casser la forme)
d.arc([58, 58, 78, 88], 200, 340, fill=outline, width=2)
d.arc([74, 64, 94, 92], 200, 340, fill=outline, width=2)
d.line([(40, 78), (52, 92)], fill=outline, width=2)  # pouce pli

# Ongle
d.ellipse([35, 30, 45, 40], fill=nail, outline=outline, width=2)

# Sparkles
for sx, sy in [(cx + 14, cy - 10), (cx - 14, cy + 8)]:
    d.ellipse([sx - 2, sy - 2, sx + 2, sy + 2], fill=(255, 255, 235, 230))

OUT.parent.mkdir(parents=True, exist_ok=True)
img.save(OUT)
print("wrote", OUT, "hotspot", HOTSPOT)
