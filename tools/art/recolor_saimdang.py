"""사임당 색 고치기 (사용자 의견 2026-11-21: "보라가 너무 유치하다, 뒤(치마)는 흰색, 나머지는 분홍에 가깝게").

  python tools/art/recolor_saimdang.py
구운 스프라이트(assets/sprites/shin_saimdang/*.png)와 영웅 카드(assets/ui/heroes/shin_saimdang.png)를 고친다.
진한 보라(치마 겉) → 미색, 옅은 보라·분홍(저고리 등) → 은은한 분홍. 명암은 남긴다.
다시 굽거나(meshy_pipeline) 카드를 다시 만들면(make_hero_cards.py) 그 뒤에 이것을 다시 돌린다.
"""
import glob
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

def soften(img, deep_s=0.30, white=(0.70, 0.30), pink_hue=345.0, pink_s=0.55):
    """보라·분홍 계열(240~355도): 진한 보라(채도 > deep_s, 치마 겉) → 미색, 옅은 보라·분홍 → 은은한 분홍. 명암은 남긴다."""
    rgba = img.convert("RGBA")
    a = np.asarray(rgba).astype(np.float32) / 255.0
    hsv = np.asarray(rgba.convert("RGB").convert("HSV")).astype(np.float32)
    h = hsv[..., 0] * 360 / 255; s = hsv[..., 1] / 255; v = hsv[..., 2] / 255
    band = (h >= 240) & (h <= 355) & (s > 0.04)
    purple = (h < 320)
    deep = np.clip((s - deep_s) / 0.12, 0, 1) * purple  # 0 옅음 ~ 1 진함
    # 미색 목표
    wh_h, wh_s, wh_v = 40.0, s * 0.07, white[0] + white[1] * v
    # 분홍 목표
    pk_h, pk_s, pk_v = pink_hue, np.minimum(s, 0.45) * pink_s / 0.45 * 0.6 + 0.05, np.clip(v * 1.02 + 0.04, 0, 1)
    def to_rgb(hh, ss, vv):
        hh = np.broadcast_to(hh, h.shape)
        im = Image.merge("HSV", [Image.fromarray(np.uint8(np.clip(x, 0, 1) * 255)) for x in (hh / 360, ss, vv)]).convert("RGB")
        return np.asarray(im).astype(np.float32) / 255
    w_rgb = to_rgb(wh_h, wh_s, wh_v)
    p_rgb = to_rgb(pk_h, pk_s, pk_v)
    tgt = p_rgb * (1 - deep[..., None]) + w_rgb * deep[..., None]
    w = np.clip((s - 0.04) / 0.08, 0, 1) * band
    res = a[..., :3] * (1 - w[..., None]) + tgt * w[..., None]
    return Image.fromarray(np.uint8(np.clip(np.dstack([res, a[..., 3:]]), 0, 1) * 255), "RGBA")


def main() -> None:
    files = glob.glob(os.path.join(ROOT, "assets/sprites/shin_saimdang/*.png"))
    files.append(os.path.join(ROOT, "assets/ui/heroes/shin_saimdang.png"))
    for f in files:
        soften(Image.open(f)).save(f, optimize=True)
        print(os.path.relpath(f, ROOT))


if __name__ == "__main__":
    main()
