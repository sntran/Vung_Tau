"""Cloth prints made by code: small flowers, checks, plain worn cloth."""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import random, sys, os


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def worn(img, seed, amount=10):
    rng = np.random.default_rng(seed)
    a = np.asarray(img).astype(np.float32)
    noise = rng.normal(0, amount, a.shape[:2])[..., None]
    blot = Image.fromarray((rng.random((32, 32)) * 255).astype(np.uint8)).resize(img.size, Image.BICUBIC)
    blot = (np.asarray(blot).astype(np.float32) / 255.0 - 0.5)[..., None] * amount * 1.6
    a = np.clip(a + noise + blot, 0, 255)
    return Image.fromarray(a.astype(np.uint8))


def flowers(base, petal, center, leaf, size=1024, scale=1.0, seed=1):
    rnd = random.Random(seed)
    img = Image.new("RGB", (size, size), hexrgb(base))
    d = ImageDraw.Draw(img)
    step = int(64 * scale)
    for gy in range(-step, size + step, step):
        for gx in range(-step, size + step, step):
            x = gx + rnd.randint(-step // 3, step // 3) + (step // 2 if (gy // step) % 2 else 0)
            y = gy + rnd.randint(-step // 3, step // 3)
            r = rnd.uniform(7, 11) * scale
            # two leaves
            for ang in (rnd.uniform(0, 6.28), rnd.uniform(0, 6.28)):
                lx, ly = x + np.cos(ang) * r * 1.6, y + np.sin(ang) * r * 1.6
                d.ellipse([lx - r * 0.7, ly - r * 0.35, lx + r * 0.7, ly + r * 0.35], fill=hexrgb(leaf))
            for k in range(5):
                ang = k * 1.2566 + rnd.uniform(0, 0.4)
                px, py = x + np.cos(ang) * r * 0.75, y + np.sin(ang) * r * 0.75
                d.ellipse([px - r * 0.55, py - r * 0.55, px + r * 0.55, py + r * 0.55], fill=hexrgb(petal))
            d.ellipse([x - r * 0.3, y - r * 0.3, x + r * 0.3, y + r * 0.3], fill=hexrgb(center))
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    return worn(img, seed, 8)


def checks(base, line, size=1024, step=48, seed=2):
    img = Image.new("RGB", (size, size), hexrgb(base))
    d = ImageDraw.Draw(img)
    for i in range(0, size, step):
        d.rectangle([i, 0, i + step // 4, size], fill=hexrgb(line))
        d.rectangle([0, i, size, i + step // 4], fill=hexrgb(line))
    img = Image.blend(Image.new("RGB", (size, size), hexrgb(base)), img, 0.55)
    return worn(img.filter(ImageFilter.GaussianBlur(0.7)), seed, 7)


def plain(base, size=512, seed=3):
    return worn(Image.new("RGB", (size, size), hexrgb(base)), seed, 9)


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    flowers("#B9C7D6", "#F2EEE6", "#D9A441", "#6F8F78", seed=11).save(f"{out}/dobo_batu.png")
    flowers("#8E5A60", "#E8D7C9", "#E2C36B", "#5F7563", scale=1.2, seed=12).save(f"{out}/dobo_cosau.png")
    checks("#2F4E7A", "#C9CED6", step=44, seed=7).save(f"{out}/plaid_navy.png")
