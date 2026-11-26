"""Builds the world map's dungeon and raid entrance icons from art/icons/dungeon-portal.png.

  NoobsForeverDungeonMapper/Media/Textures/DungeonPortal.tga       the blue swirl, as a round icon
  NoobsForeverDungeonMapper/Media/Textures/DungeonPortalRaid.tga   the same, turned purple (raids)

The addon prefers the game's own "Dungeon" and "Raid" icons when the client has them (as retail's world
map does) and uses these as the fallback. Run with Pillow installed:  python3 -P tools/make_icons.py
"""
import colorsys
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "art", "icons", "dungeon-portal.png")
OUT = os.path.join(ROOT, "NoobsForeverDungeonMapper", "Media", "Textures")
CENTER, RADIUS, SIZE = (128, 124), 60, 64     # the swirl's circle in the 256 px picture; icon size


def round_icon(img):
    cx, cy = CENTER
    crop = img.crop((cx - RADIUS, cy - RADIUS, cx + RADIUS, cy + RADIUS)).convert("RGBA")
    mask = Image.new("L", crop.size, 0)
    ImageDraw.Draw(mask).ellipse((2, 2, crop.size[0] - 3, crop.size[1] - 3), fill=255)
    crop.putalpha(mask.filter(ImageFilter.GaussianBlur(1.5)))
    return crop.resize((SIZE, SIZE), Image.LANCZOS)


def turn(img, degrees, saturation):
    """the picture with its hues turned and its colour toned down (blue -> muted purple)"""
    px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            r, g, b = colorsys.hsv_to_rgb((h + degrees / 360) % 1, s * saturation, v * 0.92)
            px[x, y] = (int(r * 255), int(g * 255), int(b * 255), a)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    icon = round_icon(Image.open(SRC))
    icon.save(os.path.join(OUT, "DungeonPortal.tga"))
    turn(icon.copy(), 68, 0.7).save(os.path.join(OUT, "DungeonPortalRaid.tga"))
    print("wrote DungeonPortal.tga and DungeonPortalRaid.tga")


main()
