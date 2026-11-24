"""전투 화면의 단순 도형(체력 막대·충전 원·화살·예고)을 먹·붓 결로 바꾸는 작은 그림들을 절차적으로 굽는다 (외부 이미지 없음).

  python tools/art/bake_ink_ui.py
만드는 것 (assets/vfx/, 흰색 그림은 코드에서 색을 입힌다):
  ink_bar_back.png  512x64  옅은 먹 획 바탕 (시작이 굵고 끝이 가는 붓 획, 갈필 가장자리, 먹색 그대로)
  ink_bar_fill.png  512x64  차는 붓 획 (흰 바탕, 끝으로 갈수록 마른 붓결·튄 방울; 찬 만큼 가로로 늘여 써도 한 획)
  ink_arrow.png     192x48  적 화살 (쇠 화살촉·미늘, 나무 대, 양쪽 깃털, 먹 꼬리)
  ink_tail.png      128x32  탄 뒤 먹 꼬리 획 (흰 바탕)
  ink_edge.png      512x32  예고 줄 가장자리 거친 붓 획 (흰 바탕)
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
    """-1~1 값 잡음 (옥타브마다 무작위 매듭을 부드럽게 이음): 사인 합처럼 되풀이되는 톱니가 생기지 않는다."""
    x = np.linspace(0.0, 1.0, n)
    out = np.zeros(n)
    amp = 1.0
    for o in range(octaves):
        k = int(base * 2 ** o) + 2
        knots = rng.uniform(-1, 1, k)
        pos = x * (k - 1)
        i = np.minimum(pos.astype(int), k - 2)
        f = pos - i
        f = f * f * (3 - 2 * f)
        out += amp * (knots[i] * (1 - f) + knots[i + 1] * f)
        amp *= 0.55
    return out / max(np.abs(out).max(), 1e-6)


def smooth(d: np.ndarray, soft: float) -> np.ndarray:
    return np.clip(d / soft + 0.5, 0.0, 1.0)


def save(a: np.ndarray, name: str) -> None:
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name), optimize=True)


def stroke_bar(w: int, h: int, start: float, end: float, dry: float, edge: float, color, lit: bool,
               drops: bool) -> np.ndarray:
    """붓 획: 왼쪽 시작이 둥글고 굵고 오른쪽 끝으로 가늘게 빠진다. 가장자리는 갈필처럼 거칠고,
    끝으로 갈수록 먹이 마른다 (알파에 가로 결과 빈틈). 늘여 써도 같은 획 모양이 남게 가로 전체가 한 획이다."""
    xs = np.arange(w)
    t = xs / (w - 1)
    prof = start + (end - start) * t ** 0.8  # 반두께(높이 비율)
    cap = np.clip(t / 0.035, 0, 1) ** 0.5  # 시작 끝은 둥글게
    tip = np.clip((1.0 - t) / 0.03, 0, 1) ** 0.6  # 끝은 짧게 빠진다 (너무 길게 뾰족하면 칼날로 보인다)
    half = h * 0.5 * prof * cap * tip
    cy = h / 2 + 0.9 * noise1(w, 2, 1.5)
    rough_top = 1.0 + edge * noise1(w, 6, 22.0)
    rough_bot = 1.0 + edge * noise1(w, 6, 25.0)
    ys = np.arange(h)[:, None]
    top = cy - half * rough_top
    bot = cy + half * rough_bot
    cover = smooth(np.minimum(ys - top[None, :], bot[None, :] - ys), 1.3)
    # 갈필: 가로로 긴 결, 끝(t 큼)일수록 더 비어 있다
    row = np.clip(rng.uniform(0, 1, (h, 1)) * 1.4 - 0.2, 0, 1)
    grain = noise1(w, 6, 14.0)[None, :] * 0.5 + 0.5
    gap = np.clip(row * (0.3 + 1.2 * t[None, :] ** 1.3) * dry + (1 - grain) * 0.18 * dry, 0, 0.95)
    a = cover * (1.0 - gap)
    rgb = np.ones((h, w, 3)) * color
    if lit:
        shade = 1.0 - 0.30 * np.clip((ys - top[None, :]) / np.maximum(bot - top, 1)[None, :], 0, 1)
        rgb = rgb * shade[..., None]
    img = np.dstack([rgb, a])
    if drops:  # 끝 너머로 튄 먹 방울 몇 개
        for _ in range(5):
            dx = int(w * rng.uniform(0.9, 0.995))
            dy = int(h * rng.uniform(0.3, 0.7))
            r = rng.uniform(1.2, 2.6)
            yy, xx = np.mgrid[0:h, 0:w]
            img[..., 3] = np.maximum(img[..., 3], smooth(r - np.hypot(xx - dx, yy - dy), 1.0))
    return img


def make_bar() -> None:
    save(stroke_bar(512, 64, 0.92, 0.72, 0.5, 0.10, np.array([0.09, 0.09, 0.11]), False, False), "ink_bar_back.png")
    save(stroke_bar(512, 64, 0.80, 0.58, 0.7, 0.14, np.array([1.0, 1.0, 1.0]), True, True), "ink_bar_fill.png")


def make_arrow() -> None:
    """화살 그림: 쇠 화살촉(양쪽 미늘)·나무 대·양쪽 깃털·시위 자리 + 뒤로 짧은 먹 꼬리. 4배로 그려 줄인다."""
    from PIL import ImageDraw
    S = 4
    W, H = 192, 48
    im = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cy = H * S // 2

    def P(x, y):
        return (x * S, cy + y * S)

    # 먹 꼬리: 뒤(왼쪽)로 가늘고 옅게 흩어지는 획 + 방울
    d.polygon([P(0, 0.2), P(36, -3.2), P(70, -1.4), P(70, 1.4), P(36, 3.6)], fill=(24, 22, 28, 150))
    for x, y, r in ((8, -3.5, 1.4), (20, 4.5, 1.2), (4, 2.5, 1.0)):
        d.ellipse([P(x - r, y - r), P(x + r, y + r)], fill=(24, 22, 28, 170))
    # 대: 나무색 + 윗결
    d.polygon([P(36, -2.0), P(150, -1.8), P(150, 2.0), P(36, 2.2)], fill=(122, 84, 48, 255))
    d.polygon([P(36, -2.0), P(150, -1.8), P(150, -0.4), P(36, -0.6)], fill=(176, 128, 78, 255))
    # 깃털: 양쪽 두 쌍, 뒤로 젖힌 붉은 깃 + 흰 끝
    for k in range(2):
        x0 = 40 + k * 15
        for sg in (-1, 1):
            d.polygon([P(x0 + 4, 0), P(x0, sg * 9.0), P(x0 + 9, sg * 9.0), P(x0 + 14, 0)], fill=(188, 36, 28, 255))
            d.polygon([P(x0, sg * 9.0), P(x0 + 9, sg * 9.0), P(x0 + 8, sg * 6.4), P(x0 + 1.5, sg * 6.4)], fill=(240, 230, 214, 255))
    # 시위 자리
    d.rectangle([P(33, -3.0), P(37, 3.0)], fill=(60, 40, 24, 255))
    # 쇠 화살촉: 잎 모양 + 양쪽 미늘, 윗면이 밝은 쇠
    d.polygon([P(148, -2.6), P(160, -8.5), P(190, 0), P(160, 8.5), P(148, 2.6)], fill=(46, 48, 58, 255))
    d.polygon([P(148, -2.6), P(160, -8.5), P(190, 0), P(160, -0.8)], fill=(150, 156, 170, 255))
    d.polygon([P(148, -2.4), P(143, -6.5), P(152, -4.0)], fill=(46, 48, 58, 255))
    d.polygon([P(148, 2.4), P(143, 6.5), P(152, 4.0)], fill=(46, 48, 58, 255))
    im = im.resize((W, H), Image.LANCZOS)
    im.save(os.path.join(OUT, "ink_arrow.png"), optimize=True)


def make_tail() -> None:
    """먹 꼬리 획 (흰 바탕, 색을 입혀 쓴다): 왼쪽(탄 쪽)이 굵고 둥글고 오른쪽으로 가늘게 빠진다."""
    w, h = 128, 32
    img = stroke_bar(w, h, 0.05, 0.9, 0.5, 0.18, np.array([1.0, 1.0, 1.0]), False, False)
    save(img, "ink_tail.png")


def make_edge() -> None:
    """예고 줄 가장자리용 거친 붓 획 (흰 바탕, 가로로 길게 늘여 쓴다)."""
    img = stroke_bar(512, 32, 0.9, 0.9, 0.9, 0.30, np.array([1.0, 1.0, 1.0]), False, False)
    save(img, "ink_edge.png")


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
    """먹 번짐 판: 가운데가 옅고 가장자리로 짙어지며, 얼룩이 크게 진다 (가로로 늘여 써도 번짐 무늬가 보이게)."""
    w, h = 256, 64
    yy, xx = np.mgrid[0:h, 0:w]
    ex = np.minimum(xx, w - 1 - xx).astype(float)
    ey = np.minimum(yy, h - 1 - yy).astype(float)
    jit = 2.0 + 1.6 * noise1(w, 4, 5.0)[None, :] + 1.2 * noise1(h, 3, 3.0)[:, None]
    d = np.minimum(ex, ey) - jit
    n1 = noise2(256, 3.0)[:h, :w]
    n2 = noise2(256, 9.0)[:h, :w]
    edge_dark = 1.0 - np.clip(np.minimum(ey / (h * 0.5), 1.0), 0, 1)  # 위아래 가장자리일수록 1
    mott = 0.55 + 0.30 * (n1 * 0.5 + 0.5) + 0.25 * (n2 * 0.5 + 0.5) + 0.35 * edge_dark
    save(np.dstack([np.ones((h, w, 3)), smooth(d, 3.0) * np.clip(mott, 0, 1)]), "ink_wash_rect.png")


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
    make_tail()
    make_edge()
    make_wash()
    make_wash_rect()
    make_ring()
    print("구움: assets/vfx/ink_*.png")
