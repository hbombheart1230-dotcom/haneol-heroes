"""고리 그림의 고리만 바깥으로 옮긴다 (선 두께 px 그대로): 판 크기를 키우고 각 화소를 반지름 shift px만큼 밖으로.
python tools/art/widen_ring.py <원본.png> <출력.png> <shift_px> <새 판 한 변 px>
쓰임: 순신 해룡참 고리 (sea_dragon_ring.png → sea_dragon_ring_wide.png, 2026-11-24 "원 둘레 크기를 칼질에 맞게, 두께는 그냥")."""
import math
import sys

from PIL import Image

src = Image.open(sys.argv[1]).convert("RGBA")
shift = float(sys.argv[3])
size = int(sys.argv[4])
w, h = src.size
cs = (w / 2.0, h / 2.0)
co = size / 2.0
px = src.load()
out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
po = out.load()


def sample(x: float, y: float):
    x0, y0 = int(math.floor(x)), int(math.floor(y))
    fx, fy = x - x0, y - y0
    acc = [0.0] * 4
    for dx, dy, wt in ((0, 0, (1 - fx) * (1 - fy)), (1, 0, fx * (1 - fy)), (0, 1, (1 - fx) * fy), (1, 1, fx * fy)):
        xx, yy = x0 + dx, y0 + dy
        if 0 <= xx < w and 0 <= yy < h and wt > 0:
            p = px[xx, yy]
            for k in range(4):
                acc[k] += p[k] * wt
    return tuple(int(round(v)) for v in acc)


for y in range(size):
    for x in range(size):
        dx, dy = x + 0.5 - co, y + 0.5 - co
        r = math.hypot(dx, dy)
        rs = r - shift
        if rs <= 0:
            continue
        po[x, y] = sample(cs[0] + dx / r * rs - 0.5, cs[1] + dy / r * rs - 0.5)
out.save(sys.argv[2])
