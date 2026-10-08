#!/usr/bin/env python3
"""Generate the CamBreaker Camera Control Edition app icon set.

Design: midnight background, three rows of glossy Breakout bricks,
a white paddle + glowing ball, and a cyan Camera Control pill on the
right edge — the game's signature feature, right on the icon.
"""
from PIL import Image, ImageDraw

SIZE = 1024
BG = (10, 10, 20)
ROWS = [
    [(235, 60, 70), (245, 130, 30), (250, 200, 40), (80, 220, 90), (60, 180, 250), (90, 110, 250)],
    [(80, 220, 90), (60, 180, 250), (90, 110, 250), (235, 60, 70), (245, 130, 30), (250, 200, 40)],
    [(150, 152, 160), (150, 152, 160), (250, 200, 40), (250, 200, 40), (150, 152, 160), (150, 152, 160)],
]

img = Image.new("RGB", (SIZE, SIZE), BG)
d = ImageDraw.Draw(img, "RGBA")

# Subtle vignette glow behind the action.
for r in range(420, 40, -1):
    alpha = int(38 * (1 - r / 420))
    d.ellipse([SIZE // 2 - r, 300 - r, SIZE // 2 + r, 300 + r], fill=(40, 90, 160, alpha))

# Brick rows.
margin, gap = 110, 16
bw = (SIZE - 2 * margin - 5 * gap) // 6
bh = 88
top = 150
for ri, row in enumerate(ROWS):
    y = top + ri * (bh + gap)
    for ci, col in enumerate(row):
        x = margin + ci * (bw + gap)
        d.rounded_rectangle([x, y, x + bw, y + bh], radius=20, fill=col)
        # glossy top highlight
        d.rounded_rectangle([x + 8, y + 8, x + bw - 8, y + 30], radius=12, fill=(255, 255, 255, 70))

# Ball with glow.
ball = (SIZE // 2 + 130, 640)
for r, a in ((60, 40), (44, 70), (30, 255)):
    d.ellipse([ball[0] - r, ball[1] - r, ball[0] + r, ball[1] + r], fill=(255, 255, 255, a))

# Paddle.
pw, ph, py = 380, 56, 800
d.rounded_rectangle([SIZE // 2 - pw // 2, py, SIZE // 2 + pw // 2, py + ph], radius=28,
                    fill=(245, 245, 250))
d.rounded_rectangle([SIZE // 2 - pw // 2, py, SIZE // 2 + pw // 2, py + 18], radius=9,
                    fill=(120, 200, 255, 160))

# Camera Control pill (right edge, cyan).
d.rounded_rectangle([SIZE - 74, 300, SIZE - 34, 620], radius=20, fill=(60, 220, 235))
d.rounded_rectangle([SIZE - 68, 330, SIZE - 40, 470], radius=12, fill=(10, 10, 20, 110))

img.save("icon-1024.png")

# Downscaled copies for the classic appiconset slots.
for s in (180, 167, 152, 120, 87, 80, 60, 58, 40, 29, 20):
    img.resize((s, s), Image.LANCZOS).save(f"icon-{s}.png")
print("icons written")
