"""한산 갑판 가장자리 먹선 겹침 그림 (assets/textures/overlay/hansan_edge.png) 만들기.

『이충무공전서』 전라좌수영 귀선(1795, 일본 국립국회도서관, 퍼블릭 도메인; Wikimedia Commons Geobukseon2.jpg)의 목판 선화에서
귀갑문(육각 등딱지 무늬)·방패판 원 무늬 띠·용머리를 먹선만 뽑아, 무대 지도(배경 그림)와 같은 월드 영역 위에 얹을 투명 그림 한 장으로 합성한다.
전투 구역(가운데)은 비우고 갑판 가장자리(위·아래 끝, 모서리)에만, 중간 진하기로 둔다.
원본 인쇄물(1.8MB, 퍼블릭 도메인)은 assets/concept/gwiseon_src/에 둔다.
python tools/art/make_hansan_edge.py [원본 jpg] [출력 png]
"""
import sys

import numpy as np
from PIL import Image

SRC = "assets/concept/gwiseon_src/Geobukseon2.jpg"
OUT = "assets/textures/overlay/hansan_edge.png"
MAP = (-1130, -1841, 2258, 3386)  # 월드 영역 (x, y, w, h): StageTheme.background_rect와 같게
HALF = 2.0                         # 겹침 그림 한 픽셀 = 월드 2px
LINE = (205, 228, 238)             # 먹선을 밤 갑판 위에서 옅은 청백으로
SHELL = (356, 698, 1240, 940)
BAND = (342, 969, 1254, 1140)
HEAD = (100, 690, 380, 905)


def ink(src: Image.Image, box, lo=70, hi=150):
    c = src.convert("L").crop(box)
    a = 1.0 - np.clip((np.asarray(c).astype(float) - lo) / (hi - lo), 0.0, 1.0)
    return a


def place(canvas, motif, cx, cy, width_world, alpha, flip=False, fade=None):
    """motif(0~1 먹 농도)를 월드 좌표 (cx, cy) 가운데, 월드 폭 width_world로 canvas에 더한다."""
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
    x0 = int((cx - MAP[0]) / HALF - tw / 2)
    y0 = int((cy - MAP[1]) / HALF - th / 2)
    H, W = canvas.shape
    xs, ys = max(0, x0), max(0, y0)
    xe, ye = min(W, x0 + tw), min(H, y0 + th)
    if xe <= xs or ye <= ys:
        return
    sub = m[ys - y0:ye - y0, xs - x0:xe - x0] * alpha
    canvas[ys:ye, xs:xe] = np.maximum(canvas[ys:ye, xs:xe], sub)


def main(src_path=SRC, out=OUT):
    src = Image.open(src_path)
    shell, band, head = ink(src, SHELL), ink(src, BAND), ink(src, HEAD)
    W, H = int(MAP[2] / HALF), int(MAP[3] / HALF)
    canvas = np.zeros((H, W), dtype=float)
    # 위·아래 끝: 방패판 원 무늬 띠를 가로로 이어 (arena 위아래 끝 y ≈ ±1400)
    for y, fade in ((1330, "up"), (-1330, "down")):
        for cx in (-560, 320):
            place(canvas, band, cx, y, 900, 0.30, fade=fade)
    # 모서리: 귀갑문 조각 (가운데 전투 구역은 비움)
    for cx, cy, flip in ((-640, 1180, False), (640, 1180, True), (-640, -1180, True), (640, -1180, False)):
        place(canvas, shell, cx, cy, 620, 0.22, flip=flip)
    # 뱃머리(위 가운데): 용머리
    place(canvas, head, 0, -1500, 520, 0.40)
    rgba = np.zeros((H, W, 4), dtype=np.uint8)
    rgba[..., 0], rgba[..., 1], rgba[..., 2] = LINE
    rgba[..., 3] = (np.clip(canvas, 0, 1) * 255).astype(np.uint8)
    import os
    os.makedirs(os.path.dirname(out), exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(out)
    print("saved", out, rgba.shape)


if __name__ == "__main__":
    main(*sys.argv[1:])
