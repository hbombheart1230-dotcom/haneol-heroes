"""사용자가 만든 GPT 이펙트 그림을 게임 텍스처로 다듬는다 (docs/skill_vfx_prompts.md).

  python tools/vfx/gpt_to_vfx.py <그림 폴더>
결과: assets/vfx/<이름>.png (256px, 투명 배경). icon_to_vfx.py가 만든 임시 그림을 덮어쓴다.

GPT의 "투명" PNG는 가장자리에 빨강·노랑 테두리 픽셀이나 희뿌연 안개가 남는다:
- 옅은 안개는 알파를 깎아 지우고 (HAZE_CUT),
- 반투명 가장자리 색은 안쪽 불투명 픽셀 색으로 바꿔 테두리 물듦을 없앤다 (색 오염 제거).
흰 바탕 묶음 그림(SHEET)에서만 있는 것들은 흰색을 빼서 알파를 만든다.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DST = os.path.join(ROOT, "assets/vfx")
SIZE = 256
## 이름: 고른 파일 (같은 이펙트 두 장 중 더 깨끗한 쪽)
PICKS = {
    "meteor": "e0e0d81e-image.png",      # v2: 불꽃이 더 또렷, 안개 적음
    "foam": "30921fed-image.png",        # v1: 물보라가 더 풍성
    "wave": "fca8bdb2-image.png",        # v1: 고리가 둥글어 돌려도 자연스러움
    "quake": "97f5b7fc-image.png",       # v1: 불길·빛이 더 강함
    "lightning": "69cb45c1-image.png",   # v2: v1은 회색 안개 상자 (v2의 빨강 테두리는 아래에서 지움)
    "constellation": "fda96084-image.png",  # v2: v1은 어두운 밤하늘 원판 안개
}
## 흰 바탕 묶음 그림: 5칸 × 2줄 (wave, foam, lightning, quake, meteor / constellation, glyphs, sundial, plum, ink)
SHEET = "0b54f876-image.png"
SHEET_CELLS = {"glyphs": (1, 1), "sundial": (1, 2), "plum": (1, 3), "ink": (1, 4)}
HAZE_CUT = (0.12, 0.45)  # 이 알파 아래는 안개로 보고 지우고, 위로 갈수록 그대로


def _decontaminate(rgba: np.ndarray) -> np.ndarray:
    """반투명 가장자리 색을 근처 불투명 픽셀 색으로 (빨강·노랑 테두리 물듦 제거)."""
    a = rgba[..., 3]
    solid = (a > 0.85).astype(np.float32)
    img = Image.fromarray((rgba[..., :3] * solid[..., None] * 255).astype(np.uint8), "RGB")
    m = Image.fromarray((solid * 255).astype(np.uint8), "L")
    rgb_b = np.asarray(img.filter(ImageFilter.GaussianBlur(6))).astype(np.float32) / 255.0
    m_b = np.asarray(m.filter(ImageFilter.GaussianBlur(6))).astype(np.float32)[..., None] / 255.0
    near = rgb_b / np.maximum(m_b, 1e-4)
    w = np.clip((0.85 - a) / 0.85, 0, 1)[..., None] * (m_b > 0.02)
    rgba[..., :3] = rgba[..., :3] * (1 - w) + near * w
    return rgba


def _finish(rgba: np.ndarray) -> Image.Image:
    lo, hi = HAZE_CUT
    a = np.clip((rgba[..., 3] - lo) / (hi - lo), 0, 1)
    rgba[..., 3] = rgba[..., 3] * (a * a * (3 - 2 * a))
    rgba = _decontaminate(rgba)
    img = Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")
    box = img.getbbox() or (0, 0, img.width, img.height)
    img = img.crop(box)
    side = max(img.width, img.height)
    sq = Image.new("RGBA", (side, side))
    sq.paste(img, ((side - img.width) // 2, (side - img.height) // 2))
    return sq.resize((SIZE, SIZE), Image.LANCZOS)


def clean_png(path: str) -> Image.Image:
    return _finish(np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0)


def cut_white(sheet: Image.Image, row: int, col: int) -> Image.Image:
    w, h = sheet.width / 5, sheet.height / 2
    cell = sheet.crop((int(col * w), int(row * h), int((col + 1) * w), int((row + 1) * h))).convert("RGB")
    c = np.asarray(cell).astype(np.float32) / 255.0
    dist = (1.0 - c).max(-1)  # 흰색에서 얼마나 먼지
    a = np.clip((dist - 0.04) / 0.30, 0, 1)
    a = a * a * (3 - 2 * a)
    # 흰 바탕을 빼고 색 되살리기 (흰색과 섞였던 만큼)
    rgb = (c - (1 - a[..., None])) / np.maximum(a[..., None], 1e-3)
    return _finish(np.dstack([np.clip(rgb, 0, 1), a]))


if __name__ == "__main__":
    src = sys.argv[1]
    os.makedirs(DST, exist_ok=True)
    for name, f in PICKS.items():
        clean_png(os.path.join(src, f)).save(os.path.join(DST, f"{name}.png"), optimize=True)
        print("ok", name, f)
    sheet = Image.open(os.path.join(src, SHEET))
    for name, (r, c) in SHEET_CELLS.items():
        cut_white(sheet, r, c).save(os.path.join(DST, f"{name}.png"), optimize=True)
        print("ok", name, "sheet")
