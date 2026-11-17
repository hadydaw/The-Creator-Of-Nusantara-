"""Potong lembar 6 pose tangan (grid 3x2, latar magenta) -> assets/hand_{buka,longgar,genggam,jepit,telapak,jangkau}.png
Pakai: python3 -I tools/process_hands.py LEMBAR"""
import sys, numpy as np
from PIL import Image
sheet = Image.open(sys.argv[1]).convert("RGB")
a = np.asarray(sheet).astype(np.float32)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
mag = np.clip((np.minimum(r, b) - g) / 255.0, 0, 1)
alpha = 1.0 - np.clip((mag - 0.3) / 0.4, 0, 1)
spill = np.clip(np.minimum(r, b) - g, 0, None) * 0.85
rgba = np.dstack([r - spill * (alpha < 1), g, b - spill * (alpha < 1), alpha * 255]).clip(0, 255).astype(np.uint8)
im = Image.fromarray(rgba, "RGBA")
Wd, Hd = im.size
names = ["buka", "longgar", "genggam", "jepit", "telapak", "jangkau"]
cells = []
for i, nm in enumerate(names):
    col, row = i % 3, i // 3
    box = (col * Wd // 3, row * Hd // 2, (col + 1) * Wd // 3, (row + 1) * Hd // 2)
    c = im.crop(box)
    bb = c.getchannel("A").point(lambda v: 255 if v > 30 else 0).getbbox()
    cells.append((nm, c, bb))
CH = max(bb[3] - bb[1] for _, _, bb in cells)
CW = Wd // 3
f = 900 / CH
for nm, c, bb in cells:
    out = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    out.paste(c.crop((0, bb[1], CW, bb[3])), (0, CH - (bb[3] - bb[1])))  # rata bawah
    out = out.resize((round(CW * f), round(CH * f)), Image.LANCZOS)
    out.save(f"assets/hand_{nm}.png")
    print(nm, out.size)
