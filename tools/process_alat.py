"""Potong lembar 6 frame animasi alat (grid 3x2, latar magenta) -> assets/alat_NAMA_1..6.png
Skala sama dengan tangan polos (faktor 1.6). Pakai: python3 -I tools/process_alat.py LEMBAR NAMA"""
import sys, numpy as np
from PIL import Image
sheet = Image.open(sys.argv[1]).convert("RGB"); name = sys.argv[2]
a = np.asarray(sheet).astype(np.float32)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
mag = np.clip((np.minimum(r, b) - g) / 255.0, 0, 1)
alpha = 1.0 - np.clip((mag - 0.3) / 0.4, 0, 1)
spill = np.clip(np.minimum(r, b) - g, 0, None) * 0.85 * (alpha < 1)
r2, b2 = r - spill, b - spill
if len(sys.argv) > 4:  # air/percikan: sisa merah jambu -> putih kebiruan
    w = (alpha < 0.97) & ((r2 - g) > 12) & ((b2 - g) > 12)
    r2 = np.where(w, 215, r2); g = np.where(w, 235, g); b2 = np.where(w, 255, b2)
im = Image.fromarray(np.dstack([r2, g, b2, alpha * 255]).clip(0, 255).astype(np.uint8), "RGBA")
Wd, Hd = im.size
F = float(sys.argv[3]) if len(sys.argv) > 3 else 1.6
ARM = len(sys.argv) > 4  # argumen ke-4: sejajarkan lengan (tengah lengan di 70% kanvas)
for i in range(6):
    col, row = i % 3, i // 3
    c = im.crop((col * Wd // 3, row * Hd // 2, (col + 1) * Wd // 3, (row + 1) * Hd // 2))
    bb = c.getchannel("A").point(lambda v: 255 if v > 30 else 0).getbbox()
    CH = int(sys.argv[4]) if ARM else 620
    CWc = 640 if ARM else c.width
    out = Image.new("RGBA", (CWc, CH), (0, 0, 0, 0))
    top = max(0, bb[3] - CH)
    piece = c.crop((0, top, c.width, bb[3]))
    dx = 0
    if ARM:
        row = np.asarray(c.getchannel("A"))[bb[3] - 6:bb[3]].max(axis=0) > 30
        xs = np.where(row)[0]
        dx = int(CWc * 0.7 - (xs.min() + xs.max()) / 2)
    out.paste(piece, (dx, CH - (bb[3] - top)))  # rata bawah
    out = out.resize((round(out.width * F), round(CH * F)), Image.LANCZOS)
    out.save(f"assets/alat_{name}_{i+1}.png"); print(i + 1, out.size)
