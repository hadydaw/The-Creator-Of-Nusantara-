"""Potong lembar 3 sprite (latar magenta) jadi PNG RGBA terpisah.
Pakai: python3 -I tools/process_sprites.py LEMBAR NAMA   (hasil: assets/spr/NAMA_{tunas,dewasa,buah}.png)"""
import sys, numpy as np
from PIL import Image
from scipy import ndimage

def key(im):
    a = np.asarray(im.convert("RGB")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mag = np.clip((np.minimum(r, b) - g) / 255.0, 0, 1)      # seberapa magenta
    alpha = 1.0 - np.clip((mag - 0.25) / 0.45, 0, 1)
    # despill: tekan sisa magenta di tepi
    spill = np.clip(np.minimum(r, b) - g, 0, None) * (alpha < 1.0)
    r2 = r - spill * 0.8; b2 = b - spill * 0.8
    out = np.dstack([r2, g, b2, alpha * 255]).clip(0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")

sheet, name = sys.argv[1], sys.argv[2]
im = key(Image.open(sheet))
al = np.asarray(im)[..., 3] > 40
lab, n = ndimage.label(ndimage.binary_dilation(al, iterations=12))
objs = ndimage.find_objects(lab)
objs = sorted(objs, key=lambda s: s[1].start)
objs = [o for o in objs if (o[0].stop - o[0].start) > 80][:3]
assert len(objs) == 3, len(objs)
import os; os.makedirs("assets/spr", exist_ok=True)
crops = []
for o in objs:
    c = im.crop((o[1].start, o[0].start, o[1].stop, o[0].stop))
    bb = c.getchannel("A").point(lambda v: 255 if v > 20 else 0).getbbox()
    crops.append(c.crop(bb))
f = min(1.0, 640 / max(max(c.size) for c in crops))  # skala sama agar ukuran relatif terjaga
for c, nm in zip(crops, ["tunas", "dewasa", "buah"]):
    c = c.resize((max(1, round(c.width * f)), max(1, round(c.height * f))), Image.LANCZOS)
    c.save(f"assets/spr/{name}_{nm}.png")
    print(name, nm, c.size)
