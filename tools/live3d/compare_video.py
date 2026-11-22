"""구운 그림 ↔ 실시간 3D 비교 영상·프레임 띠 만들기 (시험).

compare_shot.gd 가 Movie Maker 로 찍은 PNG 연번(f00000000.png ...)과 구간 표시(marks.json)를 읽어
영웅 둘레만 잘라 build/preview/ 에 저장한다:
  live3d_compare.mp4        전체 (60fps 원래 속도)
  live3d_compare_slow.mp4   전체 0.5배속 (동작 사이 이음매를 보기 쉽게)
  live3d_<구간>.png         구간별 프레임 띠 (2프레임마다, 칸 위에 경과 ms)
python tools/live3d/compare_video.py <frames 폴더> <marks.json> [출력 폴더]
"""
import json
import os
import sys

import imageio.v2 as imageio
import numpy as np
from PIL import Image, ImageDraw

CROP_W, CROP_UP, CROP_DOWN = 470, 270, 130


def crop(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    cx, cy = w // 2, h // 2
    return im.crop((cx - CROP_W // 2, cy - CROP_UP, cx + CROP_W // 2, cy + CROP_DOWN))


def strip(frames_dir, start, end, every, cols, out):
    idx = list(range(start, end, every))
    cells = []
    for i in idx:
        c = crop(os.path.join(frames_dir, "f%08d.png" % i))
        c = c.resize((c.width * 3 // 4, c.height * 3 // 4))
        ImageDraw.Draw(c).text((6, 4), "%d ms" % round((i - start) * 1000 / 60), fill=(255, 255, 255))
        cells.append(c)
    rows = (len(cells) + cols - 1) // cols
    cw, ch = cells[0].size
    sheet = Image.new("RGB", (cw * cols, ch * rows))
    for k, c in enumerate(cells):
        sheet.paste(c, ((k % cols) * cw, (k // cols) * ch))
    sheet.save(out)


def main():
    frames_dir, marks_path = sys.argv[1], sys.argv[2]
    out_dir = sys.argv[3] if len(sys.argv) > 3 else "build/preview"
    os.makedirs(out_dir, exist_ok=True)
    marks = json.load(open(marks_path, encoding="utf-8"))
    order = sorted(marks.items(), key=lambda kv: kv[1])
    first, last = order[0][1], order[-1][1]
    with imageio.get_writer(os.path.join(out_dir, "live3d_compare.mp4"), fps=60, quality=8,
                            macro_block_size=8) as w, \
            imageio.get_writer(os.path.join(out_dir, "live3d_compare_slow.mp4"), fps=30, quality=8,
                               macro_block_size=8) as ws:
        for i in range(first, last):
            a = np.asarray(crop(os.path.join(frames_dir, "f%08d.png" % i)))
            w.append_data(a)
            ws.append_data(a)
    spans = {"idle": ("idle", 40, 4), "combo": ("combo", 3, 8), "haeryong": ("haeryong", 3, 6),
             "dash": ("dash", 3, 6), "hit": ("hit", 3, 6), "run": ("run", 8, 6), "run_attack": ("run_attack", 4, 7)}
    for k, (name, every, cols) in spans.items():
        if k not in marks:
            continue
        start = marks[k]
        end = min([v for v in marks.values() if v > start] + [last])
        if k in ("combo",):
            end = marks.get("dash", end)  # 연타 1→2→3→해룡참 한 장
        strip(frames_dir, start, end, every, cols, os.path.join(out_dir, "live3d_%s.png" % name))
    print("done", first, last)


if __name__ == "__main__":
    main()
