"""Play 스토어 그림: 아이콘 512 (앱 아이콘 원본 그대로 복사), 대표 그림 1024x500 (입장 그림에서 네 영웅 줄을 잘라 위에 제목).

  python tools/art/make_store_art.py [입장 그림 경로] [출력 폴더]
기본: assets/ui/title_bg.png → build/release/store/ (깃 제외). 제목·낙관은 korean_title_art.py의 cover/title 재사용.
입장 그림은 키우지 않는다 (941 폭이면 좌우 41px씩은 가장자리를 거울로 이어 살짝 흐림).
"""
import os
import shutil
import sys

from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
from korean_title_art import ROOT, cover, title  # noqa: E402

CROP_TOP = 0.335  # 이 줄부터 500줄: 네 영웅 얼굴(맨 아래 세종까지)이 다 들어온다 (입장 그림 높이 대비)


def feature(src: str, out: str) -> None:
    """입장 그림을 키우지 않고 500줄을 잘라 가운데에 두고, 좌우 빈 띠는 가장자리를 거울로 이어 붙인다."""
    t = Image.open(src).convert("RGB")
    w, h = t.size
    y0 = min(int(h * CROP_TOP), h - 500)
    band = t.crop((0, y0, w, y0 + 500))
    if w >= 1024:
        g = band.crop(((w - 1024) // 2, 0, (w - 1024) // 2 + 1024, 500))
    else:
        pad = (1024 - w) // 2
        g = Image.new("RGB", (1024, 500))
        g.paste(band, (pad, 0))
        left = band.crop((0, 0, pad, 500)).transpose(Image.FLIP_LEFT_RIGHT).filter(ImageFilter.GaussianBlur(3))
        right = band.crop((w - (1024 - w - pad), 0, w, 500)).transpose(Image.FLIP_LEFT_RIGHT).filter(ImageFilter.GaussianBlur(3))
        g.paste(left, (0, 0))
        g.paste(right, (pad + w, 0))
    g = title(cover(g, -60, 108), 44, 0.42).convert("RGB")  # 위쪽 물결 위에 얇은 제목 띠 (얼굴은 띠 아래)
    g.save(out, optimize=True)


def main() -> None:
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets/ui/title_bg.png")
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "build/release/store")
    os.makedirs(out_dir, exist_ok=True)
    shutil.copyfile(os.path.join(ROOT, "assets/store/icon_512.png"), os.path.join(out_dir, "icon_512.png"))
    feature(src, os.path.join(out_dir, "feature_1024x500.png"))


if __name__ == "__main__":
    main()
