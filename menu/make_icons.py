#!/usr/bin/env python3
"""Genera el set de PNG del menú Zenith (128x128, fondo transparente).

    python3 menu/make_icons.py [origen_logo] [carpeta_salida]

Ejemplo:
    python3 menu/make_icons.py /tmp/arena-coding-uploads/download.png menu/assets

Salida:
    division-logo.png         el logo original con el blanco convertido en alfa
    division-logo-vector.png  recreación del logo (por si no hay original)
    house.png                 casa sobre cuadro ámbar
    people.png                icono de personas
    paper.png                 papel con esquina doblada

Los PNG son de 128x128. Para usarlos en el menú hay que subirlos a Roblox
(Creator Dashboard -> Development Items -> Images) y pegar la id en
CONFIG.ICONS dentro de menu/ZenithMenu.lua.
"""

import os
import sys

from PIL import Image, ImageDraw

SIZE = 128

# Paleta real del logo adjunto (medida sobre download.png).
LILAC_LIGHT = (216, 193, 216)
LILAC_MID = (182, 118, 182)
LILAC_DEEP = (162, 75, 162)
ACCENT = (246, 165, 32)
INK = (255, 255, 255)
PANEL = (7, 8, 11)


def strip_white(src, dst, hard=235, soft=250):
    """Convierte el fondo blanco en transparencia conservando los tonos claros.

    Solo los píxeles casi blancos se vuelven transparentes; el lila claro del
    logo (min ~193) queda opaco, así no se "come" el dibujo.
    """
    img = Image.open(src).convert("RGBA")
    pixels = img.load()
    width, height = img.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            darkest = min(r, g, b)
            if darkest >= soft:
                alpha = 0
            elif darkest <= hard:
                alpha = 255
            else:
                alpha = int(255 * (soft - darkest) / (soft - hard))
            pixels[x, y] = (r, g, b, min(a, alpha))
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    os.makedirs(os.path.dirname(dst) or ".", exist_ok=True)
    img.save(dst)
    print("logo   ->", dst)


def make_house(path):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((8, 8, 120, 120), radius=12, fill=ACCENT + (255,))
    d.polygon([(64, 32), (102, 68), (26, 68)], fill=INK + (255,))
    d.rounded_rectangle((42, 64, 86, 98), radius=3, fill=INK + (255,))
    d.rectangle((58, 78, 70, 98), fill=ACCENT + (255,))
    img.save(path)
    print("casa   ->", path)


def make_people(path):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for cx, scale, alpha in ((88, 0.8, 90), (50, 1.0, 255)):
        head = int(14 * scale)
        d.ellipse((cx - head, 28 - head, cx + head, 28 + head), fill=INK + (alpha,))
        top = 46 - int(4 * scale)
        d.rounded_rectangle(
            (cx - int(26 * scale), top, cx + int(26 * scale), top + int(38 * scale)),
            radius=int(16 * scale),
            fill=INK + (alpha,),
        )
    img.save(path)
    print("gente  ->", path)


def make_paper(path):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((28, 10, 100, 118), radius=6, outline=INK + (255,), width=6)
    d.polygon([(76, 10), (100, 34), (76, 34)], fill=(0, 0, 0, 0))  # esquina doblada
    d.line([(76, 10), (100, 34)], fill=INK + (255,), width=5)       # pliegue
    for i in range(3):
        y = 52 + i * 18
        d.rounded_rectangle((44, y, 84, y + 5), radius=2, fill=INK + (255,))
    img.save(path)
    print("papel  ->", path)


def make_logo(path):
    """Recreación vectorial del logo: anillo con hueco arriba, punto y tres chevrons."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    box = (10, 16, 118, 124)
    # anillo con un hueco arriba (como el original), donde se apoya el punto
    d.arc(box, start=312, end=360, fill=LILAC_LIGHT + (255,), width=7)
    d.arc(box, start=0, end=228, fill=LILAC_LIGHT + (255,), width=7)
    d.ellipse((55, 8, 73, 26), fill=LILAC_LIGHT + (255,))  # punto
    for apex_y, half, color in ((70, 34, LILAC_LIGHT), (89, 25, LILAC_MID), (108, 16, LILAC_DEEP)):
        d.line([(64 - half, apex_y), (64, apex_y - half)], fill=color + (255,), width=8)
        d.line([(64, apex_y - half), (64 + half, apex_y)], fill=color + (255,), width=8)
        d.ellipse((64 - 4, apex_y - half - 4, 64 + 4, apex_y - half + 4), fill=color + (255,))
    img.save(path)
    print("logo-v ->", path)


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "download.png"
    out = sys.argv[2] if len(sys.argv) > 2 else "menu/assets"
    os.makedirs(out, exist_ok=True)

    if os.path.exists(src):
        strip_white(src, os.path.join(out, "division-logo.png"))
    else:
        print("aviso: no existe", src, "- se omite division-logo.png")

    make_logo(os.path.join(out, "division-logo-vector.png"))
    make_house(os.path.join(out, "house.png"))
    make_people(os.path.join(out, "people.png"))
    make_paper(os.path.join(out, "paper.png"))
    print("listo ->", out)


if __name__ == "__main__":
    main()
