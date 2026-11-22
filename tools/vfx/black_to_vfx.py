"""순흑 배경 GPT 그림을 투명 그림으로 (조각 시트·낙인·별 같은 빛나는 그림).

  python tools/vfx/black_to_vfx.py sheet <원본> <이름> [--cols 3 --rows 2 --px 128]   → assets/vfx/parts/<이름>_<n>.png
  python tools/vfx/black_to_vfx.py one <원본> <출력 png> [--px 384] [--box x0,y0,x1,y1] [--lo 0.10 --hi 0.45]

- 알파 = max(r,g,b)를 lo~hi 구간에서 매끄럽게 (검정 = 투명). 색은 알파로 나눠 복원 (어두운 가장자리 띠가 생기지 않게).
- 칸마다 그림이 있는 곳만 남기고 여백을 잘라 정사각형 가운데에 둔 뒤 px로 줄인다.
배경이 순흑이 아니면 (색 빛 번짐 배경) 깨끗하게 안 따진다: 검은 배경으로 다시 그려 달라고 할 것.
원본은 assets/concept/vfx_layers/ 에 두고, 넣은 뒤 tools/vfx/ink_tone.py 를 돌린다.
"""
import argparse
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PARTS = os.path.join(ROOT, "assets", "vfx", "parts")


def key_black(rgb: np.ndarray, lo: float = 0.10, hi: float = 0.45) -> np.ndarray:
    """rgb (H,W,3) 0~1 → rgba. 밝기(max)로 알파, 색은 알파로 나눠 복원."""
    m = rgb.max(-1)
    t = np.clip((m - lo) / max(hi - lo, 1e-4), 0.0, 1.0)
    a = t * t * (3.0 - 2.0 * t)
    col = np.clip(rgb / np.maximum(a, 1e-3)[..., None], 0.0, 1.0)
    return np.concatenate([col, a[..., None]], -1)


def trim_square(rgba: np.ndarray, px: int, pad: float = 0.04, cut: float = 0.02) -> Image.Image:
    """알파가 cut 넘는 곳만 남겨 정사각형 가운데에, px로."""
    ys, xs = np.nonzero(rgba[..., 3] > cut)
    if len(xs) == 0:
        return Image.new("RGBA", (px, px))
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    crop = rgba[y0:y1, x0:x1]
    side = int(max(x1 - x0, y1 - y0) * (1.0 + 2.0 * pad))
    out = np.zeros((side, side, 4), np.float32)
    oy, ox = (side - (y1 - y0)) // 2, (side - (x1 - x0)) // 2
    out[oy:oy + y1 - y0, ox:ox + x1 - x0] = crop
    pre = out.copy()
    pre[..., :3] *= pre[..., 3:4]  # 줄일 때 투명 픽셀 색이 섞이지 않게 (알파 곱한 채로 줄임)
    img = Image.fromarray((pre * 255).round().astype(np.uint8), "RGBA").resize((px, px), Image.LANCZOS)
    a = np.asarray(img).astype(np.float32) / 255.0
    a[..., :3] = np.clip(a[..., :3] / np.maximum(a[..., 3:4], 1e-4), 0, 1)
    a[..., :3] *= (a[..., 3:4] > 0)
    return Image.fromarray((a * 255).round().astype(np.uint8), "RGBA")


def load_rgb(path: str) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255.0


def cut_sheet(path: str, name: str, cols: int, rows: int, px: int, lo: float, hi: float) -> list:
    rgb = load_rgb(path)
    h, w = rgb.shape[:2]
    os.makedirs(PARTS, exist_ok=True)
    out = []
    for r in range(rows):
        for c in range(cols):
            cell = rgb[r * h // rows:(r + 1) * h // rows, c * w // cols:(c + 1) * w // cols]
            dst = os.path.join(PARTS, f"{name}_{r * cols + c + 1}.png")
            trim_square(key_black(cell, lo, hi), px).save(dst)
            out.append(dst)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["sheet", "one"])
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--cols", type=int, default=3)
    ap.add_argument("--rows", type=int, default=2)
    ap.add_argument("--px", type=int, default=128)
    ap.add_argument("--lo", type=float, default=0.10)
    ap.add_argument("--hi", type=float, default=0.45)
    ap.add_argument("--box", default="")
    a = ap.parse_args()
    if a.mode == "sheet":
        for p in cut_sheet(a.src, a.dst, a.cols, a.rows, a.px, a.lo, a.hi):
            print(p)
        return
    rgb = load_rgb(a.src)
    if a.box:
        x0, y0, x1, y1 = (int(v) for v in a.box.split(","))
        rgb = rgb[y0:y1, x0:x1]
    trim_square(key_black(rgb, a.lo, a.hi), a.px).save(a.dst)
    print(a.dst)


if __name__ == "__main__":
    main()
