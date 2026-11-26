"""한산 구역 2·3 배 지도 (0.4.3 배 건너뛰기): 사용자가 GPT로 그린 지도 두 장을 게임용으로 다듬는다.

  python tools/art/make_hansan_ships.py

- hansan_sekibune.png  : 구역 2 왜군 중형선 (원본 그대로)
- hansan_atakebune.png : 구역 3 왜군 대장선. 원본(hansan_atakebune_raw.png, 저장소에는 넣지 않음 — build/stage_src/hansan_ships_orig/)
  에서 선체·난간의 금빛 꽃 문양 7개를 바로 옆 나무판을 복사해 덮는다 (실제 가문 문장으로 읽힐 수 있어서).
  생성형 도구 없이 자르기·붙이기·가장자리 흐림만. 누각 지붕 금 장식(문양 아님)은 그대로.
- 게임용 배경: make_backgrounds.py와 같은 처리 (2배 Lanczos + 살짝 선명) → assets/backgrounds/<id>.png.
  바닥 결(deck_planks)·가장자리 먹선(hansan_edge)은 무대 모양(StageLook)에서 겹치므로 그림에는 굽지 않는다.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MAPS = "assets/concept/stages/maps"
RAW = "build/stage_src/hansan_ships_orig/hansan_atakebune_raw.png"
UPSCALE = 2

## 덮을 문양: (가운데 x, y, 가로 반지름, 세로 반지름, 복사해 올 곳까지 dx, dy) — 원본 1024×1536 픽셀.
CRESTS = [
    (512, 1503, 44, 38, -96, 0),   # 아래 난간 가운데 큰 꽃
    (249, 1503, 17, 17, 44, 0),    # 아래 왼쪽 작은 꽃
    (772, 1503, 17, 17, -44, 0),   # 아래 오른쪽 작은 꽃
    (101, 1436, 14, 15, 0, 40),   # 왼쪽 뒤 선체
    (922, 1436, 14, 15, 0, 40),   # 오른쪽 뒤 선체
    (15, 1165, 13, 16, 0, 40),    # 왼쪽 옆 선체
    (1009, 1165, 13, 16, -24, 30),  # 오른쪽 옆 선체
]


def cover(img: Image.Image, crests=CRESTS, feather: float = 3.0) -> Image.Image:
    out = img.copy()
    for cx, cy, rx, ry, dx, dy in crests:
        pad = int(feather * 3)
        box = (cx - rx - pad, cy - ry - pad, cx + rx + pad, cy + ry + pad)
        src = img.crop((box[0] + dx, box[1] + dy, box[2] + dx, box[3] + dy))
        m = Image.new("L", src.size, 0)
        ImageDraw.Draw(m).ellipse([pad, pad, pad + 2 * rx, pad + 2 * ry], fill=255)
        out.paste(src, box[:2], m.filter(ImageFilter.GaussianBlur(feather)))
    return out


def upscale(src: Image.Image) -> Image.Image:
    big = src.resize((src.width * UPSCALE, src.height * UPSCALE), Image.LANCZOS)
    return big.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))


def raw_path(raw: str = RAW) -> str:
    """build/는 깃 밖이라 worktree에는 없다 — 본 저장소(…/.claude/worktrees/ 위) 쪽도 찾는다."""
    if os.path.isabs(raw):
        return raw
    main_repo = ROOT.split(os.sep + ".claude" + os.sep)[0]
    for base in (ROOT, main_repo):
        if os.path.exists(os.path.join(base, raw)):
            return os.path.join(base, raw)
    raise FileNotFoundError(raw)


def main(raw: str = RAW) -> None:
    raw_path_ = raw_path(raw)
    ata = cover(Image.open(raw_path_).convert("RGB"))
    ata.save(os.path.join(ROOT, MAPS, "hansan_atakebune.png"), optimize=True)
    os.makedirs(os.path.join(ROOT, "assets/backgrounds"), exist_ok=True)
    for sid in ("hansan_sekibune", "hansan_atakebune"):
        src = Image.open(os.path.join(ROOT, MAPS, f"{sid}.png")).convert("RGB")
        upscale(src).save(os.path.join(ROOT, "assets/backgrounds", f"{sid}.png"), optimize=True)
        print("background", sid, src.size, "->", (src.width * UPSCALE, src.height * UPSCALE))


if __name__ == "__main__":
    main(*sys.argv[1:])
