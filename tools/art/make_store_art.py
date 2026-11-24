"""Play 스토어 그림: 아이콘 512 (앱 아이콘 원본 그대로 복사), 대표 그림 1024x500 (입장 그림에서 네 영웅 줄을 잘라 위에 제목).

  python tools/art/make_store_art.py [입장 그림 경로] [출력 폴더]
기본: assets/ui/title_bg.png → build/release/store/ (깃 제외). 제목·낙관은 korean_title_art.py의 cover/title 재사용.
입장 그림은 941 폭이라 1024 폭으로 1.09배만 키운다 (그 밖의 손질 없음).
"""
import os
import shutil
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from korean_title_art import ROOT, cover, title  # noqa: E402

CROP_TOP = 0.353  # 네 영웅 머리(맨 아래 세종 얼굴까지)가 다 들어오는 줄 (입장 그림 높이 대비)


def feature(src: str, out: str) -> None:
    t = Image.open(src).convert("RGB")
    w, h = t.size
    ch = round(w * 500 / 1024)
    y0 = min(int(h * CROP_TOP), h - ch)
    g = t.crop((0, y0, w, y0 + ch)).resize((1024, 500), Image.LANCZOS)
    g = title(cover(g, -60, 112), 46, 0.42).convert("RGB")  # 위쪽 물결 위에 제목 (영웅 얼굴을 가리지 않게)
    g.save(out, optimize=True)


def main() -> None:
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets/ui/title_bg.png")
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "build/release/store")
    os.makedirs(out_dir, exist_ok=True)
    shutil.copyfile(os.path.join(ROOT, "assets/store/icon_512.png"), os.path.join(out_dir, "icon_512.png"))
    feature(src, os.path.join(out_dir, "feature_1024x500.png"))


if __name__ == "__main__":
    main()
