# -*- coding: utf-8 -*-
"""生成 CosyTool 应用图标：蓝青渐变 + 白色工具箱（复刻菜单上方图标视觉）。

输出 icons/ 目录：1024 源图、Windows ICO、Android mipmap PNG、iOS AppIcon PNG。
"""
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")
os.makedirs(OUT, exist_ok=True)

C1 = (14, 159, 143)   # #0E9F8F
C2 = (55, 182, 201)   # #37B6C9
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)


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


def build_icon(size, rounded=False):
    img = make_gradient(size, C1, C2).convert("RGBA")
    s = size / 1024.0
    cx = size / 2.0
    bg = lerp(C1, C2, 0.55) + (255,)

    # 箱体
    box_w, box_h, r = 520 * s, 330 * s, 78 * s
    x0, x1 = cx - box_w / 2, cx + box_w / 2
    y0, y1 = size * 0.46, size * 0.46 + box_h
    layer = Image.new("RGBA", (size, size), CLEAR)
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=WHITE)

    # 提手：白色圆环上半（拱形），下半自然被箱体同色覆盖
    hr_out, hr_in = 178 * s, 106 * s
    hcy = y0 - 30 * s
    d.ellipse([cx - hr_out, hcy - hr_out, cx + hr_out, hcy + hr_out], fill=WHITE)
    d.ellipse([cx - hr_in, hcy - hr_in, cx + hr_in, hcy + hr_in], fill=CLEAR)
    # 环下缘以下（箱体顶之上部分）保持透明，避免影响箱体轮廓
    d.rectangle([cx - hr_out, y0, cx + hr_out, hcy + hr_out], fill=CLEAR)

    # 锁扣带 + 两端锁扣（背景渐变色）
    band_h = 44 * s
    by0 = y0 + (box_h - band_h) / 2
    by1 = by0 + band_h
    d.rectangle([x0, by0, x1, by1], fill=bg)
    lock_w = 78 * s
    for lx in (x0 + 96 * s, x1 - 96 * s - lock_w):
        d.rectangle([lx, by0, lx + lock_w, by1], fill=bg)

    img.alpha_composite(layer)

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
