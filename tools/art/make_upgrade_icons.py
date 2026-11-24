"""레벨업 강화 카드 아이콘을 만든다: 강화마다 그림 하나 (영웅에 맞게, 같은 기술 강화끼리도 다르게).

  python tools/art/make_upgrade_icons.py          # PNG 만들기 + data/upgrades/*.tres의 icon 연결
  python tools/art/make_upgrade_icons.py --sheet out.png   # 확인용 한 장 모음도

재료는 저장소에 이미 있는 그림만 쓴다 (외부 자산 없음):
  assets/ui/icons/*.png (기술 그림), assets/vfx/*.png (이펙트), 새 원화 assets/concept/redesign/heroes (영웅 상반신).
만드는 법 (어떤 강화에 무엇을 쓰는지는 upgrade_icon_spec.py):
  1) 안쪽 그림: 기술 그림의 다른 부분을 당겨 보거나, 영웅 바탕 위에 이펙트·상반신을 얹는다.
  2) 큰 변형(major)은 기술 그림 위에 변형 이펙트를 겹친다.
  3) 영웅 기술 아이콘의 금테를 그대로 두르고, 오른쪽 아래에 효과 표지 (icon_badges.py).
출력: assets/ui/icons/upgrades/<영웅>/<강화 id>.png (SIZE px).
GPT 그림 교체: assets/concept/upgrade_icons/<영웅>/<강화 id>.png 를 넣고 다시 돌리면 금테·표지를 두른 채 바뀐다
  (프롬프트: docs/upgrade_icon_prompts.md). 새 PNG의 .import는 compress/mode=1 (손실 압축, 다른 아이콘과 같게).
"""
import os
import re
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
from icon_badges import badge  # noqa: E402
from upgrade_icon_spec import HEROES, SPEC  # noqa: E402
from make_portraits import portrait  # noqa: E402
import ink_icons  # noqa: E402  (수묵 후처리, 사용자 결정 2026-11-24 "약")

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BUST_SCALE, BUST_DROP = 1.7, 0.22  # "강건" 상반신: 초상보다 넓게, 어깨가 보이게 아래로
SIZE = 192  # 카드에는 130px 정도로 그려진다. 고해상 폰에서도 깨지지 않게 조금 크게
WORK = 256  # 원본 기술 아이콘 크기에서 작업
INSET, RADIUS = 11, 22  # 기술 아이콘 금테 안쪽 (256 기준)
BADGE = 0.36  # 표지 지름 (아이콘 대비)
OUT_DIR = "assets/ui/icons/upgrades"
GPT_DIR = "assets/concept/upgrade_icons"  # GPT 원본 (APK 제외 폴더). 넣고 다시 돌리면 그 강화만 바뀐다


def _load(rel: str) -> Image.Image:
    return Image.open(os.path.join(ROOT, rel)).convert("RGBA")


def _icon(name: str) -> Image.Image:
    """기술 아이콘 원본 (수묵 처리 전, assets/concept/icons_src). 수묵은 아래 make_icon에서 한 번만 건다."""
    src = f"assets/concept/icons_src/{name}.png"
    rel = src if os.path.exists(os.path.join(ROOT, src)) else f"assets/ui/icons/{name}.png"
    return _load(rel).resize((WORK, WORK), Image.LANCZOS)


def _inner_mask() -> Image.Image:
    m = Image.new("L", (WORK, WORK), 0)
    ImageDraw.Draw(m).rounded_rectangle([INSET, INSET, WORK - INSET - 1, WORK - INSET - 1], RADIUS, fill=255)
    return m


def _zoomed(img: Image.Image, zoom: float, focus) -> Image.Image:
    """금테 안쪽 그림에서 focus를 가운데로 zoom배 당긴다 (테두리 밖은 쓰지 않는다)."""
    inner = img.crop((INSET, INSET, WORK - INSET, WORK - INSET))
    w = inner.width
    side = w / zoom
    cx = min(max(focus[0] * w, side / 2), w - side / 2)
    cy = min(max(focus[1] * w, side / 2), w - side / 2)
    box = (int(cx - side / 2), int(cy - side / 2), int(cx + side / 2), int(cy + side / 2))
    out = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 255))
    out.paste(inner.crop(box).resize((WORK, WORK), Image.LANCZOS), (0, 0))
    return out


def _tone(img: Image.Image, tone) -> Image.Image:
    if tone is None:
        return img
    rgb, a = img.convert("RGB"), img.getchannel("A")
    if tone == "warm":
        rgb = Image.blend(rgb, Image.new("RGB", rgb.size, (255, 120, 40)), 0.14)
        rgb = ImageEnhance.Contrast(rgb).enhance(1.1)
    elif tone == "cool":
        rgb = Image.blend(rgb, Image.new("RGB", rgb.size, (60, 150, 255)), 0.16)
    elif tone == "bright":
        rgb = ImageEnhance.Brightness(rgb).enhance(1.18)
        rgb = ImageEnhance.Color(rgb).enhance(1.2)
    elif tone == "dark":  # 큰 변형 바탕: 흐리고 어둡게 해서 위에 얹은 이펙트가 돋보이게
        rgb = rgb.filter(ImageFilter.GaussianBlur(2.5))
        rgb = ImageEnhance.Brightness(rgb).enhance(0.5)
    elif tone == "gray":
        rgb = ImageEnhance.Color(rgb).enhance(0.15)
        rgb = Image.blend(rgb, Image.new("RGB", rgb.size, (90, 140, 200)), 0.25)
        rgb = ImageEnhance.Brightness(rgb).enhance(0.75)
    rgb.putalpha(a)
    return rgb


def _hero_bg(hero: str) -> Image.Image:
    """영웅 바탕: 영웅 기술 그림을 크게 흐리고 어둡게 (색감만 남긴다)."""
    bg = _icon(HEROES[hero]["bg"]).crop((INSET, INSET, WORK - INSET, WORK - INSET)).resize((WORK, WORK))
    bg = bg.filter(ImageFilter.GaussianBlur(14))
    bg = ImageEnhance.Brightness(bg).enhance(0.55)
    glow = Image.new("L", (WORK, WORK), 0)
    ImageDraw.Draw(glow).ellipse([WORK * 0.15, WORK * 0.15, WORK * 0.85, WORK * 0.85], fill=90)
    glow = glow.filter(ImageFilter.GaussianBlur(30))
    return Image.composite(Image.new("RGBA", bg.size, (255, 236, 200, 255)), bg, glow)


def _hero_bust(hero: str) -> Image.Image:
    """지금 모델과 같은 얼굴의 상반신 (새 원화, make_portraits.portrait를 넓게)."""
    bust = portrait(hero, BUST_SCALE, BUST_DROP, int(WORK * 0.92))
    out = _hero_bg(hero)
    shadow = Image.new("RGBA", bust.size, (0, 0, 0, 0))
    shadow.putalpha(bust.getchannel("A").filter(ImageFilter.GaussianBlur(6)).point(lambda v: v * 0.7))
    o = ((WORK - bust.width) // 2, WORK - bust.height + 6)
    out.alpha_composite(shadow, (o[0] + 4, o[1] + 4))
    out.alpha_composite(bust, o)
    return out


def _overlay(img: Image.Image, over) -> Image.Image:
    for name, scale, x, y, rot, alpha in over:
        v = _load(f"assets/vfx/{name}.png")
        w = int(WORK * scale)
        v = v.resize((w, max(1, int(v.height * w / v.width))), Image.LANCZOS)
        if rot:
            v = v.rotate(-rot, expand=True, resample=Image.BICUBIC)
        if alpha < 1.0:
            v.putalpha(v.getchannel("A").point(lambda p, a=alpha: int(p * a)))
        img.alpha_composite(v, (int(x * WORK - v.width / 2), int(y * WORK - v.height / 2)))
    return img


def _gpt_art(hero: str, uid: str):
    """GPT로 받은 그림이 있으면 (GPT_DIR/<영웅>/<id>.png) 가운데 정사각형으로 잘라 안쪽 그림으로 쓴다."""
    path = os.path.join(ROOT, GPT_DIR, hero, uid + ".png")
    if not os.path.exists(path):
        return None
    g = Image.open(path).convert("RGBA")
    side = min(g.size)
    g = g.crop(((g.width - side) // 2, (g.height - side) // 2, (g.width + side) // 2, (g.height + side) // 2))
    out = _hero_bg(hero)
    out.alpha_composite(g.resize((WORK, WORK), Image.LANCZOS))
    return out


def make_icon(hero: str, uid: str) -> Image.Image:
    sp = SPEC[(hero, uid)]
    gpt = _gpt_art(hero, uid)
    if gpt is not None:  # spec의 gpt=True(임시 12개)가 아니어도 넣으면 바뀐다 — 기술 강화 그림을 따로 받을 때도 같은 길
        print(f"GPT 그림 사용: {hero}/{uid}" + ("" if sp["gpt"] else " (기술 강화 그림 교체)"))
        art = gpt
        sp = dict(sp, tone=None, over=[])
    elif sp["base"].startswith("icon:"):
        art = _zoomed(_icon(sp["base"][5:]), sp["zoom"], sp["focus"])
    elif sp["base"] == "hero":
        art = _hero_bust(hero)
    else:
        art = _hero_bg(hero)
    art = _overlay(_tone(art, sp["tone"]), sp["over"])
    frame = _icon(sp["base"][5:] if sp["base"].startswith("icon:") else HEROES[hero]["frame"])
    out = frame.copy()
    out.paste(art, (0, 0), _inner_mask())
    out = ink_icons.ink(out, ink_icons.LEVELS[ink_icons.APPLIED], ink_icons.HEROES[hero][0])  # 수묵 (효과 표시 얹기 전)
    if sp["badge"] == "major":  # 큰 변형: 안쪽 금빛 테
        ring = Image.new("RGBA", (WORK, WORK), (0, 0, 0, 0))
        ImageDraw.Draw(ring).rounded_rectangle([INSET + 3, INSET + 3, WORK - INSET - 4, WORK - INSET - 4], RADIUS - 3,
                                               outline=(255, 214, 110, 220), width=4)
        out.alpha_composite(ring.filter(ImageFilter.GaussianBlur(1.2)))
    b = badge(sp["badge"], int(WORK * BADGE))
    out.alpha_composite(b, (WORK - b.width - 4, WORK - b.height - 4))
    return out.resize((SIZE, SIZE), Image.LANCZOS)


def icon_path(hero: str, uid: str) -> str:
    return f"{OUT_DIR}/{hero}/{uid}.png"


def _upgrade_blocks(text: str):
    """.tres를 sub_resource 덩어리로 나누고, UpgradeDef(upgrade_def.gd) 덩어리 번호와 id를 돌려준다."""
    m = re.search(r'^\[ext_resource type="Script" path="res://scripts/run/upgrade_def.gd" id="([^"]+)"\]', text, re.M)
    if not m:
        raise ValueError("upgrade_def.gd 스크립트 연결이 없다")
    script = f'script = ExtResource("{m.group(1)}")'
    blocks = re.split(r'(?=^\[sub_resource )', text, flags=re.M)
    found = []
    for i, blk in enumerate(blocks):
        if script in blk:
            uid = re.search(r'^id = &"([^"]+)"', blk, re.M)
            if not uid:
                raise ValueError(f"강화 덩어리 {i}에 id가 없다")
            found.append((i, uid.group(1)))
    return blocks, found


def upgrade_ids(pool_rel: str) -> list:
    with open(os.path.join(ROOT, pool_rel), encoding="utf-8") as f:
        return [u for _, u in _upgrade_blocks(f.read())[1]]


def relink(pool_rel: str, hero: str) -> None:
    """풀 .tres의 강화마다 icon을 새 그림으로 바꾸고, 안 쓰는 옛 Texture 연결은 지운다.
    UpgradeDef 덩어리만 건드린다. 예상과 다른 모양이면 고치지 않고 멈춘다 (파일을 망가뜨리지 않게)."""
    path = os.path.join(ROOT, pool_rel)
    with open(path, encoding="utf-8") as f:
        text = f.read()
    text = re.sub(r'^\[ext_resource type="Texture2D"[^\n]*\n', "", text, flags=re.M)
    blocks, found = _upgrade_blocks(text)
    head = "".join(f'[ext_resource type="Texture2D" path="res://{icon_path(hero, u)}" id="icon_{u}"]\n' for _, u in found)
    first = blocks[0]
    last_script = list(re.finditer(r'^\[ext_resource type="Script"[^\n]*\n', first, re.M))
    if not last_script:
        raise ValueError(f"{pool_rel}: 스크립트 연결 줄이 없다")
    cut = last_script[-1].end()
    blocks[0] = first[:cut] + head + first[cut:]
    for i, uid in found:
        blk = re.sub(r'^icon = [^\n]*\n', "", blocks[i], flags=re.M)
        anchor = re.search(r'^color = ', blk, re.M) or re.search(r'^max_stacks = ', blk, re.M)
        if not anchor:
            raise ValueError(f"{pool_rel} / {uid}: icon을 넣을 자리(color·max_stacks)가 없다")
        blocks[i] = blk[:anchor.start()] + f'icon = ExtResource("icon_{uid}")\n' + blk[anchor.start():]
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("".join(blocks))


def pools():
    for hero in HEROES:
        for suffix in ("", "_major"):
            yield f"data/upgrades/{hero}{suffix}.tres", hero


def main() -> None:
    made = 0
    for pool, hero in pools():
        ids = upgrade_ids(pool)
        os.makedirs(os.path.join(ROOT, OUT_DIR, hero), exist_ok=True)
        for uid in ids:
            make_icon(hero, uid).save(os.path.join(ROOT, icon_path(hero, uid)), optimize=True)
            made += 1
        relink(pool, hero)
    print(f"{made} icons")
    if "--sheet" in sys.argv:
        sheet(sys.argv[sys.argv.index("--sheet") + 1])


def sheet(out: str) -> None:
    rows = []
    for pool, hero in pools():
        rows.append([icon_path(hero, u) for u in upgrade_ids(pool)])
    cols = max(len(r) for r in rows)
    s = 128
    img = Image.new("RGB", (cols * s, len(rows) * s), (40, 30, 30))
    for y, r in enumerate(rows):
        for x, p in enumerate(r):
            ic = _load(p).resize((s, s), Image.LANCZOS)
            img.paste(ic, (x * s, y * s), ic)
    img.save(out)


if __name__ == "__main__":
    main()
