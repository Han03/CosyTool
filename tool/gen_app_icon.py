# -*- coding: utf-8 -*-
"""生成 CosyTool 应用图标：青绿渐变背景 + 白色 handyman_rounded 字形。

与菜单上方图标完全一致（同一个 MaterialIcons 字体 glyph 0xf7cc）。
输出 icons/ 目录：1024 源图、Windows ICO、Android mipmap PNG、iOS AppIcon PNG。
"""
import os
import numpy as np
from PIL import Image, ImageDraw
import freetype

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")
os.makedirs(OUT, exist_ok=True)

FONT = r"C:\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf"
GLYPH = 0xF7CC  # Icons.handyman_rounded

C1 = (14, 159, 143)   # #0E9F8F
C2 = (55, 182, 201)   # #37B6C9
WHITE = (255, 255, 255, 255)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def make_gradient(size, c1, c2):
    """左上 -> 右下线性渐变。"""
    img = Image.new("RGB", (size, size))
    px = img.load()
    denom = 2.0 * (size - 1)
    for y in range(size):
        for x in range(size):
            px[x, y] = lerp(c1, c2, (x + y) / denom)
    return img


def render_glyph(size):
    """渲染 handyman_rounded 字形为 RGBA（内容区透明外扩，白色字形）。"""
    face = freetype.Face(FONT)
    face.set_char_size(size * 64)
    face.load_char(GLYPH)
    bm = face.glyph.bitmap
    w, h = bm.width, bm.rows
    buf = np.frombuffer(bytes(bm.buffer), np.uint8).reshape(h, w)
    # 内容 bbox
    ys, xs = np.nonzero(buf > 8)
    x0, x1 = xs.min(), xs.max()
    y0, y1 = ys.min(), ys.max()
    crop = buf[y0:y1 + 1, x0:x1 + 1]
    alpha = Image.fromarray(crop, "L")
    rgba = Image.new("RGBA", alpha.size, WHITE)
    rgba.putalpha(alpha)
    return rgba


def build_icon(size, rounded=False):
    img = make_gradient(size, C1, C2).convert("RGBA")
    # 字形缩放到图标尺寸的 ~62%（应用图标元素占比），居中
    glyph = render_glyph(max(256, size))
    target = int(size * 0.62)
    glyph = glyph.resize((target, target), Image.LANCZOS)
    ox = (size - target) // 2
    oy = (size - target) // 2
    img.alpha_composite(glyph, (ox, oy))
    if rounded:
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, size - 1, size - 1], radius=size * 0.18, fill=255)
        img.putalpha(mask)
    return img


def main():
    build_icon(1024, rounded=False).save(os.path.join(OUT, "app_icon_1024.png"))
    build_icon(256, rounded=True).save(
        os.path.join(OUT, "app_icon.ico"),
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64),
               (128, 128), (256, 256)])

    mipmap = {"mipmap-mdpi": 48, "mipmap-hdpi": 72, "mipmap-xhdpi": 96,
              "mipmap-xxhdpi": 144, "mipmap-xxxhdpi": 192}
    for name, sz in mipmap.items():
        build_icon(sz, rounded=False).save(os.path.join(OUT, f"ic_launcher_{name}.png"))

    ios_icons = {
        "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60, "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120, "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180, "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152, "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for name, sz in ios_icons.items():
        build_icon(sz, rounded=False).save(os.path.join(OUT, name))

    print("generated:", len(os.listdir(OUT)), "files")


if __name__ == "__main__":
    main()
