"""만주·경복궁·초충도 세 구역 미리보기 (build/preview/zone_maps/).

  python tools/art/zone_maps_preview.py

- <전장>_stack.jpg : 세 구역 이어 붙임 (만주·경복궁 세로, 구역 1이 아래 / 초충도 가로, 구역 1이 왼쪽), 걸을 곳·자리 표시
- <지도>_layout.jpg : 한 장씩 표시
- 초충도는 왼쪽·오른쪽 가장자리 띠에서 종이 바탕이 이어진 곳(열림)을 초록, 식물로 막힌 곳을 빨강으로
- gyeongbokgung_clean_before_after.jpg : 지운 곳 전·후
"""
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
import zone_maps_layout as L  # noqa: E402
from make_zone_maps import CLEAN, MAPS, ROOT, raw_of  # noqa: E402

OUT = os.path.join(ROOT, "build/preview/zone_maps")
PAPER = np.array([232, 200, 145])


def font(size):
    p = "C:/Windows/Fonts/malgunbd.ttf"
    return ImageFont.truetype(p, size) if os.path.exists(p) else None


def load(sid):
    return Image.open(os.path.join(ROOT, MAPS, f"{sid}.png")).convert("RGB")


def existing_walk(sid):
    t = open(os.path.join(ROOT, f"data/stages/{sid}.tres"), encoding="utf-8").read()
    r = [float(v) for v in re.search(r"^background_rect = Rect2\((.*)\)$", t, re.M).group(1).split(",")]
    n = [float(v) for v in re.search(r"^walk_area = PackedVector2Array\((.*)\)$", t, re.M).group(1).split(",")]
    return [((n[i] - r[0]) * 1024 / r[2], (n[i + 1] - r[1]) * 1536 / r[3]) for i in range(0, len(n), 2)]


def open_runs(img, side, min_len=60):
    """가장자리 48px 띠에서 종이 바탕이 70% 넘는 줄이 min_len 이상 이어진 구간."""
    a = np.asarray(img).astype(int)
    band = a[:, :48] if side == "L" else a[:, -48:]
    frac = (np.abs(band - PAPER).sum(2) < 70).mean(1)
    runs, st = [], None
    for y, f in enumerate(list(frac) + [0]):
        if f > 0.7 and st is None:
            st = y
        elif f <= 0.7 and st is not None:
            if y - st >= min_len:
                runs.append((st, y))
            st = None
    return runs


def label(d, p, text, col, f):
    off = (18, -30) if p[0] < 700 else (-20 - (f.getlength(text) if f else 120), -30)
    d.text((p[0] + off[0], p[1] + off[1]), text, fill=col, font=f, stroke_width=3, stroke_fill=(0, 0, 0))


def annotate(sid, img, stage):
    im = img.convert("RGBA")
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d, f = ImageDraw.Draw(ov), font(22)
    walk = existing_walk(sid) if sid in L.EXISTING else L.WALK[sid]
    d.polygon(walk, fill=(80, 220, 120, 55), outline=(60, 255, 120, 255), width=4)
    if stage in L.HORIZONTAL:
        for side, x in (("L", 6), ("R", 1018)):
            runs = open_runs(img, side)
            d.line([(x, 0), (x, 1536)], fill=(230, 40, 40, 255), width=12)
            for a, b in runs:
                d.line([(x, a), (x, b)], fill=(40, 230, 80, 255), width=12)
    for name, p in L.CROSS.get(sid, {}).items():
        d.ellipse([p[0] - 15, p[1] - 15, p[0] + 15, p[1] + 15], fill=(255, 200, 40, 255), outline=(0, 0, 0, 255), width=3)
        label(d, p, "넘어감 · " + name, (255, 210, 60), f)
    if sid in L.LAND:
        p = L.LAND[sid]
        d.rectangle([p[0] - 16, p[1] - 16, p[0] + 16, p[1] + 16], fill=(70, 170, 255, 255), outline=(0, 0, 0, 255), width=3)
        label(d, p, "내리는 자리", (130, 200, 255), f)
    for name, p in L.BOSS.get(sid, {}).items():
        d.ellipse([p[0] - 17, p[1] - 17, p[0] + 17, p[1] + 17], outline=(255, 60, 60, 255), width=5)
        label(d, p, "우두머리 · " + name, (255, 120, 120), f)
    return Image.alpha_composite(im, ov).convert("RGB")


def stack(stage, imgs):
    seam = 8
    if stage in L.HORIZONTAL:  # 왼쪽 → 오른쪽 = 구역 1 → 3
        out = Image.new("RGB", (sum(i.width for i in imgs) + seam * 2, imgs[0].height), (30, 30, 30))
        x = 0
        for im in imgs:
            out.paste(im, (x, 0))
            x += im.width + seam
        return out
    out = Image.new("RGB", (imgs[0].width, sum(i.height for i in imgs) + seam * 2), (30, 30, 30))
    y = 0
    for im in reversed(imgs):  # 위 = 구역 3
        out.paste(im, (0, y))
        y += im.height + seam
    return out


def clean_sheet():
    rows = []
    for sid, spots in CLEAN.items():
        for _mode, cx, cy, rx, ry, _dx, _dy in spots:
            box = (cx - rx - 30, cy - ry - 30, cx + rx + 30, cy + ry + 30)
            a, b = Image.open(raw_of(sid)).convert("RGB").crop(box), load(sid).crop(box)
            k = 4
            rows.append((a.resize((a.width * k, a.height * k)), b.resize((b.width * k, b.height * k))))
    w = max(a.width for a, _ in rows) * 2 + 30
    sheet = Image.new("RGB", (w, sum(a.height + 12 for a, _ in rows) + 40), (235, 230, 220))
    d = ImageDraw.Draw(sheet)
    d.text((10, 6), "전 (왼쪽) / 후 (오른쪽) — 경복궁 현판 자리 흐린 획, 향로 둥근 무늬", fill=(0, 0, 0), font=font(20))
    y = 40
    for a, b in rows:
        sheet.paste(a, (0, y))
        sheet.paste(b, (a.width + 30, y))
        y += a.height + 12
    return sheet


def main():
    os.makedirs(OUT, exist_ok=True)
    for stage, sids in L.ZONES.items():
        lay = []
        for sid in sids:
            im = annotate(sid, load(sid), stage)
            im.save(os.path.join(OUT, f"{sid}_layout.jpg"), quality=88)
            lay.append(im)
        s = stack(stage, lay)
        s.thumbnail((2400, 2400), Image.LANCZOS)
        s.save(os.path.join(OUT, f"{stage}_stack.jpg"), quality=86)
        if stage in L.HORIZONTAL:
            for sid in sids:
                img = load(sid)
                print(sid, "열림 L", open_runs(img, "L"), "R", open_runs(img, "R"))
    clean_sheet().save(os.path.join(OUT, "gyeongbokgung_clean_before_after.jpg"), quality=90)
    print("->", OUT)


if __name__ == "__main__":
    main()
