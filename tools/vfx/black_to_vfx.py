"""순흑 배경 GPT 그림을 투명 그림으로 (조각 시트·낙인·별 같은 빛나는 그림).

  python tools/vfx/black_to_vfx.py sheet <원본> <이름> [--cols 3 --rows 2 --px 128]   → assets/vfx/parts/<이름>_<n>.png
  python tools/vfx/black_to_vfx.py one <원본> <출력 png> [--px 384] [--box x0,y0,x1,y1] [--lo 0.10 --hi 0.45]
      [--fill] [--rotate 도] [--size 1024x256]
- --fill: 테두리 안쪽은 어두워도 불투명 (해시계 판 안쪽 갈색처럼 밝기로 따면 뚫리는 그림).
- --rotate: 반시계로 돌린다 (바늘을 오른쪽으로 눕힐 때). --size: 정사각형 대신 가로×세로 칸에 왼쪽 맞춤
  (바늘: 왼쪽 끝 = 돌리는 축).

- 알파 = max(r,g,b)를 lo~hi 구간에서 매끄럽게 (검정 = 투명). 색은 알파로 나눠 복원 (어두운 가장자리 띠가 생기지 않게).
- 칸마다 그림이 있는 곳만 남기고 여백을 잘라 정사각형 가운데에 둔 뒤 px로 줄인다.
배경이 순흑이 아니면 (색 빛 번짐 배경) 깨끗하게 안 따진다: 검은 배경으로 다시 그려 달라고 할 것.
원본은 assets/concept/vfx_layers/ 에 두고, 넣은 뒤 tools/vfx/ink_tone.py 를 돌린다.
"""
import argparse
import os

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PARTS = os.path.join(ROOT, "assets", "vfx", "parts")


def key_black(rgb: np.ndarray, lo: float = 0.10, hi: float = 0.45) -> np.ndarray:
    """rgb (H,W,3) 0~1 → rgba. 밝기(max)로 알파, 색은 알파로 나눠 복원."""
    m = rgb.max(-1)
    t = np.clip((m - lo) / max(hi - lo, 1e-4), 0.0, 1.0)
    a = t * t * (3.0 - 2.0 * t)
    col = np.clip(rgb / np.maximum(a, 1e-3)[..., None], 0.0, 1.0)
    return np.concatenate([col, a[..., None]], -1)


def fill_inside(rgba: np.ndarray, rgb: np.ndarray, lo: float) -> np.ndarray:
    """그림 테두리로 둘러싸인 안쪽은 어두워도 불투명 (색은 원래 그대로)."""
    shape = ndimage.binary_fill_holes(rgb.max(-1) > lo)
    inside = ndimage.binary_erosion(shape, iterations=2)
    out = rgba.copy()
    out[inside, 3] = 1.0
    out[inside, :3] = rgb[inside]
    return out


def _resize_premul(out: np.ndarray, size: tuple) -> Image.Image:
    pre = out.copy()
    pre[..., :3] *= pre[..., 3:4]  # 줄일 때 투명 픽셀 색이 섞이지 않게 (알파 곱한 채로 줄임)
    img = Image.fromarray((pre * 255).round().astype(np.uint8), "RGBA").resize(size, Image.LANCZOS)
    a = np.asarray(img).astype(np.float32) / 255.0
    a[..., :3] = np.clip(a[..., :3] / np.maximum(a[..., 3:4], 1e-4), 0, 1)
    a[..., :3] *= (a[..., 3:4] > 0)
    return Image.fromarray((a * 255).round().astype(np.uint8), "RGBA")


def _bbox(rgba: np.ndarray, cut: float) -> tuple:
    ys, xs = np.nonzero(rgba[..., 3] > cut)
    return xs.min(), xs.max() + 1, ys.min(), ys.max() + 1


def trim_fit(rgba: np.ndarray, w: int, h: int, pad: float = 0.02, cut: float = 0.02,
        axis_top: bool = False) -> Image.Image:
    """여백을 잘라 w×h 칸에 비율 유지로, 왼쪽 끝에 붙이고 세로 가운데 (바늘: 왼쪽 = 축).
    axis_top: 그림의 윗변이 칸의 가로 가운데 줄에 오게 (윗변을 따라 도는 지느러미 모양 바늘)."""
    x0, x1, y0, y1 = _bbox(rgba, cut)
    crop = rgba[y0:y1, x0:x1]
    if axis_top:
        crop = np.concatenate([np.zeros_like(crop), crop], 0)
        y0, y1 = 0, crop.shape[0]
    k = min(w * (1 - pad) / (x1 - x0), h * (1 - 2 * pad) / (y1 - y0))
    cw, ch = max(int((x1 - x0) * k), 1), max(int((y1 - y0) * k), 1)
    small = np.asarray(_resize_premul(crop, (cw, ch))).astype(np.float32) / 255.0
    out = np.zeros((h, w, 4), np.float32)
    oy = (h - ch) // 2
    out[oy:oy + ch, int(w * pad * 0.5):int(w * pad * 0.5) + cw] = small
    return Image.fromarray((out * 255).round().astype(np.uint8), "RGBA")


def rotate(rgba: np.ndarray, deg: float) -> np.ndarray:
    """반시계로 deg도 (캔버스를 키워 잘리지 않게)."""
    img = Image.fromarray((rgba * 255).round().astype(np.uint8), "RGBA").rotate(deg, Image.BICUBIC, expand=True)
    return np.asarray(img).astype(np.float32) / 255.0


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
    return _resize_premul(out, (px, px))


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
    ap.add_argument("--fill", action="store_true")
    ap.add_argument("--rotate", type=float, default=0.0)
    ap.add_argument("--size", default="")
    ap.add_argument("--axis-top", action="store_true")
    a = ap.parse_args()
    if a.mode == "sheet":
        for p in cut_sheet(a.src, a.dst, a.cols, a.rows, a.px, a.lo, a.hi):
            print(p)
        return
    rgb = load_rgb(a.src)
    if a.box:
        x0, y0, x1, y1 = (int(v) for v in a.box.split(","))
        rgb = rgb[y0:y1, x0:x1]
    rgba = key_black(rgb, a.lo, a.hi)
    if a.fill:
        rgba = fill_inside(rgba, rgb, a.lo)
    if a.rotate:
        rgba = rotate(rgba, a.rotate)
    if a.size:
        w, h = (int(v) for v in a.size.lower().split("x"))
        trim_fit(rgba, w, h, axis_top=a.axis_top).save(a.dst)
    else:
        trim_square(rgba, a.px).save(a.dst)
    print(a.dst)


if __name__ == "__main__":
    main()
