"""사진 재질(CC0) → 바닥 결 층 (회색, 0.5 = 변화 없음). floor_grade 셰이더가 바닥 그림에 곱한다 (StageLook.detail_*).

밝기만 남기고 큰 얼룩은 빼서(하이패스) 결·흠만 남긴다 → 그린 바닥의 색과 판선은 그대로, 질감만 더한다.
python tools/art/make_grain.py <원본 jpg/png> <출력 png> [--blur 14] [--gain 2.2] [--rotate 90]
"""
import argparse

import numpy as np
from PIL import Image, ImageFilter


def grain(img: Image.Image, blur: float, gain: float) -> Image.Image:
    lum = img.convert("L")
    low = lum.filter(ImageFilter.GaussianBlur(blur))
    a = np.asarray(lum).astype(float) - np.asarray(low).astype(float)
    a = np.clip(128.0 + a * gain, 0, 255).astype(np.uint8)
    return Image.fromarray(a, "L")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("src")
    p.add_argument("out")
    p.add_argument("--blur", type=float, default=14.0)
    p.add_argument("--gain", type=float, default=2.2)
    p.add_argument("--rotate", type=int, default=0)
    a = p.parse_args()
    im = Image.open(a.src)
    if a.rotate:
        im = im.rotate(a.rotate, expand=True)
    grain(im, a.blur, a.gain).save(a.out)


if __name__ == "__main__":
    main()
