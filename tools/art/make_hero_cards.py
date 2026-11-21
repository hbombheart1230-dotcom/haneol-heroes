"""영웅 고르기 카드 그림 만들기: 새 디자인 원본(흰 바탕)에서 배경을 지우고 카드 크기로 줄인다.

  python tools/art/make_hero_cards.py [--ink] [--out <폴더>]
원본: assets/concept/redesign/heroes/<영웅>.png (1254x1254, 흰 바탕, GPT)
결과: assets/ui/heroes/<영웅>.png (가로 360, 투명 바탕) — --out을 주면 그 폴더에 (비교용)
--ink: 입장 그림(수묵)과 어울리게 색을 조금 빼고 한지 빛으로 바랜다.
- 배경은 가장자리에서 이어진 흰색 + 둘러싸인 큰 순백 구멍을 지운다 (그늘 있는 흰 천은 남는다).
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HEROES = ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]
WIDTH = 360
WHITE = 236  # 이보다 밝으면 배경 후보
PURE = 246  # 둘러싸인 구멍을 배경으로 볼 순백
HOLE_MIN = 700  # 이보다 큰 순백 구멍만 (px, 원본 크기). 동정(흰 깃)은 이보다 작다
HOLE_FILL = 0.25  # 구멍이 꽉 찬 덩어리여야 (칼날 반짝임처럼 가는 줄은 0.2 아래)
PAPER = np.array([0.96, 0.92, 0.84])


def cut_out(img: Image.Image) -> Image.Image:
    a = np.asarray(img.convert("RGB")).astype(np.int16)
    light = (a.min(axis=2) >= WHITE)
    lab, _ = ndimage.label(light)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    # 갓끈·망토 안쪽처럼 둘러싸인 큰 순백 영역도 배경 (옷의 흰 천은 그늘이 있어 순백이 아니다)
    pure = a.min(axis=2) >= PURE
    plab, n = ndimage.label(pure & ~bg)
    if n:
        big = []
        for i, sl in enumerate(ndimage.find_objects(plab)):
            m = plab[sl] == i + 1
            if m.sum() >= HOLE_MIN and m.mean() >= HOLE_FILL:
                big.append(i + 1)
        bg |= np.isin(plab, big)
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    m = Image.fromarray(alpha).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.0))
    out = img.convert("RGBA")
    out.putalpha(m)
    return out.crop(out.getbbox())


def ink_tone(img: Image.Image) -> Image.Image:
    rgb = img.convert("RGB")
    rgb = ImageEnhance.Color(rgb).enhance(0.72)
    x = np.asarray(rgb).astype(np.float32) / 255.0
    x = x * (0.82 + 0.18 * PAPER)  # 한지 빛으로 살짝 바램
    x = np.clip((x - 0.5) * 1.06 + 0.5, 0, 1)
    out = Image.fromarray((x * 255).astype(np.uint8)).convert("RGBA")
    out.putalpha(img.getchannel("A"))
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ink", action="store_true")
    ap.add_argument("--out", default=os.path.join(ROOT, "assets/ui/heroes"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    for h in HEROES:
        img = cut_out(Image.open(os.path.join(ROOT, f"assets/concept/redesign/heroes/{h}.png")))
        if a.ink:
            img = ink_tone(img)
        img = img.resize((WIDTH, round(img.height * WIDTH / img.width)), Image.LANCZOS)
        img.save(os.path.join(a.out, f"{h}.png"), optimize=True)
        print(h, img.size)


if __name__ == "__main__":
    main()
