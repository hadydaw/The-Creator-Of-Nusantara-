"""Memotong lembar tekstur dan rumpun hasil AI menjadi aset game.
Pakai: python3 -I tools/process_textures.py SHEET_RUMPUT SHEET_TANAH SHEET_RUMPUN
"""
import sys
import numpy as np
from PIL import Image

SIZE = 512


def magenta_mask(a):
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    return (r > 200) & (b > 200) & (g < 90)


def find_runs(flags, min_len=40):
    runs, start = [], None
    for i, f in enumerate(flags):
        if f and start is None:
            start = i
        elif not f and start is not None:
            if i - start >= min_len:
                runs.append((start, i))
            start = None
    if start is not None and len(flags) - start >= min_len:
        runs.append((start, len(flags)))
    return runs


def make_seamless(img):
    a = np.asarray(img).astype(np.float32)
    n = a.shape[0]
    shifted = np.roll(a, (n // 2, n // 2), axis=(0, 1))
    x = np.arange(n, dtype=np.float32)
    w = 0.5 - 0.5 * np.cos(2 * np.pi * x / n)
    m = (w[:, None] * w[None, :])[..., None]
    out = a * m + shifted * (1 - m)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def swatches(path, names):
    im = Image.open(path).convert("RGB")
    a = np.asarray(im)
    cols = ~magenta_mask(a).mean(axis=0).__gt__(0.5)  # kolom yang bukan magenta
    runs = find_runs(cols)
    assert len(runs) == 3, f"ditemukan {len(runs)} kotak di {path}"
    rows = ~magenta_mask(a).mean(axis=1).__gt__(0.5)
    rr = find_runs(rows)[0]
    for (x0, x1), name in zip(runs, names):
        inset = 6
        tile = im.crop((x0 + inset, rr[0] + inset, x1 - inset, rr[1] - inset))
        s = min(tile.size)
        tile = tile.crop((0, 0, s, s)).resize((SIZE, SIZE), Image.LANCZOS)
        make_seamless(tile).save(f"assets/tex/{name}.png")
        print("tekstur", name, tile.size)


def clumps(path, names, max_side=512):
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = np.minimum(r, b) - g  # seberapa magenta
    alpha = np.clip(1.0 - (m - 25.0) / 70.0, 0, 1)
    alpha[m < 25] = 1.0
    # despill: turunkan merah/biru yang berlebih di tepi
    lim = g * 1.0
    r2 = np.where(m > 0, np.minimum(r, lim), r)
    b2 = np.where(m > 0, np.minimum(b, lim), b)
    rgb = np.dstack([r2, g, b2])
    # tepi transparan diisi warna hijau agar tidak ada halo magenta
    fill = np.array([70, 140, 40], dtype=np.float32)
    rgb = np.where(alpha[..., None] < 0.05, fill, rgb)
    rgba = np.dstack([rgb, alpha * 255.0]).astype(np.uint8)
    full = Image.fromarray(rgba, "RGBA")
    solid = alpha > 0.5
    cols = solid.any(axis=0)
    runs = find_runs(cols, min_len=30)
    # gabungkan jalur yang berdekatan (helai terpisah)
    merged = []
    for s, e in runs:
        if merged and s - merged[-1][1] < 25:
            merged[-1] = (merged[-1][0], e)
        else:
            merged.append((s, e))
    assert len(merged) == 3, f"ditemukan {len(merged)} rumpun: {merged}"
    for (x0, x1), name in zip(merged, names):
        sub = solid[:, x0:x1]
        ys = np.where(sub.any(axis=1))[0]
        y0, y1 = ys.min(), ys.max() + 1
        c = full.crop((x0, y0, x1, y1))
        sc = max_side / max(c.size)
        c = c.resize((max(1, int(c.size[0] * sc)), max(1, int(c.size[1] * sc))), Image.LANCZOS)
        c.save(f"assets/tex/{name}.png")
        print("rumpun", name, c.size)


if __name__ == "__main__":
    swatches(sys.argv[1], ["grass_fresh", "grass_dry", "grass_dark"])
    swatches(sys.argv[2], ["soil_tilled", "soil_wet", "soil_dry"])
    clumps(sys.argv[3], ["clump_short", "clump_tall", "clump_flower"])
