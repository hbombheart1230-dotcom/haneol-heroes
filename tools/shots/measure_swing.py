"""평타 이펙트만 잰다 (swing_strip.gd ... fx 결과): 휘두르기 전 바닥과 달라진 픽셀을 이펙트로 보고
칸마다 면적·밝기, 보이는 시간을 낸다.

python tools/shots/measure_swing.py <strip.png> [...]   (같은 이름_base.png 필요, 칸 = 높이 정사각형)
출력: 최대 면적(칸 대비 %), 면적 합(칸·%), 이펙트 평균 밝기, 이펙트 평균 채도, 보인 칸 수(면적 ≥ 2%, 25ms 간격),
바닥과의 밝기 차, 바닥과의 색 거리 (어두운 바닥에서 얼마나 튀는지).
"""
import os
import sys

import numpy as np
from PIL import Image

LUMA = np.array([0.2126, 0.7152, 0.0722])


def measure(path, thresh=0.12, min_area=0.02):
    strip = np.asarray(Image.open(path).convert("RGB")).astype(float) / 255.0
    base = np.asarray(Image.open(os.path.splitext(path)[0] + "_base.png").convert("RGB")).astype(float) / 255.0
    c = strip.shape[0]
    areas, lums, sats, dlums, dcols = [], [], [], [], []
    for i in range(strip.shape[1] // c):
        cell = strip[:, i * c:(i + 1) * c]
        mask = np.abs(cell - base).max(2) > thresh
        areas.append(mask.mean())
        if mask.any():
            px = cell[mask]
            lums.append((px @ LUMA).mean())
            mx, mn = px.max(1), px.min(1)
            sats.append(((mx - mn) / np.maximum(mx, 1e-6)).mean())
            bp = base[mask]
            dlums.append(np.abs(px @ LUMA - bp @ LUMA).mean())  # 바닥과의 밝기 차
            dcols.append(np.linalg.norm(px - bp, axis=1).mean())  # 바닥과의 색 거리 (RGB)
    areas = np.array(areas)
    return {"peak": areas.max(), "sum": areas.sum(), "lum": float(np.mean(lums)) if lums else 0.0,
            "sat": float(np.mean(sats)) if sats else 0.0, "frames": int((areas >= min_area).sum()),
            "dlum": float(np.mean(dlums)) if dlums else 0.0, "dcol": float(np.mean(dcols)) if dcols else 0.0}


def main(paths):
    keys = ["peak", "sum", "lum", "sat", "frames", "dlum", "dcol"]
    print("file\t" + "\t".join(keys))
    for p in paths:
        m = measure(p)
        print(os.path.basename(p) + "\t%.3f\t%.3f\t%.3f\t%.3f\t%d" % tuple(m[k] for k in keys))


if __name__ == "__main__":
    main(sys.argv[1:])
