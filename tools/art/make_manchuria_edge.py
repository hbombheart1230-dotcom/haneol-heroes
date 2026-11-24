"""만주 벌판 가장자리 겹침 그림 (assets/textures/overlay/manchuria_edge.png) 만들기.

무용총 수렵도(고구려 5세기 벽화, 공공누리 1유형 — Wikimedia Commons Muyongchong Suryeopdo.jpg)에서 산 물결·사슴·말 탄 사냥꾼·호랑이의
검은 선·먹 덩어리만 뽑아, 무대 지도와 같은 월드 영역 위에 얹을 투명 그림 한 장으로 합성한다. 가운데 전투 구역은 비운다.
원본(2000폭 이상 사본)은 assets/concept/stage_edge_src/에 둔다.
python tools/art/make_manchuria_edge.py [원본 jpg] [출력 png]
"""
import os
import sys

import numpy as np
from PIL import Image

SRC = "assets/concept/stage_edge_src/Muyongchong_Suryeopdo_2000.jpg"
OUT = "assets/textures/overlay/manchuria_edge.png"
MAP = (-1068, -1711, 2124, 3186)  # StageTheme.background_rect와 같게
HALF = 2.0
LINE = (232, 205, 150)            # 먹선을 저녁 벌판 위에서 옅은 황토색으로
S = 1.92                          # 원본(3840폭)을 2000폭 기준 좌표로 쓴 박스에 맞춘다
BOXES = {                         # 2000폭 기준 (x0, y0, x1, y1)
    "wave": (350, 380, 1380, 790), "peak": (1470, 1030, 2000, 1345), "deer": (150, 130, 1100, 500),
    "rider": (70, 720, 1000, 1320), "tiger": (1000, 880, 1520, 1180), "archer": (1100, 1280, 1700, 1515),
}


def ink(src, key, lo=35, hi=100):
    box = tuple(int(v * S) for v in BOXES[key])
    c = np.asarray(src.convert("L").crop(box)).astype(float)
    a = 1.0 - np.clip((c - lo) / (hi - lo), 0.0, 1.0)
    h, w = a.shape  # 상자 가장자리는 부드럽게 (벽 얼룩이 사각형으로 끊기지 않게)
    ey = np.clip(np.minimum(np.arange(h), h - 1 - np.arange(h)) / (h * 0.12), 0, 1)
    ex = np.clip(np.minimum(np.arange(w), w - 1 - np.arange(w)) / (w * 0.12), 0, 1)
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
    src = Image.open(src_path)
    m = {k: ink(src, k) for k in BOXES}
    canvas = np.zeros((int(MAP[3] / HALF), int(MAP[2] / HALF)), dtype=float)
    # 위 끝: 산 물결 + 달리는 사슴 / 아래 끝: 말 탄 사냥꾼 + 호랑이 + 먼 산 (가운데 전투 구역은 비움)
    place(canvas, m["wave"], -380, -1180, 800, 0.5, fade="up")
    place(canvas, m["peak"], 480, -1170, 560, 0.5, fade="up")
    place(canvas, m["deer"], 120, -1330, 760, 0.5)
    place(canvas, m["rider"], -340, 1220, 760, 0.5, fade="down")
    place(canvas, m["tiger"], 400, 1270, 520, 0.5, fade="down")
    place(canvas, m["archer"], -820, 1100, 420, 0.30, fade="down")
    place(canvas, m["peak"], -760, -960, 380, 0.3, flip=True, fade="up")
    rgba = np.zeros(canvas.shape + (4,), dtype=np.uint8)
    rgba[..., 0], rgba[..., 1], rgba[..., 2] = LINE
    rgba[..., 3] = (np.clip(canvas, 0, 1) * 255).astype(np.uint8)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(out)
    print("saved", out, rgba.shape)


if __name__ == "__main__":
    main(*sys.argv[1:])
