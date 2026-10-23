#!/usr/bin/env python3
# 生成 fbconsole 用的 8x16 点阵字库 (font8x16.h)
# 依赖: pillow (pip3 install pillow)
# 用法: python3 tools/linux/src/gen_font.py > tools/linux/src/font8x16.h
import sys
from PIL import Image, ImageDraw, ImageFont

W, H = 8, 16


def render(code: int) -> list[int]:
    ch = chr(code)
    img = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(img)
    font = ImageFont.load_default(size=14)
    bbox = d.textbbox((0, 0), ch, font=font)
    w = bbox[2] - bbox[0]
    h = bbox[3] - bbox[1]
    d.text(((W - w) // 2 - bbox[0], (H - h) // 2 - bbox[1]), ch, fill=255, font=font)
    rows = []
    for y in range(H):
        b = 0
        for x in range(W):
            if img.getpixel((x, y)) >= 96:
                b |= 1 << (7 - x)
        rows.append(b)
    return rows


def main() -> None:
    out = sys.stdout
    out.write("/* 自动生成: tools/linux/src/gen_font.py (8x16, ASCII 32..126) */\n")
    out.write("#ifndef FONT8X16_H\n#define FONT8X16_H\n\n")
    out.write("static const unsigned char font8x16[95][16] = {\n")
    for code in range(32, 127):
        ch = chr(code)
        esc = "\\\\" if ch == "\\" else ch
        rows = ",".join("0x%02x" % b for b in render(code))
        out.write("    {%s}, /* '%s' */\n" % (rows, esc))
    out.write("};\n\n#endif\n")


if __name__ == "__main__":
    main()
