"""기술·강화 패 아이콘 수묵 후처리 (다시 그리지 않고 원본에서 굽는다, 원본은 그대로 둔다).

  python tools/art/ink_icons.py preview [출력 폴더]        견본판 (영웅당 하나 × 원본·약·중·강)
  python tools/art/ink_icons.py bake <약|중|강> [출력 폴더]  아이콘 전부를 구워 출력 폴더에 (게임 자산을 덮지 않음)

처리 (세기 s, 약 0.35 · 중 0.6 · 강 0.85):
1. 안쪽 그림: 채도를 낮추되 영웅 대표색(HeroData.body_color)을 옅게 남긴다.
2. 번쩍임 누르기: 밝은 곳(빛·형광)을 눌러 종이 밝기 위로 튀지 않게.
3. 먹·한지: 어두운 쪽은 먹색, 밝은 쪽은 한지색으로 당기고 (두 색 그림), 한지 결(assets/textures/grain/hanji_paper.png)을 곱하고, 살짝 번지게.
4. 금테: 번쩍이는 금을 UiStyle 금색(0.86, 0.68, 0.32)의 차분한 결로.
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ICONS = os.path.join(ROOT, "assets/ui/icons")
GRAIN = os.path.join(ROOT, "assets/textures/grain/hanji_paper.png")
LEVELS = {"약": 0.35, "중": 0.6, "강": 0.85}
INK = (28, 24, 22)
PAPER = (236, 226, 204)
GOLD = (219, 173, 82)
# 영웅 → (대표색 body_color, 기술 아이콘)
HEROES = {
    "yi_sun_sin": ((33, 69, 140), ["haeryong", "pado", "haeil", "counter"]),
    "gwanggaeto": ((140, 64, 38), ["lightning", "thunder_trail", "quake", "conqueror"]),
    "sejong": ((184, 38, 31), ["jeongeum", "meteor", "constellation", "sundial"]),
    "shin_saimdang": ((128, 77, 158), ["critters", "ink_bleed", "canvas", "plum"]),
}
FRAME = 0.075  # 금테 두께 (아이콘 폭 대비)


def _inner_mask(size: int) -> Image.Image:
    m = Image.new("L", (size, size), 0)
    inset = int(size * FRAME)
    ImageDraw.Draw(m).rounded_rectangle([inset, inset, size - inset, size - inset], radius=int(size * 0.06), fill=255)
    return m.filter(ImageFilter.GaussianBlur(size * 0.006))


def _lerp(a: Image.Image, b: Image.Image, t: float) -> Image.Image:
    return Image.blend(a, b, max(0.0, min(1.0, t)))


def _grain(size: int) -> Image.Image:
    g = Image.open(GRAIN).convert("L")
    side = min(g.size)
    return g.crop((0, 0, side, side)).resize((size, size), Image.LANCZOS)


def ink(img: Image.Image, s: float, tint: tuple) -> Image.Image:
    img = img.convert("RGBA")
    size = img.size[0]
    rgb = img.convert("RGB")
    alpha = img.getchannel("A")
    lum = rgb.convert("L")
    # 2. 번쩍임 누르기: 0.62 위 밝기를 눌러 준다
    knee = 158
    lut = [v if v < knee else int(knee + (v - knee) * (1.0 - 0.75 * s)) for v in range(256)]
    lum_c = lum.point(lut)
    # 3'. 먹 번진 종이처럼: 어두운 쪽을 들어 올린다 (검은 바탕 → 옅은 먹)
    lift = 1.0 - 0.45 * s
    lum_c = lum_c.point([int(255 * (v / 255) ** lift) for v in range(256)])
    # 1+3. 먹 · 대표색(옅게, 한지와 섞음) · 한지 세 색으로 다시 물들인다
    mid = tuple(int(p * 0.55 + t * 0.45) for p, t in zip(PAPER, tint))
    wash = ImageOps.colorize(lum_c, black=INK, mid=mid, white=PAPER, midpoint=110)
    art = _lerp(rgb, wash, 0.3 + 0.6 * s)
    grain = _grain(size).point(lambda v, k=12 + 40 * s: int(255 - k * (1 - v / 255)))
    art = ImageChops.multiply(art, Image.merge("RGB", (grain, grain, grain)))
    art = _lerp(art, art.filter(ImageFilter.GaussianBlur(size * 0.004 * (1 + 2 * s))), 0.25 + 0.4 * s)
    # 4. 금테: 원래 테 밝기를 UiStyle 금으로 다시 칠함 (번쩍임은 눌러서)
    flum = lum.point([int(60 + 0.7 * v) for v in range(256)])
    frame = ImageChops.multiply(Image.merge("RGB", (flum, flum, flum)), Image.new("RGB", rgb.size, GOLD))
    frame = ImageChops.add(frame, Image.new("RGB", rgb.size, (18, 12, 6)))
    frame = _lerp(rgb, frame, 0.3 + 0.65 * s)
    out = Image.composite(art, frame, _inner_mask(size))
    out.putalpha(alpha)
    return out


TAGS = {"orig": "원본", "weak": "약", "mid": "중", "strong": "강"}


def _label(img: Image.Image, text: str) -> Image.Image:
    from PIL import ImageFont
    font = ImageFont.truetype(os.path.join(ROOT, "assets/fonts/DeogonPrincess.ttf"), 30)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 84, 40], fill=(0, 0, 0))
    d.text((8, 2), TAGS.get(text, text), fill=(240, 230, 210), font=font)
    return img


def preview(out_dir: str) -> None:
    os.makedirs(out_dir, exist_ok=True)
    pick = {"yi_sun_sin": "haeryong", "gwanggaeto": "lightning", "sejong": "jeongeum", "shin_saimdang": "plum"}
    cols = [("orig", None)] + [(k, v) for k, v in [("weak", 0.35), ("mid", 0.6), ("strong", 0.85)]]
    sheet = Image.new("RGB", (256 * len(cols) + 16 * (len(cols) + 1), 256 * len(pick) + 16 * (len(pick) + 1)), (24, 20, 20))
    for r, (hero, name) in enumerate(pick.items()):
        src = Image.open(os.path.join(ICONS, name + ".png")).convert("RGBA")
        for c, (tag, s) in enumerate(cols):
            im = src if s is None else ink(src, s, HEROES[hero][0])
            sheet.paste(_label(im.copy(), tag), (16 + c * 272, 16 + r * 272), im)
    sheet.save(os.path.join(out_dir, "skill_icons_strengths.png"), optimize=True)
    # 강화 패 그림 (영웅마다 하나씩) 같은 처리
    ups = []
    for hero in HEROES:
        d = os.path.join(ICONS, "upgrades", hero)
        files = sorted(f for f in os.listdir(d) if f.endswith(".png")) if os.path.isdir(d) else []
        if files:
            ups.append((hero, os.path.join(d, files[0])))
    sheet = Image.new("RGB", (256 * len(cols) + 16 * (len(cols) + 1), 256 * len(ups) + 16 * (len(ups) + 1)), (24, 20, 20))
    for r, (hero, path) in enumerate(ups):
        src = Image.open(path).convert("RGBA").resize((256, 256), Image.LANCZOS)
        for c, (tag, s) in enumerate(cols):
            im = src if s is None else ink(src, s, HEROES[hero][0])
            sheet.paste(_label(im.copy(), tag), (16 + c * 272, 16 + r * 272), im)
    sheet.save(os.path.join(out_dir, "upgrade_icons_strengths.png"), optimize=True)


def mock(shot: str, hero: str, out: str) -> None:
    """전투 사진(1080 폭, 화면 720의 1.5배)의 오른쪽 아래 기술 칸 셋에 원본·약·중·강을 얹어 아래쪽을 나란히."""
    base = Image.open(shot).convert("RGB")
    k = base.size[0] / 720.0
    names = HEROES[hero][1][:3]  # 톡 · 내닫기 · 모으기 (SkillButtonDrawer._draw_status 순서)
    crop_top = int(base.size[1] * 0.62)
    cols = []
    for tag, sv in [("orig", None), ("weak", 0.35), ("mid", 0.6), ("strong", 0.85)]:
        im = base.copy()
        for i, n in enumerate(names):
            r = int(32 * k)
            cx = int(base.size[0] - (60 + (len(names) - 1 - i) * 84) * k)
            cy = int(base.size[1] - 74 * k)
            ic = Image.open(os.path.join(ICONS, n + ".png")).convert("RGBA")
            if sv is not None:
                ic = ink(ic, sv, HEROES[hero][0])
            ic = ic.resize((2 * r, 2 * r), Image.LANCZOS)
            im.paste(ic, (cx - r, cy - r), ic)
        cols.append(_label(im.crop((0, crop_top, base.size[0], base.size[1])), tag))
    w, h = cols[0].size
    sheet = Image.new("RGB", (w * 2 + 12, h * 2 + 12), (20, 18, 18))
    for i, c in enumerate(cols):
        sheet.paste(c, ((i % 2) * (w + 12), (i // 2) * (h + 12)))
    sheet.save(out, optimize=True)


def bake(level: str, out_dir: str) -> None:
    s = LEVELS[level]
    os.makedirs(out_dir, exist_ok=True)
    for hero, (tint, names) in HEROES.items():
        for n in names:
            ink(Image.open(os.path.join(ICONS, n + ".png")), s, tint).save(os.path.join(out_dir, n + ".png"), optimize=True)
        up = os.path.join(ICONS, "upgrades", hero)
        if os.path.isdir(up):
            os.makedirs(os.path.join(out_dir, "upgrades", hero), exist_ok=True)
            for f in sorted(os.listdir(up)):
                if f.endswith(".png"):
                    ink(Image.open(os.path.join(up, f)), s, tint).save(os.path.join(out_dir, "upgrades", hero, f), optimize=True)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "preview"
    if mode == "mock":  # mock <전투 사진> <영웅 id> <출력 png>
        mock(sys.argv[2], sys.argv[3], sys.argv[4])
    elif mode == "preview":
        preview(sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "build/preview/icon_ink"))
    else:
        bake(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else os.path.join(ROOT, "build/preview/icon_ink", sys.argv[2]))
