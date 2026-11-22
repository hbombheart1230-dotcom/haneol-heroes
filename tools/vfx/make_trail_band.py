"""검기 궤적 띠 그림 (assets/vfx/trail_band.png) 만들기: 무채색, 기술 색을 곱해 쓴다 (SwingTrail).

가로(u) = 띠 길이 방향, 세로(v) = 0 바깥 가장자리(칼끝, 진하고 날카롭게) → 1 안쪽(붓이 마르며 갈라짐).
마른 붓 자국: 가로로 긴 결 잡음을 깎아 안쪽으로 갈수록 끊긴다. 씨앗 고정 → 같은 그림.
python tools/vfx/make_trail_band.py [출력 경로]
"""
import sys

import numpy as np
from PIL import Image

W, H = 256, 64


def band(seed=7):
    rng = np.random.default_rng(seed)
    v = np.linspace(0.0, 1.0, H)[:, None]
    # 결: 세로로는 거칠고 가로로는 길게 이어지는 잡음 (가로로 흐리게)
    grain = rng.random((H, W // 16 + 2))
    grain = np.array([np.interp(np.linspace(0, grain.shape[1] - 1, W), np.arange(grain.shape[1]), row)
                      for row in grain])
    # 바깥 가장자리는 진하게, 안쪽으로 갈수록 결이 남는 곳만
    edge = np.clip(1.0 - v / 0.12, 0.0, 1.0) ** 0.5
    dry = np.clip((grain - v * 1.05) * 5.0 + 0.2, 0.0, 1.0)
    body = np.clip(1.0 - v, 0.0, 1.0) ** 1.4  # 획의 몸 (안쪽으로 옅어짐)
    alpha = np.clip(np.maximum(edge, body * (0.55 + 0.45 * dry)), 0.0, 1.0)
    # 밝기: 바깥 가장자리 흰빛, 안쪽은 조금 어둡게 (색을 곱하면 영웅색이 살아난다)
    lum = 0.75 + 0.25 * np.clip(1.0 - v / 0.25, 0.0, 1.0)
    lum = np.broadcast_to(lum, (H, W))
    rgba = np.dstack([lum, lum, lum, alpha])
    return (rgba * 255).round().astype(np.uint8)


def main(out="assets/vfx/trail_band.png"):
    Image.fromarray(band(), "RGBA").save(out)


if __name__ == "__main__":
    main(*sys.argv[1:])
