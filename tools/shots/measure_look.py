"""화면 그림의 명암·색 측정 (하데스 비교용).

밝기 = Rec.709 휘도, 채도 = HSV 채도. HUD를 빼려고 위·아래 일부를 잘라 잴 수 있다.
python tools/shots/measure_look.py <png> [<png> ...] [--crop 0.06,0.12]  (위 비율, 아래 비율)
"""
import sys

import numpy as np
from PIL import Image

LUMA = np.array([0.2126, 0.7152, 0.0722])


def measure(path, top=0.0, bottom=0.0):
    a = np.asarray(Image.open(path).convert("RGB")).astype(float) / 255.0
    h = a.shape[0]
    a = a[int(h * top): h - int(h * bottom)]
    y = a @ LUMA
    mx = a.max(2)
    mn = a.min(2)
    s = np.where(mx > 0.02, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    return {"mean": y.mean(), "std": y.std(), "p95": np.percentile(y, 95), "sat": s.mean()}


def main(argv):
    top = bottom = 0.0
    paths = []
    i = 0
    while i < len(argv):
        if argv[i] == "--crop":
            top, bottom = (float(v) for v in argv[i + 1].split(","))
            i += 2
            continue
        paths.append(argv[i])
        i += 1
    print("file\tmean\tstd\tp95\tsat")
    for p in paths:
        m = measure(p, top, bottom)
        print("%s\t%.3f\t%.3f\t%.3f\t%.3f" % (p, m["mean"], m["std"], m["p95"], m["sat"]))


if __name__ == "__main__":
    main(sys.argv[1:])
