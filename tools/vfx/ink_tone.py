"""기술 그림에 수묵 톤을 입힌다 (캐릭터는 굽기 때 먹선·번짐이 들어가는데 기술 그림만 쨍해서).

  python tools/vfx/ink_tone.py            # assets/vfx 의 기술 그림 전부
  python tools/vfx/ink_tone.py --check    # 바꿀 것이 있는지만 본다

- 채도: 그림 평균 채도가 TARGET_SAT를 넘으면 그만큼만 낮춘다 (이미 차분한 그림은 그대로).
- 먹선: 어두운 곳과 그림 가장자리를 먹색으로 (LINE).
- 번짐: 순백 하이라이트를 한지색 쪽으로 (WASH).
원본은 assets/concept/vfx_src/ 에 두고 늘 원본에서 다시 만든다 (여러 번 돌려도 같은 결과).
assets/vfx 의 그림이 지난번 결과와 다르면 (gpt_to_vfx 로 새 그림을 넣었으면) 그것을 새 원본으로 삼는다.
붓 질감(brush_*)은 코드가 색을 입히는 흰 그림이라 건드리지 않는다.
"""
import glob
import hashlib
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DST = os.path.join(ROOT, "assets/vfx")
SRC = os.path.join(ROOT, "assets/concept/vfx_src")
DONE = os.path.join(ROOT, "tools/vfx/ink_tone.done.json")
SKIP_PREFIX = ("brush_", "boss_", "spawn_", "trail_")  # 흰 붓 질감, 인주 낙인, 먹 번짐, 검기 띠(무채색, 색은 SwingTrail이 입힘)는 그대로
TARGET_SAT = 0.36
LINE = 0.62
WASH = 0.55
DARK = 0.93
INK = np.array([0.09, 0.09, 0.11], dtype=np.float32)
PAPER = np.array([0.93, 0.90, 0.82], dtype=np.float32)


def mean_saturation(rgb: np.ndarray, alpha: np.ndarray) -> float:
    m = alpha > 0.5
    if not m.any():
        return 0.0
    px = rgb[m]
    mx = px.max(-1)
    return float(((mx - px.min(-1)) / np.maximum(mx, 1e-3)).mean())


def sat_scale(sat: float, target: float = TARGET_SAT) -> float:
    """채도 배율: 목표를 넘는 만큼만 낮춘다 (1 이하)."""
    return 1.0 if sat <= target else target / sat


def tone(img: Image.Image) -> Image.Image:
    a = np.asarray(img.convert("RGBA")).astype(np.float32) / 255.0
    rgb, al = a[..., :3], a[..., 3]
    lum = (rgb * np.array([0.299, 0.587, 0.114], dtype=np.float32)).sum(-1, keepdims=True)
    rgb = (lum + (rgb - lum) * sat_scale(mean_saturation(rgb, al))) * DARK
    dark = np.clip((0.55 - lum) / 0.55, 0, 1) ** 1.5
    rgb = rgb * (1 - dark * LINE) + INK * dark * LINE
    blur = np.asarray(Image.fromarray((al * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.5))).astype(np.float32) / 255.0
    rim = (np.clip((al - blur) * 4, 0, 1) * (al > 0.3))[..., None]
    rgb = rgb * (1 - rim * LINE) + INK * rim * LINE
    hi = np.clip((lum - 0.75) / 0.25, 0, 1)
    rgb = rgb * (1 - hi * WASH) + PAPER * hi * WASH
    out = np.dstack([np.clip(rgb, 0, 1), al])
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")


def sha(path: str) -> str:
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def targets() -> list:
    paths = sorted(glob.glob(os.path.join(DST, "*.png"))) + sorted(glob.glob(os.path.join(DST, "parts", "*.png")))
    return [p for p in paths if not os.path.basename(p).startswith(SKIP_PREFIX)]


def run(check: bool = False) -> int:
    done = json.load(open(DONE, encoding="utf-8")) if os.path.exists(DONE) else {}
    os.makedirs(SRC, exist_ok=True)
    changed = 0
    for path in targets():
        name = os.path.relpath(path, DST).replace(os.sep, "/")
        src = os.path.join(SRC, name)
        os.makedirs(os.path.dirname(src), exist_ok=True)
        if not os.path.exists(src) or done.get(name) != sha(path):  # 처음이거나 새 그림이 들어왔다
            if check:
                changed += 1
                continue
            shutil.copyfile(path, src)
        elif check:
            continue
        tone(Image.open(src)).save(path, optimize=True)
        done[name] = sha(path)
        changed += 1
        print("ok", name)
    if not check:
        with open(DONE, "w", encoding="utf-8") as f:
            json.dump(done, f, indent=1, sort_keys=True)
    return changed


if __name__ == "__main__":
    n = run("--check" in sys.argv)
    print("바꿀 그림" if "--check" in sys.argv else "수묵 톤 입힘", n)
