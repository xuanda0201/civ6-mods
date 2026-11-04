"""Draw original typographic Workshop covers. Optional authoring tool; requires Pillow."""
import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SIZE, SCALE = 1024, 2


def font_path(explicit, candidates):
    for path in ([explicit] if explicit else []) + candidates:
        if path and Path(path).is_file():
            return path
    raise SystemExit("No suitable font found. Pass --cjk-font and --latin-font.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cjk-font")
    parser.add_argument("--latin-font")
    args = parser.parse_args()
    cjk = font_path(args.cjk_font, [
        "/System/Library/Fonts/Hiragino Sans GB.ttc", "C:/Windows/Fonts/msyh.ttc",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    ])
    latin = font_path(args.latin_font, [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf", "C:/Windows/Fonts/arialbd.ttf", cjk,
    ])
    for metadata in sorted(ROOT.glob("*/workshop/metadata.json")):
        data = json.loads(metadata.read_text(encoding="utf-8"))
        cover, name = data["cover"], data["name"]
        accent = cover["accent"]
        image = Image.new("RGB", (SIZE * SCALE, SIZE * SCALE))
        draw = ImageDraw.Draw(image)

        def xy(values):
            return tuple(round(v * SCALE) for v in values)

        def line(points, fill=accent, width=7):
            draw.line([xy(p) for p in points], fill=fill, width=width * SCALE, joint="curve")

        def box(bounds, fill=None, outline=accent, width=5, radius=0):
            if radius:
                draw.rounded_rectangle(xy(bounds), radius=radius * SCALE, fill=fill, outline=outline, width=width * SCALE)
            else:
                draw.rectangle(xy(bounds), fill=fill, outline=outline, width=width * SCALE)

        def ellipse(bounds, fill=None, outline=accent, width=5):
            draw.ellipse(xy(bounds), fill=fill, outline=outline, width=width * SCALE)

        def text(value, y, size, path=latin, color="#F1EEE7", center=True, x=512):
            font = ImageFont.truetype(path, size * SCALE)
            while draw.textlength(value, font=font) > 880 * SCALE:
                size -= 1
                font = ImageFont.truetype(path, size * SCALE)
            draw.text(xy((x, y)), value, font=font, fill=color, anchor="mt" if center else "lt")

        for y in range(SIZE * SCALE):
            ratio = y / (SIZE * SCALE)
            draw.line([(0, y), (SIZE * SCALE, y)], fill=(int(16 + ratio * 5), int(28 + ratio * 7), int(43 + ratio * 9)))
        for x in range(80, 945, 72):
            line([(x, 164), (x, 650)], "#203447", 1)
        for y in range(164, 651, 72):
            line([(80, y), (944, y)], "#203447", 1)
        box((30, 30, 994, 994), outline="#395165", width=1)
        text("XUANDA / CIV VI MODS", 62, 21, x=64, center=False, color=accent)
        text(cover["kicker"], 134, 23, color=accent)
        hexagon = [(512 + 214 * math.cos(math.pi / 3 * i - math.pi / 6),
                    417 + 214 * math.sin(math.pi / 3 * i - math.pi / 6)) for i in range(6)]
        draw.polygon([xy(p) for p in hexagon], fill="#172A3C")
        line(hexagon + [hexagon[0]], width=2)
        if name == "InfiniteProjects":
            for bounds in [(400, 340, 460, 490), (482, 291, 544, 490), (566, 370, 626, 490)]:
                box(bounds, fill="#233F51", radius=3)
            line([(377, 506), (648, 506)], "#F1EEE7", 5)
            draw.arc(xy((365, 275, 659, 555)), 12, 162, fill=accent, width=9 * SCALE)
            draw.arc(xy((365, 275, 659, 555)), 192, 342, fill=accent, width=9 * SCALE)
            draw.polygon([xy(p) for p in [(367, 434), (389, 449), (365, 464)]], fill=accent)
            draw.polygon([xy(p) for p in [(657, 395), (633, 380), (657, 365)]], fill=accent)
        elif name == "SpyRepeat":
            eye = [(351, 406), (397, 357), (453, 330), (512, 322), (571, 330), (627, 357),
                   (673, 406), (627, 455), (571, 482), (512, 490), (453, 482), (397, 455), (351, 406)]
            line(eye, width=8)
            ellipse((453, 347, 571, 465), fill="#203A50", width=6)
            ellipse((489, 383, 535, 429), fill="#F1EEE7", outline="#F1EEE7")
            line([(417, 536), (512, 566), (607, 536)], width=3)
            for x, y in [(417, 536), (512, 566), (607, 536)]:
                ellipse((x - 9, y - 9, x + 9, y + 9), fill=accent)
        elif name == "BuilderAuto":
            for index, h in enumerate([50, 88, 125]):
                box((395 + index * 79, 493 - h, 448 + index * 79, 493), fill="#24493F", width=3)
            line([(425, 523), (578, 311)], "#F1EEE7", 17)
            line([(482, 302), (572, 309), (647, 373)], accent, 21)
            line([(483, 300), (444, 337)], accent, 13)
            line([(376, 546), (650, 546)], accent, 4)
        elif name == "AutoTheme":
            for index in range(3):
                x = 342 + index * 120
                box((x, 323, x + 101, 491), fill="#253248", width=5, radius=3)
                line([(x + 16, 463), (x + 85, 463)], "#718295", 2)
            ellipse((365, 361, 420, 416), fill=accent)
            box((491, 365, 535, 409), fill=accent)
            draw.polygon([xy(p) for p in [(631, 356), (601, 413), (660, 413)]], fill=accent)
            line([(393, 532), (632, 532)], accent, 4)
            for x in [393, 512, 632]:
                ellipse((x - 7, 525, x + 7, 539), fill=accent)
        elif name == "RailAuto":
            line([(438, 295), (385, 548)], width=12)
            line([(586, 295), (639, 548)], width=12)
            for y in range(320, 541, 44):
                span = 88 + (y - 320) * 0.25
                line([(512 - span, y), (512 + span, y)], "#F1EEE7", 9)
        text(cover["title"], 684, 74, path=cjk)
        text(cover["english"].upper(), 786, 39, color=accent)
        text(cover["strapline"], 854, 29, path=cjk, color="#AEBECA")
        image = image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
        destination = metadata.parent / "preview.png"
        image.save(destination, optimize=True)
        print(destination.relative_to(ROOT), destination.stat().st_size, "bytes")


if __name__ == "__main__":
    main()
