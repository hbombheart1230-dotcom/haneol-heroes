"""한산 세 배 지도 미리보기 (build/preview/hansan_ships/): 걸을 곳·뛰어넘는/내리는 자리 표시, 세 장 세로 잇기, 문양 덮기 전·후.

  python tools/art/hansan_ships_preview.py
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
import hansan_ships_layout as L  # noqa: E402
from make_hansan_ships import CRESTS, ROOT, raw_path  # noqa: E402

OUT = os.path.join(ROOT, "build/preview/hansan_ships")
MAPS = os.path.join(ROOT, "assets/concept/stages/maps")
ORDER = ["hansan_atakebune", "hansan_sekibune", "hansan_1592"]  # 위 → 아래
GAP = 240
SEA_PATCH = (0, 300, 50, 480)  # 각 지도 왼쪽 가장자리 바다 (떠다니는 판자 없는 곳, 원본 픽셀)


def font(size):
    p = "C:/Windows/Fonts/malgunbd.ttf"
    return ImageFont.truetype(p, size) if os.path.exists(p) else None


def load(sid):
    return Image.open(os.path.join(MAPS, f"{sid}.png")).convert("RGB")


def hansan_walk_px():
    """구역 1 walk_area(월드, data/stages/hansan_1592.tres)를 원본 픽셀로."""
    import re
    t = open(os.path.join(ROOT, "data/stages/hansan_1592.tres"), encoding="utf-8").read()
    nums = [float(v) for v in re.search(r"^walk_area = PackedVector2Array\((.*)\)$", t, re.M).group(1).split(",")]
    x, y, w, h = L.MAP_RECT
    return [((nums[i] - x) * L.SRC_SIZE[0] / w, (nums[i + 1] - y) * L.SRC_SIZE[1] / h) for i in range(0, len(nums), 2)]


def annotate(sid, img):
    im = img.convert("RGBA")
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    f = font(22)
    walk = L.WALK.get(sid) or hansan_walk_px()
    d.polygon(walk, fill=(80, 220, 120, 60), outline=(60, 255, 120, 255), width=4)
    if sid == "hansan_sekibune":
        for path in L.SEKIBUNE_SIDE_PATHS:
            d.line(path, fill=(255, 200, 40, 255), width=6)
        d.line(L.SEKIBUNE_ROOF_PATH, fill=(255, 80, 200, 255), width=6)
    for name, p in L.JUMP.get(sid, {}).items():
        col = (255, 80, 200, 255) if "안 B" in name else (255, 200, 40, 255)
        d.ellipse([p[0] - 14, p[1] - 14, p[0] + 14, p[1] + 14], fill=col, outline=(0, 0, 0, 255), width=3)
        off = (18, -34) if p[0] > 560 else ((-20, 22) if p[0] < 460 else (-150, 52))
        d.text((p[0] + off[0], p[1] + off[1]), name, fill=col, font=f, stroke_width=3, stroke_fill=(0, 0, 0))
    if L.LAND.get(sid):
        p = L.LAND[sid]
        d.rectangle([p[0] - 16, p[1] - 16, p[0] + 16, p[1] + 16], fill=(70, 170, 255, 255), outline=(0, 0, 0, 255), width=3)
        d.text((p[0] + 22, p[1] - 12), "내리는 자리", fill=(120, 200, 255), font=f, stroke_width=3, stroke_fill=(0, 0, 0))
    for name, p in L.BOSS_SPOT.get(sid, {}).items():
        d.ellipse([p[0] - 16, p[1] - 16, p[0] + 16, p[1] + 16], outline=(255, 60, 60, 255), width=5)
        d.text((p[0] + 22, p[1] - 12), "우두머리 · " + name, fill=(255, 110, 110), font=f, stroke_width=3, stroke_fill=(0, 0, 0))
    return Image.alpha_composite(im, ov).convert("RGB")


def sea_band(img, width, height):
    patch = img.crop(SEA_PATCH)
    row = Image.new("RGB", (width, patch.height))
    for i, x in enumerate(range(0, width, patch.width)):
        row.paste(patch if i % 2 == 0 else patch.transpose(Image.FLIP_LEFT_RIGHT), (x, 0))
    band = Image.new("RGB", (width, height))
    for j, y in enumerate(range(0, height, row.height)):
        band.paste(row if j % 2 == 0 else row.transpose(Image.FLIP_TOP_BOTTOM), (0, y))
    return band.filter(ImageFilter.GaussianBlur(5))  # 이어 붙인 자국을 흐려 멀리 보이는 물로


def stack(maps, blend: bool):
    w = maps[0].width
    out = Image.new("RGB", (w, sum(m.height for m in maps) + GAP * (len(maps) - 1)))
    y = 0
    for i, m in enumerate(maps):
        out.paste(m, (0, y))
        y += m.height
        if i + 1 < len(maps):
            up, lo = sea_band(m, w, GAP), sea_band(maps[i + 1], w, GAP)
            if blend:  # 점점 물드는 띠: 위 배 바다 → 아래 배 바다
                mask = Image.linear_gradient("L").resize((w, GAP))
                gap = Image.composite(lo, up, mask)
            else:  # 그냥 반씩
                gap = up.copy()
                gap.paste(lo.crop((0, GAP // 2, w, GAP)), (0, GAP // 2))
            out.paste(gap, (0, y))
            y += GAP
    return out


def crest_before_after():
    raw, done = Image.open(raw_path()).convert("RGB"), load("hansan_atakebune")
    box = (0, 1120, 1024, 1536)
    a, b = raw.crop(box), done.crop(box)
    sheet = Image.new("RGB", (a.width, a.height * 2 + 50), (235, 230, 220))
    d = ImageDraw.Draw(sheet)
    d.text((10, 2), "전 (금빛 꽃 7개)", fill=(0, 0, 0), font=font(20))
    sheet.paste(a, (0, 24))
    d.text((10, a.height + 26), "후 (옆 나무판 복사로 덮음)", fill=(0, 0, 0), font=font(20))
    sheet.paste(b, (0, a.height + 50))
    da = ImageDraw.Draw(sheet)
    for cx, cy, rx, ry, _dx, _dy in CRESTS:
        for top in (24, a.height + 50):
            yy = cy - box[1] + top
            da.ellipse([cx - rx - 8, yy - ry - 8, cx + rx + 8, yy + ry + 8], outline=(255, 40, 40), width=3)
    return sheet


def main():
    os.makedirs(OUT, exist_ok=True)
    maps = [load(s) for s in ORDER]
    for sid, m in zip(ORDER, maps):
        annotate(sid, m).save(os.path.join(OUT, f"{sid}_layout.jpg"), quality=88)
    plain, blend = stack(maps, False), stack(maps, True)
    s = 0.5
    side = Image.new("RGB", (int(plain.width * s) * 2 + 30, int(plain.height * s)), (235, 230, 220))
    side.paste(plain.resize((int(plain.width * s), int(plain.height * s)), Image.LANCZOS), (0, 0))
    side.paste(blend.resize((int(blend.width * s), int(blend.height * s)), Image.LANCZOS), (int(plain.width * s) + 30, 0))
    side.save(os.path.join(OUT, "stack_plain_vs_blend.jpg"), quality=85)
    lay = [annotate(sid, m) for sid, m in zip(ORDER, maps)]
    stack(lay, True).resize((512, int(stack(lay, True).height / 2)), Image.LANCZOS).save(os.path.join(OUT, "stack_layout.jpg"), quality=85)
    crest_before_after().save(os.path.join(OUT, "atakebune_crests_before_after.jpg"), quality=90)
    for sid in ORDER[:2]:
        print(sid, "walk(world):", [L.world(p) for p in L.WALK[sid]])
        print(sid, "jump(world):", {k: L.world(v) for k, v in L.JUMP[sid].items()}, "land:", L.world(L.LAND[sid]))
    print("boss(world):", {k: L.world(v) for k, v in L.BOSS_SPOT["hansan_atakebune"].items()})
    print("jump 1592(world):", {k: L.world(v) for k, v in L.JUMP["hansan_1592"].items()})
    print("->", OUT)


if __name__ == "__main__":
    main()
