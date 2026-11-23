"""구운 공격 시트의 몸 움직임 크기 (무대 세션 motion_compare.md와 같은 정의, 8방향 중앙값):
몸 기울기 폭 = 칸마다 실루엣 주축 각도의 최대 - 최소(°), 무게 이동 = 실루엣 중심 가로 이동 ÷ 몸 키.

python tools/shots/measure_motion.py <시트.png> <칸 수> [칸 크기=256]
"""
import sys

import numpy as np
from PIL import Image


def frame_stats(cell):
    a = cell[:, :, 3] > 40
    ys, xs = np.nonzero(a)
    if len(xs) < 50:
        return None
    cx, cy = xs.mean(), ys.mean()
    cov = np.cov(np.stack([xs - cx, ys - cy]))
    w, v = np.linalg.eigh(cov)
    ax = v[:, np.argmax(w)]
    ang = np.degrees(np.arctan2(ax[0], ax[1]))  # 세로 기준
    if ang > 90:
        ang -= 180
    if ang < -90:
        ang += 180
    return ang, cx, ys.max() - ys.min()


def measure(path, frames, size=256):
    im = np.asarray(Image.open(path).convert("RGBA"))
    tilts, shifts = [], []
    for d in range(im.shape[0] // size):
        st = [frame_stats(im[d * size:(d + 1) * size, f * size:(f + 1) * size]) for f in range(frames)]
        st = [s for s in st if s]
        if len(st) < 2:
            continue
        angs = [s[0] for s in st]
        xs = [s[1] for s in st]
        h = np.median([s[2] for s in st])
        tilts.append(max(angs) - min(angs))
        shifts.append((max(xs) - min(xs)) / max(h, 1.0))
    return float(np.median(tilts)), float(np.median(shifts))


if __name__ == "__main__":
    t, s = measure(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]) if len(sys.argv) > 3 else 256)
    print(f"{sys.argv[1]}: tilt {t:.0f} deg, weight shift {s:.2f}")
