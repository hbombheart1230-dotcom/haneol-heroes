"""초충도 병풍(국립중앙박물관 전 신사임당필 초충도 신수3550, 공공누리 제1유형) 그림만 잘린 판(clean_*.jpg)에서
식물·열매·나비를 잘라 소품 PNG(assets/props/chochungdo/screen_*.png)로 만든다.

종이 바탕색을 상자 가장자리 중앙값으로 잡아 그 색에서 먼 픽셀만 남긴다 (부드러운 알파, 먹 점·얼룩 제거).
상자는 판 크기 대비 비율(x0, y0, x1, y1)이라 원본 해상도가 달라도 같은 자리를 자른다.
원본은 저장소에 두지 않는다 (판당 15MB): 아래 SRC 폴더에 clean_*.jpg가 있어야 돌아간다.
python tools/art/cut_chochungdo.py [원본 폴더] [출력 폴더]
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

SRC = r"C:/Haneol-Heroes/assets/concept/chochungdo_src"
OUT = "assets/props/chochungdo"
MAX_PX = 300  # 소품 한 변 최대 (화면에서 0.55~0.8배로 그려진다)
THRESH = {"screen_poppy": (34.0, 62.0), "screen_smartweed": (30.0, 58.0), "screen_orange_flower": (30.0, 58.0)}  # 종이가 얼룩진 판
SMALL = {"screen_butterfly_red": 120, "screen_butterfly_white": 130, "screen_moth_eggplant": 90, "screen_dragonfly": 150}

# 이름: (판, (x0, y0, x1, y1) 비율, 막히는 소품인지)
CUTS = {
    "screen_cockscomb": ("cockscomb_dung_beetle", (0.17, 0.10, 0.69, 0.80), True),
    "screen_cucumber": ("cucumber_frog", (0.08, 0.14, 0.88, 0.80), True),
    "screen_daylily": ("daylily_cicada_frog", (0.11, 0.07, 0.88, 0.81), True),
    "screen_eggplant": ("eggplant", (0.08, 0.13, 0.88, 0.82), True),
    "screen_orange_flower": ("orange_flower_frog_dragonfly", (0.0, 0.11, 0.70, 0.78), False),
    "screen_poppy": ("poppy_lizard", (0.12, 0.17, 0.90, 0.82), True),
    "screen_smartweed": ("smartweed_mantis", (0.10, 0.22, 0.98, 0.755), False),
    "screen_watermelon": ("watermelon", (0.0, 0.17, 0.98, 0.79), True),
    "screen_butterfly_red": ("watermelon", (0.14, 0.15, 0.36, 0.25), False),
    "screen_butterfly_white": ("watermelon", (0.52, 0.11, 0.74, 0.26), False),
    "screen_moth_eggplant": ("eggplant", (0.24, 0.12, 0.50, 0.23), False),
    "screen_dragonfly": ("smartweed_mantis", (0.62, 0.05, 0.80, 0.22), False),
}


def cut(img: Image.Image, box, thresh=(24.0, 52.0), max_px=MAX_PX):
    w, h = img.size
    c = img.crop((int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h))).convert("RGB")
    a = np.asarray(c).astype(float)
    ring = max(4, int(min(a.shape[:2]) * 0.03))
    edge = np.concatenate([a[:ring].reshape(-1, 3), a[-ring:].reshape(-1, 3),
                           a[:, :ring].reshape(-1, 3), a[:, -ring:].reshape(-1, 3)])
    paper = np.median(edge, axis=0)
    # 종이 얼룩(밝기 변화)은 덜 보고, 색이 다른 곳(녹청·적·남·흰)을 본다: 색차(밝기 뺀 부분) + 밝기 차의 절반
    pn = paper - paper.mean()
    cn = a - a.mean(axis=2, keepdims=True)
    chroma = np.linalg.norm(cn - pn, axis=2)
    lum = np.abs(a.mean(axis=2) - paper.mean())
    d = chroma * 1.4 + lum * 0.9
    lo, hi = thresh
    al = np.clip((d - lo) / (hi - lo), 0.0, 1.0)
    al = np.clip((al - 0.18) / 0.82, 0.0, 1.0)  # 종이 얼룩의 옅은 안개 제거
    m = Image.fromarray((al * 255).astype(np.uint8))
    m = m.filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.GaussianBlur(1.5))  # 점 잡음 제거, 가장자리 부드럽게
    out = c.convert("RGBA")
    out.putalpha(m)
    bb = m.point(lambda v: 255 if v > 40 else 0).getbbox()
    if bb:
        out = out.crop(bb)
    out.thumbnail((max_px, max_px), Image.LANCZOS)
    return out


def main(src=SRC, out=OUT):
    os.makedirs(out, exist_ok=True)
    cache = {}
    for name, (panel, box, _solid) in CUTS.items():
        if panel not in cache:
            cache[panel] = Image.open(os.path.join(src, "clean_%s.jpg" % panel))
        cut(cache[panel], box, thresh=THRESH.get(name, (24.0, 52.0)), max_px=SMALL.get(name, MAX_PX)).save(os.path.join(out, name + ".png"))
        print("cut", name)


if __name__ == "__main__":
    main(*sys.argv[1:])
