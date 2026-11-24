"""전투 화면의 단순 도형(체력 막대·충전 원·화살·예고)을 먹·붓 결로 바꾸는 작은 그림들을 절차적으로 굽는다 (외부 이미지 없음).

  python tools/art/bake_ink_ui.py
만드는 것 (assets/vfx/, 흰색 그림은 코드에서 색을 입힌다):
  ink_bar_back.png  256x32  먹선 바탕 (양 끝이 가늘고 가장자리가 붓처럼 흔들림, 먹색 그대로)
  ink_bar_fill.png  256x32  획으로 차는 막대 (흰 바탕, 마른 붓결)
  ink_arrow.png     128x32  적 화살 (나무 대, 먹 촉, 붉은 깃, 먹 꼬리)
  ink_wash.png      128x128 먹 번짐 원판 (흰 바탕, 얼룩, 반지름 1 안에 있음)
  ink_wash_rect.png 256x64  먹 번짐 판 (흰 바탕, 모서리 안쪽으로만 흔들림)
  ink_ring.png      256x256 붓으로 그은 고리 (흰 바탕, 바깥 가장자리가 반지름 1, 굵기가 오르내림)
같은 씨앗이라 다시 구워도 같다.
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets/vfx")
rng = np.random.default_rng(20261124)


def noise1(n: int, octaves: int = 4, base: float = 3.0) -> np.ndarray:
    """0 둘레 -1~1 부드러운 1차원 잡음."""
    x = np.linspace(0.0, 1.0, n)
    out = np.zeros(n)
    amp = 1.0
    for o in range(octaves):
        out += amp * np.sin(2 * np.pi * (base * 2 ** o) * x + rng.uniform(0, 2 * np.pi))
        amp *= 0.5
    return out / max(np.abs(out).max(), 1e-6)


def smooth(d: np.ndarray, soft: float) -> np.ndarray:
    return np.clip(d / soft + 0.5, 0.0, 1.0)


def save(a: np.ndarray, name: str) -> None:
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name), optimize=True)


def bar(w: int, h: int, half_frac: float, color: np.ndarray, dry: float, lit: bool) -> np.ndarray:
    """가로 막대 획: 위아래 가장자리를 흔들고 양 끝을 가늘게, 마른 붓결을 알파에 건다."""
    xs = np.arange(w)
    t = xs / (w - 1)
    cy = h / 2 + 0.8 * noise1(w, 2, 1.5)
    half = h * half_frac * (0.5 + 0.045 * noise1(w, 3, 2.5))
    taper = np.minimum(1.0, np.minimum(t, 1.0 - t) / 0.09) ** 0.5  # 양 끝 가늘어지는 자리는 InkPaint가 늘이지 않고 그대로 붙인다 (캡 28칸 안)
    ys = np.arange(h)[:, None]
    top = cy - half * taper
    bot = cy + half * taper
    cover = smooth(np.minimum(ys - top[None, :], bot[None, :] - ys), 1.6)
    streak = 1.0 - dry * np.clip(noise1(w, 5, 9.0)[None, :] * 0.5 + rng.uniform(0, 1, (h, 1)) * 0.6 - 0.15, 0, 1)
    a = cover * streak
    rgb = np.ones((h, w, 3)) * color
    if lit:  # 위쪽이 밝고 아래가 어두운 획 (붓에 먹이 모인 느낌)
        shade = 1.0 - 0.28 * np.clip((ys - top[None, :]) / np.maximum(bot - top, 1)[None, :], 0, 1)
        rgb = rgb * shade[..., None]
    return np.dstack([rgb, a])


def make_bar() -> None:
    save(bar(256, 32, 0.98, np.array([0.09, 0.09, 0.11]), 0.10, False), "ink_bar_back.png")
    save(bar(256, 32, 0.78, np.array([1.0, 1.0, 1.0]), 0.22, True), "ink_bar_fill.png")


def make_arrow() -> None:
    w, h = 128, 32
    img = np.zeros((h, w, 4))
    ys = np.arange(h)[:, None]
    xs = np.arange(w)[None, :]
    wob = 0.6 * noise1(w, 3, 2.0)[None, :]
    # 먹 꼬리: 뒤(왼쪽)로 갈수록 옅고 가는 먹 줄
    tail = np.clip((xs - 0.0) / 60.0, 0, 1) * (np.abs(ys - 16 - wob) < (1.0 + 2.2 * np.clip(xs / 60.0, 0, 1))) * (xs < 70)
    img[..., 3] = np.maximum(img[..., 3], 0.35 * tail)
    img[..., :3] = np.where(tail[..., None] > 0, np.array([0.09, 0.09, 0.11]), img[..., :3])
    # 대: 갈색
    shaft = (xs >= 18) & (xs <= 108) & (np.abs(ys - 16 - wob) < 2.6)
    img[shaft] = [0.42, 0.28, 0.16, 1.0]
    # 깃: 붉은 두 획
    for sign in (-1, 1):
        for k in range(3):
            x0 = 14 + k * 6
            line = (np.abs((ys - 16) - sign * (xs - x0 + 2) * 0.6) < 2.2) & (xs >= x0 - 2) & (xs <= x0 + 9)
            img[line] = [0.72, 0.13, 0.10, 1.0]
    # 촉: 먹 마름모
    head = (xs >= 100) & (xs <= 126) & (np.abs(ys - 16) < (126 - xs) * 0.52)
    img[head] = [0.07, 0.07, 0.09, 1.0]
    save(img, "ink_arrow.png")


def make_wash() -> None:
    n = 128
    yy, xx = np.mgrid[0:n, 0:n]
    cx = cy = (n - 1) / 2
    r = np.hypot(xx - cx, yy - cy) / (n / 2)
    ang = np.arctan2(yy - cy, xx - cx)
    edge = 0.90 + 0.06 * np.sin(ang * 3 + 1.1) + 0.03 * np.sin(ang * 7 + 0.4) + 0.015 * np.sin(ang * 13)
    mott = 0.80 + 0.20 * np.clip(noise2(n, 6.0) * 0.5 + 0.5, 0, 1)
    a = smooth(edge - r, 0.10) * mott
    save(np.dstack([np.ones((n, n, 3)), a]), "ink_wash.png")


def noise2(n: int, freq: float) -> np.ndarray:
    yy, xx = np.mgrid[0:n, 0:n] / n
    out = np.zeros((n, n))
    amp = 1.0
    for o in range(4):
        out += amp * np.sin(2 * np.pi * (freq * 2 ** o * xx + rng.uniform(0, 1))) * np.sin(2 * np.pi * (freq * 2 ** o * yy + rng.uniform(0, 1)))
        amp *= 0.5
    return out / max(np.abs(out).max(), 1e-6)


def make_wash_rect() -> None:
    w, h = 256, 64
    yy, xx = np.mgrid[0:h, 0:w]
    ex = np.minimum(xx, w - 1 - xx).astype(float)
    ey = np.minimum(yy, h - 1 - yy).astype(float)
    jit = 2.0 + 1.6 * noise1(w, 4, 5.0)[None, :] + 1.2 * noise1(h, 3, 3.0)[:, None]
    d = np.minimum(ex, ey) - jit
    mott = 0.82 + 0.18 * np.clip(noise2(256, 5.0)[:h, :w] * 0.5 + 0.5, 0, 1)
    save(np.dstack([np.ones((h, w, 3)), smooth(d, 3.0) * mott]), "ink_wash_rect.png")


def make_ring() -> None:
    n = 256
    yy, xx = np.mgrid[0:n, 0:n]
    cx = cy = (n - 1) / 2
    r = np.hypot(xx - cx, yy - cy) / (n / 2)
    ang = np.arctan2(yy - cy, xx - cx)
    outer = 0.985 - 0.012 * (0.5 + 0.5 * np.sin(ang * 5 + 0.7))
    thick = 0.075 + 0.045 * np.sin(ang + 0.6) + 0.02 * np.sin(ang * 4 + 2.1)  # 시작은 굵고 끝은 가늘다
    inner = outer - thick
    a = smooth(outer - r, 0.012) * smooth(r - inner, 0.012)
    dry = 1.0 - 0.45 * np.clip(noise2(n, 9.0), 0, 1) * (0.5 + 0.5 * np.sin(ang + 0.6))
    save(np.dstack([np.ones((n, n, 3)), a * dry]), "ink_ring.png")


if __name__ == "__main__":
    make_bar()
    make_arrow()
    make_wash()
    make_wash_rect()
    make_ring()
    print("구움: assets/vfx/ink_*.png")
