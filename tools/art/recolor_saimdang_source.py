"""사임당 3D 원본 그림 색 바꾸기 (Meshy에 넣기 전): 보라 → 연분홍 저고리 + 미색 치마 + 진분홍 고름·띠.

  python tools/art/recolor_saimdang_source.py
입력: assets/concept/redesign/heroes/shin_saimdang_purple.png (GPT A자세, 큰 붓, 보라)
출력: assets/concept/redesign/heroes/shin_saimdang.png (tools/ai3d/heroes/shin_saimdang.json이 읽는다)
그림에서 먼저 바꾸면 3D 텍스처가 처음부터 이 색으로 나온다 (구운 뒤 recolor_saimdang.py를 돌릴 필요 없음).
영역은 이 그림의 자세에 맞춘 값이다 (허리 높이, 소매·고름 위치) — 다른 그림이면 아래 수치를 다시 잡는다.
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
D = os.path.join(ROOT, "assets/concept/redesign/heroes")
WAIST = 0.30        # 그림 높이 대비 허리 위치 (위 = 저고리)
DEEP_S = 0.66       # 이보다 채도가 높은 보라 = 고름·띠
SASH = (0.36, 0.62, 0.64)  # 고름·띠가 있는 영역: x 최소, x 최대, y 최대


def main() -> None:
    img = Image.open(os.path.join(D, "shin_saimdang_purple.png")).convert("RGB")
    a = np.asarray(img).astype(np.float32) / 255
    hsv = np.asarray(img.convert("HSV")).astype(np.float32)
    h = hsv[..., 0] * 360 / 255
    s = hsv[..., 1] / 255
    v = hsv[..., 2] / 255
    hh, ww = h.shape
    yy = np.arange(hh)[:, None] / hh * np.ones((1, ww))
    xx = np.arange(ww)[None, :] / ww * np.ones((hh, 1))
    band = (h >= 235) & (h <= 335) & (s > 0.08)
    upper = np.clip((WAIST - yy) / 0.02, 0, 1)
    spread = np.clip(yy - WAIST + 0.01, 0, 1) * 0.75  # 소매는 허리 아래 높이까지 비스듬히 내려온다
    sleeve = ((xx < 0.44 - spread) | (xx > 0.56 + spread)) & (yy < 0.44)
    upper = np.maximum(upper, sleeve.astype(np.float32))
    in_sash = (xx > SASH[0]) & (xx < SASH[1]) & (yy < SASH[2])
    deep = np.clip((s - DEEP_S) / 0.08, 0, 1) * (in_sash | (upper > 0.5))

    def rgb(hue: float, ss: np.ndarray, vv: np.ndarray) -> np.ndarray:
        chans = (np.full(h.shape, hue / 360.0), ss, vv)
        im = Image.merge("HSV", [Image.fromarray(np.uint8(np.clip(c, 0, 1) * 255)) for c in chans]).convert("RGB")
        return np.asarray(im).astype(np.float32) / 255

    pink = rgb(345.0, np.clip(s * 0.55, 0.14, 0.34), np.clip(v * 1.02 + 0.03, 0, 1))
    rose = rgb(345.0, np.clip(s * 0.62, 0.35, 0.55), v * 0.97)
    ivory = rgb(40.0, s * 0.08, 0.68 + 0.32 * v)
    d3 = deep[..., None]
    u3 = upper[..., None]
    target = (pink * (1 - d3) + rose * d3) * u3 + (ivory * (1 - d3) + rose * d3) * (1 - u3)
    w = (np.clip((s - 0.08) / 0.08, 0, 1) * band)[..., None]
    out = Image.fromarray(np.uint8(np.clip(a * (1 - w) + target * w, 0, 1) * 255))
    out.save(os.path.join(D, "shin_saimdang.png"))
    print("shin_saimdang.png", out.size)


if __name__ == "__main__":
    main()
