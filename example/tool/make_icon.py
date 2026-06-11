#!/usr/bin/env python3
"""Generate the Document Scanner launcher icon: a sheet of paper with a
smartphone scanning it (green scan brackets + beam)."""
from PIL import Image, ImageDraw
import sys

SS = 4          # supersample factor for anti-aliasing
S = 1024        # final size
W = S * SS      # working size

BLUE_TOP = (30, 136, 229)
BLUE_BOT = (13, 71, 161)
WHITE = (255, 255, 255, 255)
LINE = (207, 216, 220, 255)
PHONE = (38, 50, 56, 255)
SCREEN = (236, 239, 241, 255)
LENS = (96, 125, 139, 255)
GREEN = (0, 230, 118, 255)


def px(v):  # scale a 1024-space value into working space
    return int(v * SS)


def vgradient_rounded(size, top, bottom, radius):
    base = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    grad = Image.new("RGBA", (size, size))
    gd = ImageDraw.Draw(grad)
    for y in range(size):
        t = y / (size - 1)
        r = int(top[0] + (bottom[0] - top[0]) * t)
        g = int(top[1] + (bottom[1] - top[1]) * t)
        b = int(top[2] + (bottom[2] - top[2]) * t)
        gd.line([(0, y), (size, y)], fill=(r, g, b, 255))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=radius, fill=255
    )
    base.paste(grad, (0, 0), mask)
    return base


def make_subject():
    """Subject (sheet + scanning phone) on a transparent WxW canvas, centered."""
    canvas = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    cx = W // 2

    # --- document (back), tilted left ---
    dw, dh = px(430), px(560)
    doc = Image.new("RGBA", (dw, dh), (0, 0, 0, 0))
    dd = ImageDraw.Draw(doc)
    dd.rounded_rectangle([0, 0, dw - 1, dh - 1], radius=px(26), fill=WHITE)
    lx0, lx1 = px(58), dw - px(58)
    ly, gap, lh = px(86), px(74), px(26)
    for i in range(5):
        x1 = lx1 if i != 4 else int(dw * 0.6)
        dd.rounded_rectangle([lx0, ly, x1, ly + lh], radius=lh // 2, fill=LINE)
        ly += gap
    doc = doc.rotate(11, expand=True, resample=Image.BICUBIC)
    canvas.alpha_composite(
        doc, (cx - px(150) - doc.width // 2, W // 2 - px(70) - doc.height // 2)
    )

    # --- smartphone (front, tilted right) actively scanning ---
    pw, ph = px(320), px(600)
    phone = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    pd = ImageDraw.Draw(phone)
    pd.rounded_rectangle([0, 0, pw - 1, ph - 1], radius=px(58), fill=PHONE)
    m = px(20)
    pd.rounded_rectangle(
        [m, px(64), pw - m, ph - px(64)], radius=px(40), fill=SCREEN
    )
    pd.ellipse([pw // 2 - px(9), px(30), pw // 2 + px(9), px(48)], fill=LENS)

    # green scan corner brackets + beam on the phone screen
    sx0, sy0 = m + px(30), px(140)
    sx1, sy1 = pw - m - px(30), ph - px(140)
    t, blen = px(15), px(66)
    pd.rectangle([sx0, sy0, sx0 + blen, sy0 + t], fill=GREEN)
    pd.rectangle([sx0, sy0, sx0 + t, sy0 + blen], fill=GREEN)
    pd.rectangle([sx1 - blen, sy0, sx1, sy0 + t], fill=GREEN)
    pd.rectangle([sx1 - t, sy0, sx1, sy0 + blen], fill=GREEN)
    pd.rectangle([sx0, sy1 - t, sx0 + blen, sy1], fill=GREEN)
    pd.rectangle([sx0, sy1 - blen, sx0 + t, sy1], fill=GREEN)
    pd.rectangle([sx1 - blen, sy1 - t, sx1, sy1], fill=GREEN)
    pd.rectangle([sx1 - t, sy1 - blen, sx1, sy1], fill=GREEN)
    by = (sy0 + sy1) // 2
    pd.rectangle([sx0, by - px(5), sx1, by + px(5)], fill=(0, 230, 118, 200))

    phone = phone.rotate(-11, expand=True, resample=Image.BICUBIC)
    canvas.alpha_composite(
        phone, (cx + px(150) - phone.width // 2, W // 2 + px(80) - phone.height // 2)
    )
    return canvas


def fit_subject(subject, frac):
    """Return a WxW canvas with the subject scaled to occupy `frac` of width."""
    bbox = subject.getbbox()
    cropped = subject.crop(bbox)
    target_w = int(W * frac)
    scale = target_w / cropped.width
    target_h = int(cropped.height * scale)
    if target_h > int(W * frac):
        scale = int(W * frac) / cropped.height
        target_w = int(cropped.width * scale)
        target_h = int(W * frac)
    resized = cropped.resize((target_w, target_h), Image.LANCZOS)
    out = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    out.alpha_composite(resized, ((W - target_w) // 2, (W - target_h) // 2))
    return out


def main():
    legacy_path, fg_path, bg_path = sys.argv[1], sys.argv[2], sys.argv[3]
    subject = make_subject()

    # Legacy full icon: gradient rounded-square bg + subject
    bg = vgradient_rounded(W, BLUE_TOP, BLUE_BOT, radius=px(180))
    legacy = bg.copy()
    legacy.alpha_composite(fit_subject(subject, 0.74))
    legacy.resize((S, S), Image.LANCZOS).save(legacy_path)

    # Adaptive foreground: subject fills most of the drawable; the adaptive
    # XML adds a 16% inset for the safe zone (0.90 * 0.68 ≈ 0.61 of the icon).
    fit_subject(subject, 0.90).resize((S, S), Image.LANCZOS).save(fg_path)

    # Adaptive background: full-bleed gradient (launcher applies the mask)
    fullbg = Image.new("RGBA", (W, W))
    gd = ImageDraw.Draw(fullbg)
    for y in range(W):
        t = y / (W - 1)
        gd.line(
            [(0, y), (W, y)],
            fill=(
                int(BLUE_TOP[0] + (BLUE_BOT[0] - BLUE_TOP[0]) * t),
                int(BLUE_TOP[1] + (BLUE_BOT[1] - BLUE_TOP[1]) * t),
                int(BLUE_TOP[2] + (BLUE_BOT[2] - BLUE_TOP[2]) * t),
                255,
            ),
        )
    fullbg.resize((S, S), Image.LANCZOS).save(bg_path)

    print("wrote", legacy_path, fg_path, bg_path)


if __name__ == "__main__":
    main()
