"""흰 배경 소품 그림 한 장 → 소품마다 투명 PNG (무대 소품용).

  python tools/art/cut_props.py <그림.png> <출력 폴더> 이름1 이름2 ...
소품은 위→아래, 왼쪽→오른쪽 순으로 번호가 매겨진다 (이름을 그 순서대로 준다). 이름이 모자라면 prop_N.
작은 조각(면적 6000px 미만)은 버린다. 긴 변 240px로 줄인다.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage


def cut(src: str, out_dir: str, names: list, max_side: int = 240, min_area: int = 6000) -> list:
    a = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
    mn = a.min(axis=2)
    lab, _ = ndimage.label(ndimage.binary_dilation(mn < 225, iterations=2))
    items = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        if (sl[0].stop - sl[0].start) * (sl[1].stop - sl[1].start) >= min_area:
            items.append((sl, i + 1))
    # 같은 줄(세로 위치가 비슷한 것)끼리 묶어 왼쪽부터
    items.sort(key=lambda t: (round(((t[0][0].start + t[0][0].stop) / 2) / 160), t[0][1].start))
    alpha = np.clip((246.0 - mn) / 34.0, 0, 1)
    os.makedirs(out_dir, exist_ok=True)
    made = []
    for k, (sl, lid) in enumerate(items):
        m = lab[sl] == lid
        im = Image.fromarray(np.dstack([a[sl].astype(np.uint8), (alpha[sl] * m * 255).astype(np.uint8)]), "RGBA")
        im.thumbnail((max_side, max_side), Image.LANCZOS)
        name = names[k] if k < len(names) else f"prop_{k + 1}"
        path = os.path.join(out_dir, f"{name}.png")
        im.save(path, optimize=True)
        with open(path + ".import", "w", encoding="utf-8", newline="\n") as f:
            f.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
                    "compress/mode=1\ncompress/lossy_quality=0.7\nmipmaps/generate=false\n")
        made.append((name, im.size))
    return made


if __name__ == "__main__":
    for name, size in cut(sys.argv[1], sys.argv[2], sys.argv[3:]):
        print(name, size)
