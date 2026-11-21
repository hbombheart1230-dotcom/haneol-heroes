"""사임당 색 고치기 (사용자 의견 2026-11-21: "보라가 너무 유치하다, 뒤(치마)는 흰색, 나머지는 분홍에 가깝게").

  python tools/art/recolor_saimdang.py
구운 스프라이트(assets/sprites/shin_saimdang/*.png)와 영웅 카드(assets/ui/heroes/shin_saimdang.png)를 고친다.
진한 보라(치마 겉) → 미색, 옅은 보라·분홍(저고리 등) → 은은한 분홍. 명암은 남긴다.
다시 굽거나(meshy_pipeline) 카드를 다시 만들면(make_hero_cards.py) 그 뒤에 이것을 다시 돌린다.
이미 고친 파일은 지문(recolor_saimdang.done.json)으로 알아보고 건너뛴다.
"""
import glob
import hashlib
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

def soften(img, deep_s=0.30, white=(0.70, 0.30), pink_hue=345.0, pink_cap=0.33):
    """보라·분홍 계열(240~355도): 진한 보라(채도 > deep_s, 치마 겉) → 미색, 옅은 보라·분홍 → 은은한 분홍. 명암은 남긴다."""
    rgba = img.convert("RGBA")
    a = np.asarray(rgba).astype(np.float32) / 255.0
    hsv = np.asarray(rgba.convert("RGB").convert("HSV")).astype(np.float32)
    h = hsv[..., 0] * 360 / 255; s = hsv[..., 1] / 255; v = hsv[..., 2] / 255
    band = (h >= 240) & (h <= 355) & (s > 0.04) & (np.abs(h - pink_hue) > 3.0)  # 이미 고친 분홍은 건너뜀 (두 번 돌려도 그대로)
    purple = (h < 320)
    deep = np.clip((s - deep_s) / 0.12, 0, 1) * purple  # 0 옅음 ~ 1 진함
    # 미색 목표
    wh_h, wh_s, wh_v = 40.0, s * 0.07, white[0] + white[1] * v
    # 분홍 목표
    pk_h, pk_s, pk_v = pink_hue, np.minimum(s, pink_cap), v  # 채도만 눌러 은은하게 (명암 그대로)
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


## 고친 결과의 지문(sha256). 지문이 같은 파일은 이미 고친 것이라 건너뛴다 (두 번 돌려도 그대로).
## 다시 구워 파일이 바뀌면 지문이 달라져 다시 고친다.
DONE_FILE = os.path.join(ROOT, "tools/art/recolor_saimdang.done.json")


def sha(path: str) -> str:
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def main() -> None:
    files = sorted(glob.glob(os.path.join(ROOT, "assets/sprites/shin_saimdang/*.png")))
    files.append(os.path.join(ROOT, "assets/ui/heroes/shin_saimdang.png"))
    done = json.load(open(DONE_FILE, encoding="utf-8")) if os.path.exists(DONE_FILE) else {}
    for f in files:
        key = os.path.relpath(f, ROOT).replace("\\", "/")
        if done.get(key) == sha(f):
            print(key, "이미 고침")
            continue
        soften(Image.open(f)).save(f, optimize=True)
        done[key] = sha(f)
        print(key)
    with open(DONE_FILE, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(done, fh, indent=1, sort_keys=True)
        fh.write("\n")


if __name__ == "__main__":
    main()
