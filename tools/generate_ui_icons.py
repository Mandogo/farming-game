"""Petites icônes UI : piece, sac de graines, faux."""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "assets" / "textures"


def save(img: Image.Image, name: str) -> None:
    img.resize((img.width * 2, img.height * 2), Image.NEAREST).save(OUT / f"{name}.png")
    print("wrote", name)


def icon_coin() -> Image.Image:
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([2, 2, 21, 21], fill=(220, 175, 40, 255), outline=(160, 110, 20, 255))
    d.ellipse([5, 5, 18, 18], fill=(255, 215, 70, 255))
    d.ellipse([8, 7, 12, 11], fill=(255, 240, 160, 200))
    # $ stylisé
    d.line([(12, 7), (12, 17)], fill=(160, 110, 20, 255), width=1)
    d.arc([9, 8, 15, 13], 200, 20, fill=(160, 110, 20, 255), width=1)
    d.arc([9, 12, 15, 17], 20, 200, fill=(160, 110, 20, 255), width=1)
    return img


def icon_seed_bag() -> Image.Image:
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # sac
    d.polygon([(6, 8), (18, 8), (20, 20), (4, 20)], fill=(160, 110, 55, 255), outline=(100, 70, 35, 255))
    d.rectangle([8, 5, 16, 9], fill=(140, 95, 45, 255))
    # graines qui dépassent
    d.ellipse([9, 10, 13, 14], fill=(230, 190, 60, 255))
    d.ellipse([13, 12, 17, 16], fill=(90, 160, 50, 255))
    d.ellipse([11, 14, 15, 18], fill=(245, 210, 80, 255))
    return img


def icon_scythe() -> Image.Image:
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # manche
    d.line([(6, 20), (14, 8)], fill=(120, 80, 40, 255), width=2)
    # lame
    d.arc([8, 2, 22, 16], 200, 40, fill=(200, 210, 220, 255), width=2)
    d.arc([10, 4, 20, 14], 210, 30, fill=(230, 235, 240, 255), width=1)
    return img


def icon_mouse_left() -> Image.Image:
    img = Image.new("RGBA", (16, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([2, 1, 13, 18], radius=4, fill=(50, 55, 60, 255), outline=(180, 185, 190, 255))
    d.rectangle([2, 1, 7, 9], fill=(90, 200, 110, 255))  # bouton gauche highlight
    d.line([(8, 1), (8, 9)], fill=(180, 185, 190, 255), width=1)
    return img


def icon_mouse_right() -> Image.Image:
    img = Image.new("RGBA", (16, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([2, 1, 13, 18], radius=4, fill=(50, 55, 60, 255), outline=(180, 185, 190, 255))
    d.rectangle([8, 1, 13, 9], fill=(240, 190, 70, 255))  # bouton droit highlight
    d.line([(8, 1), (8, 9)], fill=(180, 185, 190, 255), width=1)
    return img


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    save(icon_coin(), "ui_coin")
    save(icon_seed_bag(), "ui_seed_bag")
    save(icon_scythe(), "ui_scythe")
    save(icon_mouse_left(), "ui_mouse_left")
    save(icon_mouse_right(), "ui_mouse_right")
