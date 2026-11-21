"""기술 색으로 물들여 쓰는 무채색 붓 그림 (코드로 그린 동그라미·선 대신).

  python tools/vfx/make_neutral.py
GPT 그림(물결 고리·먹 붓 획·물보라·먹 소용돌이·물칼)을 밝은 회색조로 바꿔 assets/vfx/brush_*.png.
FxLayer가 add_ring·add_slash·add_spark를 이 그림에 기술 색을 곱해 그린다.
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
V = os.path.join(ROOT, "assets/vfx")
SRC = {"brush_ring": "wave", "brush_stroke": "ink_strip", "brush_splat": "foam", "brush_pool": "ink",
       "brush_crescent": "proj_water"}


def neutral(name: str) -> Image.Image:
    a = np.asarray(Image.open(os.path.join(V, f"{name}.png")).convert("RGBA")).astype(np.float32) / 255.0
    lum = a[..., :3] @ np.array([0.3, 0.59, 0.11], np.float32)
    lum = (lum - lum.min()) / max(lum.max() - lum.min(), 1e-4)
    grey = 0.55 + 0.45 * lum  # 붓 결은 남기고 밝게 (색을 곱하면 그 색이 된다)
    return Image.fromarray((np.dstack([grey, grey, grey, a[..., 3]]) * 255).astype(np.uint8), "RGBA")


if __name__ == "__main__":
    for out, src in SRC.items():
        neutral(src).save(os.path.join(V, f"{out}.png"), optimize=True)
        print("ok", out)
