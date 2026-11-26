"""만주·경복궁·초충도 새 구역 지도 (전장 확장 준비): 사용자가 GPT로 그린 지도를 게임용으로 다듬는다.

  python tools/art/make_zone_maps.py

- 원본(사용자 GPT 그림, 한글 이름)은 build/stage_src/<전장>_orig/ 에 보관, *_raw.png가 손대기 전 사본.
- 글자·문장처럼 읽힐 수 있는 곳만 지운다 (생성형 없이): "copy" = 옆자리 복사해 덮기, "soften" = 그 자리만 흐리게.
- 게임용 배경: make_backgrounds.py와 같은 2배 Lanczos + 살짝 선명 → assets/backgrounds/<id>.png.
- 예비 판(만주 목책 alt1/alt3)은 build/stage_src/manchuria_alt/ 에만 둔다 (게임에 안 넣음).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
from make_hansan_ships import ROOT, raw_path, upscale  # noqa: E402

MAPS = "assets/concept/stages/maps"

## 지도 id: 손볼 곳 [(방식, 가운데 x, y, 가로 반지름, 세로 반지름, dx, dy)] (원본 1024×1536 픽셀)
CLEAN = {
    "manchuria_palisade": [],
    "manchuria_camp": [],
    "gyeongbokgung_gate_road": [
        ("soften", 551, 104, 38, 6, 0, 0),     # 문 위 가운데 현판 자리의 흐린 글자 같은 획
        ("soften", 550, 81, 22, 4, 0, 0),     # 그 위 작은 판
    ],
    "gyeongbokgung_terrace": [
        ("soften", 524, 119, 46, 8, 0, 0),    # 문 위 가운데 판의 흐린 획
        ("soften", 145, 417, 24, 13, 0, 0),   # 왼쪽 향로 둥근 무늬 (글자처럼 읽힘)
        ("soften", 895, 417, 24, 13, 0, 0),   # 오른쪽 향로 둥근 무늬
    ],
    "chochungdo_melon": [],
    "chochungdo_pond": [],
}
STAGE = {"manchuria": "manchuria_orig", "gyeongbokgung": "gyeongbokgung_orig", "chochungdo": "chochungdo_orig"}


def clean(img: Image.Image, spots, feather: float = 2.5) -> Image.Image:
    out = img.copy()
    for mode, cx, cy, rx, ry, dx, dy in spots:
        pad = int(feather * 3)
        box = (cx - rx - pad, cy - ry - pad, cx + rx + pad, cy + ry + pad)
        if mode == "copy":
            src = img.crop((box[0] + dx, box[1] + dy, box[2] + dx, box[3] + dy))
        else:
            src = img.crop((box[0] - 8, box[1] - 8, box[2] + 8, box[3] + 8)).filter(ImageFilter.GaussianBlur(3))
            src = src.crop((8, 8, src.width - 8, src.height - 8))
        m = Image.new("L", src.size, 0)
        ImageDraw.Draw(m).ellipse([pad, pad, pad + 2 * rx, pad + 2 * ry], fill=255)
        out.paste(src, box[:2], m.filter(ImageFilter.GaussianBlur(feather)))
    return out


def raw_of(sid: str) -> str:
    return raw_path(f"build/stage_src/{STAGE[sid.split('_')[0]]}/{sid}_raw.png")


def main() -> None:
    os.makedirs(os.path.join(ROOT, "assets/backgrounds"), exist_ok=True)
    for sid, spots in CLEAN.items():
        src = clean(Image.open(raw_of(sid)).convert("RGB"), spots)
        src.save(os.path.join(ROOT, MAPS, f"{sid}.png"), optimize=True)
        upscale(src).save(os.path.join(ROOT, "assets/backgrounds", f"{sid}.png"), optimize=True)
        print(sid, f"{len(spots)} spots", src.size, "->", (src.width * 2, src.height * 2))


if __name__ == "__main__":
    main()
