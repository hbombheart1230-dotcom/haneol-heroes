"""경복궁 가장자리 겹침 그림 (assets/textures/overlay/gyeongbokgung_edge.png) 만들기.

북궐후원도형(규장각한국학연구원 소장 조선 말 도면, 퍼블릭 도메인 — Wikimedia Commons 북궐후원도형.jpg)의 연필 선에서
행각으로 둘러싼 건물 배치·궁성 담장 곡선만 뽑는다 (격자 종이는 번짐 제거로 날린다). 지도와 같은 월드 영역에 얹을 투명 그림 한 장.
가운데 전투 구역은 비운다. 원본 사본은 assets/concept/stage_edge_src/에 둔다.
python tools/art/make_gyeongbokgung_edge.py [원본 jpg] [출력 png]
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import grey_dilation, label

SRC = "assets/concept/stage_edge_src/Bukgwon_Huwondohyeong.jpg"
OUT = "assets/textures/overlay/gyeongbokgung_edge.png"
MAP = (-1310, -2248, 2630, 3946)  # StageTheme.background_rect와 같게
HALF = 2.0
LINE = (214, 214, 240)            # 먹선을 밤 궁궐 바닥 위에서 옅은 청백으로
K = 3.84                          # 1000폭 기준 좌표 -> 원본(3840폭)
BOXES = {                         # 1000폭 기준 (x0, y0, x1, y1)
    "court": (500, 510, 640, 620), "hall": (595, 685, 675, 815), "rows": (120, 560, 330, 640),
    "field": (128, 680, 205, 775), "wallL": (150, 30, 370, 560), "wallR": (735, 40, 845, 800),
}


def ink_all(path):
    im = Image.open(path).convert("L")
    bg = np.asarray(im.filter(ImageFilter.GaussianBlur(6))).astype(float)
    a = np.clip((bg - np.asarray(im).astype(float) - 25) / 30.0, 0.0, 1.0)
    lab, n = label(grey_dilation((a > 0.12).astype(np.uint8), size=(7, 7)), structure=np.ones((3, 3)))  # 격자 종이의 잔 부스러기(작은 덩어리)는 버린다
    size = np.bincount(lab.ravel())
    keep = size >= 1400
    keep[0] = False
    return a * keep[lab]


def crop(ink, key):
    x0, y0, x1, y1 = (int(v * K) for v in BOXES[key])
    a = grey_dilation(ink[y0:y1, x0:x1], size=(5, 5))  # 가는 연필선을 굵게 (작게 줄여도 남도록)
    h, w = a.shape
    ey = np.clip(np.minimum(np.arange(h), h - 1 - np.arange(h)) / (h * 0.08), 0, 1)
    ex = np.clip(np.minimum(np.arange(w), w - 1 - np.arange(w)) / (w * 0.08), 0, 1)
    return a * ey[:, None] * ex[None, :]


def place(canvas, motif, cx, cy, width_world, alpha, flip=False, fade=None):
    h, w = motif.shape
    tw = max(2, int(width_world / HALF))
    th = max(2, int(tw * h / w))
    m = np.asarray(Image.fromarray((motif * 255).astype(np.uint8)).resize((tw, th), Image.LANCZOS)).astype(float) / 255.0
    if flip:
        m = m[:, ::-1]
    if fade == "down":
        m = m * np.linspace(1.0, 0.0, th)[:, None]
    elif fade == "up":
        m = m * np.linspace(0.0, 1.0, th)[:, None]
    x0, y0 = int((cx - MAP[0]) / HALF - tw / 2), int((cy - MAP[1]) / HALF - th / 2)
    H, W = canvas.shape
    xs, ys, xe, ye = max(0, x0), max(0, y0), min(W, x0 + tw), min(H, y0 + th)
    if xe > xs and ye > ys:
        sub = m[ys - y0:ye - y0, xs - x0:xe - x0] * alpha
        canvas[ys:ye, xs:xe] = np.maximum(canvas[ys:ye, xs:xe], sub)


def main(src_path=SRC, out=OUT):
    ink = ink_all(src_path)
    m = {k: crop(ink, k) for k in BOXES}
    canvas = np.zeros((int(MAP[3] / HALF), int(MAP[2] / HALF)), dtype=float)
    # 놀이 마당은 x ±900, y ±1400. 위 끝: 행각 마당 / 아래 끝: 전각 터 + 궁성 담장 곡선이 양옆 가장자리를 따라
    place(canvas, m["court"], -420, -1270, 640, 0.95, fade="up")
    place(canvas, m["rows"], 430, -1250, 600, 0.9, flip=True, fade="up")
    place(canvas, m["hall"], -380, 1260, 420, 0.95, fade="down")
    place(canvas, m["field"], 470, 1250, 300, 0.85, fade="down")
    place(canvas, m["wallL"], -820, -330, 700, 0.8)
    place(canvas, m["wallR"], 830, 250, 560, 0.8, flip=True)
    rgba = np.zeros(canvas.shape + (4,), dtype=np.uint8)
    rgba[..., 0], rgba[..., 1], rgba[..., 2] = LINE
    rgba[..., 3] = (np.clip(canvas, 0, 1) * 255).astype(np.uint8)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(out)
    print("saved", out, rgba.shape)


if __name__ == "__main__":
    main(*sys.argv[1:])
