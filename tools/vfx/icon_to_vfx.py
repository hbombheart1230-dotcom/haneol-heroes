"""기술 아이콘 그림에서 이펙트 텍스처를 뽑는다 (밝은 붓 터치만 남기고 어두운 바탕·금테를 지운다).

  python tools/vfx/icon_to_vfx.py
결과: assets/vfx/<이름>.png (192px, 투명 배경). 아이콘을 바꾸면 다시 실행한다.
설정(KEYS)은 기술마다 남길 밝기 범위·채도 가중·가장자리 지우기 반지름.
"""
import os
from PIL import Image, ImageFilter
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets/ui/icons")
DST = os.path.join(ROOT, "assets/vfx")
SIZE = 192
## 결과 이름: (원본 아이콘, 밝기 하한, 밝기 상한, 채도 가중, 원형 가리개 반지름 비율)
## 사람이 그려진 아이콘(반격·해룡참·정음 등)은 효과 부분만 남도록 다른 아이콘에서 뽑는다.
## GPT 그림(docs/skill_vfx_prompts.md)을 받으면 같은 이름으로 덮어쓰고 이 도구는 다시 돌리지 않는다.
KEYS = {
    "wave": ("haeil", 0.62, 0.92, 0.25, 0.47),
    "quake": ("quake", 0.45, 0.85, 0.5, 0.46),
    "lightning": ("lightning", 0.55, 0.90, 0.3, 0.47),
    "meteor": ("meteor", 0.45, 0.85, 0.5, 0.46),
    "constellation": ("constellation", 0.45, 0.85, 0.2, 0.47),
    "sundial": ("sundial", 0.45, 0.85, 0.4, 0.46),
    "plum": ("plum", 0.50, 0.85, 0.7, 0.47),
    "ink": ("ink_bleed", 0.40, 0.80, 0.6, 0.46),
}


def extract(src: str, lo: float, hi: float, sat_w: float, mask_r: float) -> Image.Image:
    im = Image.open(os.path.join(SRC, f"{src}.png")).convert("RGBA")
    w, h = im.size
    inset = int(w * 0.09)  # 금테 잘라내기
    im = im.crop((inset, inset, w - inset, h - inset)).resize((SIZE, SIZE), Image.LANCZOS)
    a = np.asarray(im).astype(np.float32) / 255.0
    rgb = a[..., :3]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-5), 0)
    key = np.clip((mx + sat * sat_w * 0.5 - lo) / max(hi - lo, 1e-5), 0, 1)
    key = key * key * (3 - 2 * key)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    d = np.hypot(xx - SIZE / 2 + 0.5, yy - SIZE / 2 + 0.5) / SIZE
    radial = np.clip((mask_r - d) / 0.16, 0, 1)  # 가장자리를 넓게 흐려 동그란 스티커처럼 보이지 않게
    alpha = np.power(key, 0.55) * radial * a[..., 3]  # 붓 터치는 또렷하게 (흐릿한 반투명 줄이기)
    out = np.dstack([rgb, alpha])
    img = Image.fromarray((out * 255).astype(np.uint8), "RGBA")
    return img.filter(ImageFilter.SMOOTH)


if __name__ == "__main__":
    os.makedirs(DST, exist_ok=True)
    for n, (src, lo, hi, s, r) in KEYS.items():
        extract(src, lo, hi, s, r).save(os.path.join(DST, f"{n}.png"), optimize=True)
        print("ok", n)
