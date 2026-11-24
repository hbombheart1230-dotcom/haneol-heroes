"""GPT로 그린 움직이는 기술 그림 시트를 게임용 프레임 시트로 다듬는다 (규격: docs/skill_vfx_sheets.md).

  python tools/vfx/sheet_to_vfx.py <원본.png> <이름> [--cols 3] [--rows 2] [--size 256] [--strip]
                                   [--smooth 0.2] [--tween] [--loop] [--no-lock]
원본은 assets/concept/vfx_sheets/<이름>.png 에 둔다 (APK에 안 들어감). 결과: assets/vfx/sheets/<이름>.png
그리고 기술 데이터(.tres)에 붙일 줄을 출력한다.

하는 일:
1. 칸 나누기: 가로 cols × 세로 rows 똑같이 (칸 테두리 2%는 버림, GPT가 칸 경계에 번짐을 남김).
2. 바탕 빼기: 투명 PNG면 옅은 안개를 깎고, 흰 바탕이면 흰색을 빼서 알파를 만든다 (gpt_to_vfx.py와 같은 방식).
   반투명 가장자리 색 오염도 지운다.
3. 중심 고정 (--no-lock이면 안 함): 장마다 그림 무게중심을 모든 장의 가운데값으로 옮긴다 (GPT가 장마다 조금씩 어긋남 → 흔들림).
4. 모든 장을 같은 네모로 자른다 (모든 장을 합친 영역, 크기가 장마다 튀지 않게).
5. 깜빡임 줄이기 (--smooth s): 장마다 앞뒤 장을 s만큼 섞는다 (미리 곱한 알파로 섞어 검은 테두리가 안 생김).
   --tween: 장 사이에 반반 섞은 장을 끼워 장 수를 두 배로 (모양이 크게 바뀌는 곳이 부드러워짐).
6. 가로 4칸으로 다시 묶어 저장한다.
--strip: 띠(파도격·벽력돌파·발묵)용. 정사각형 대신 가로로 긴 칸 (너비 size×2), 오른쪽 = 앞.
"""
import argparse
import math
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.dirname(__file__))
from gpt_to_vfx import HAZE_CUT, _decontaminate  # noqa: E402  (같은 바탕 정리)

OUT_DIR = os.path.join(ROOT, "assets", "vfx", "sheets")
OUT_COLS = 4
MARGIN = 0.02


def split(img: Image.Image, cols: int, rows: int) -> list:
    w, h = img.width / cols, img.height / rows
    mx, my = w * MARGIN, h * MARGIN
    return [img.crop((int(c * w + mx), int(r * h + my), int((c + 1) * w - mx), int((r + 1) * h - my)))
            for r in range(rows) for c in range(cols)]


def to_rgba(cell: Image.Image) -> np.ndarray:
    """바탕을 빼서 0~1 RGBA (투명 PNG면 안개 깎기, 아니면 흰 바탕 빼기)."""
    c = np.asarray(cell.convert("RGBA")).astype(np.float32) / 255.0
    if c[..., 3].min() < 0.9:  # 진짜 투명 바탕
        lo, hi = HAZE_CUT
        a = np.clip((c[..., 3] - lo) / (hi - lo), 0, 1)
        c[..., 3] = c[..., 3] * (a * a * (3 - 2 * a))
    else:  # 흰 바탕
        rgb = c[..., :3]
        a = np.clip(((1.0 - rgb).max(-1) - 0.04) / 0.30, 0, 1)
        a = a * a * (3 - 2 * a)
        rgb = (rgb - (1 - a[..., None])) / np.maximum(a[..., None], 1e-3)
        c = np.dstack([np.clip(rgb, 0, 1), a])
    return _decontaminate(c)


def centroid(rgba: np.ndarray) -> tuple:
    a = rgba[..., 3]
    s = a.sum()
    if s < 1e-3:
        return rgba.shape[1] / 2, rgba.shape[0] / 2
    ys, xs = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    return float((xs * a).sum() / s), float((ys * a).sum() / s)


def shift(rgba: np.ndarray, dx: float, dy: float) -> np.ndarray:
    img = Image.fromarray((rgba * 255).astype(np.uint8), "RGBA")
    out = Image.new("RGBA", img.size)
    out.paste(img, (int(round(dx)), int(round(dy))))
    return np.asarray(out).astype(np.float32) / 255.0


def lock_centers(frames: list) -> list:
    cs = [centroid(f) for f in frames]
    mx = float(np.median([c[0] for c in cs]))
    my = float(np.median([c[1] for c in cs]))
    return [shift(f, mx - c[0], my - c[1]) for f, c in zip(frames, cs)]


def same_box(frames: list, strip: bool) -> list:
    """모든 장을 합친 영역을 (띠가 아니면 가운데 맞춘 정사각형으로) 잘라 같은 크기로."""
    h, w = frames[0].shape[:2]
    union = np.zeros((h, w), np.float32)
    for f in frames:
        union = np.maximum(union, f[..., 3])
    ys, xs = np.nonzero(union > 0.02)
    if len(xs) == 0:
        return frames
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    if not strip:  # 가운데 기준 정사각형 (돌려 그려도 중심이 안 흔들리게)
        cx, cy = w / 2, h / 2
        half = max(cx - x0, x1 - cx, cy - y0, y1 - cy)
        x0, x1, y0, y1 = int(cx - half), int(cx + half), int(cy - half), int(cy + half)
    out = []
    for f in frames:
        img = Image.fromarray((f * 255).astype(np.uint8), "RGBA")
        out.append(np.asarray(img.crop((x0, y0, x1, y1))).astype(np.float32) / 255.0)
    return out


def premul(f: np.ndarray) -> np.ndarray:
    p = f.copy()
    p[..., :3] *= p[..., 3:4]
    return p


def unpremul(p: np.ndarray) -> np.ndarray:
    f = p.copy()
    f[..., :3] = f[..., :3] / np.maximum(f[..., 3:4], 1e-4)
    return np.clip(f, 0, 1)


def smooth(frames: list, s: float, loop: bool) -> list:
    """앞뒤 장을 s만큼 섞어 장마다 모양이 튀는 깜빡임을 줄인다."""
    if s <= 0 or len(frames) < 3:
        return frames
    p = [premul(f) for f in frames]
    n = len(p)
    out = []
    for i in range(n):
        a = p[(i - 1) % n] if loop or i > 0 else p[i]
        b = p[(i + 1) % n] if loop or i < n - 1 else p[i]
        out.append(unpremul(p[i] * (1 - 2 * s) + (a + b) * s))
    return out


def tween(frames: list, loop: bool) -> list:
    p = [premul(f) for f in frames]
    out = []
    for i in range(len(p)):
        out.append(frames[i])
        if i < len(p) - 1 or loop:
            out.append(unpremul((p[i] + p[(i + 1) % len(p)]) * 0.5))
    return out


def pack(frames: list, size: int, strip: bool) -> tuple:
    cw, ch = (size * 2, size) if strip else (size, size)
    rows = math.ceil(len(frames) / OUT_COLS)
    sheet = Image.new("RGBA", (cw * OUT_COLS, ch * rows))
    for i, f in enumerate(frames):
        img = Image.fromarray((f * 255).astype(np.uint8), "RGBA")
        if strip:  # 비율 유지, 세로 가운데
            k = min(cw / img.width, ch / img.height)
            img = img.resize((max(int(img.width * k), 1), max(int(img.height * k), 1)), Image.LANCZOS)
            cell = Image.new("RGBA", (cw, ch))
            cell.paste(img, ((cw - img.width) // 2, (ch - img.height) // 2))
            img = cell
        else:
            img = img.resize((cw, ch), Image.LANCZOS)
        sheet.paste(img, ((i % OUT_COLS) * cw, (i // OUT_COLS) * ch))
    return sheet, rows


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("name")
    ap.add_argument("--cols", type=int, default=3)
    ap.add_argument("--rows", type=int, default=2)
    ap.add_argument("--size", type=int, default=256)
    ap.add_argument("--smooth", type=float, default=0.2)
    ap.add_argument("--tween", action="store_true")
    ap.add_argument("--loop", action="store_true")
    ap.add_argument("--strip", action="store_true")
    ap.add_argument("--no-lock", action="store_true")
    args = ap.parse_args()
    frames = [to_rgba(c) for c in split(Image.open(args.src), args.cols, args.rows)]
    if not args.no_lock:
        frames = lock_centers(frames)
    frames = same_box(frames, args.strip)
    frames = smooth(frames, args.smooth, args.loop)
    if args.tween:
        frames = tween(frames, args.loop)
    sheet, rows = pack(frames, args.size, args.strip)
    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, f"{args.name}.png")
    sheet.save(out, optimize=True)
    fps = 16 if args.tween else 10
    key = "strip_sheet" if args.strip else "sheet"
    print(out)
    print(f'# 기술 데이터에: [ext_resource type="Texture2D" path="res://assets/vfx/sheets/{args.name}.png" id="sheet"]')
    print(f'{key} = ExtResource("sheet")\nsheet_cols = {OUT_COLS}\nsheet_rows = {rows}\nsheet_count = {len(frames)}\n'
          f'sheet_fps = {fps}.0\nsheet_loop = {"true" if args.loop else "false"}')


if __name__ == "__main__":
    main()
