"""앱 아이콘을 입장 그림(수묵 키아트)에서 만든다: 네 영웅이 모인 윗부분을 정사각형으로 잘라 크기별로 저장.

  python tools/art/make_icons.py
원본: assets/concept/keyart/keyart_portrait.png
만드는 것: assets/ui/icon/main_192.png, adaptive_background_432.png (전체 그림), adaptive_foreground_432.png (투명),
         project_256.png, assets/store/icon_512.png
작은 크기에서도 보이게 대비를 조금 올린다 (수묵 그림은 옅어서).
"""
import os

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets/concept/keyart/keyart_portrait.png")
SAFE = 0.78  # 적응형 아이콘에서 그림을 넣는 가운데 크기 (432 대비)
TOP = 0.08  # 정사각형을 그림 높이의 이 비율 위치부터 자른다 (머리띠·관이 잘리지 않게)


def square() -> Image.Image:
    k = Image.open(SRC).convert("RGB")
    w, h = k.size
    side = w
    y0 = int(h * TOP)
    sq = k.crop((0, y0, side, y0 + side))
    sq = ImageEnhance.Contrast(sq).enhance(1.18)
    return ImageEnhance.Color(sq).enhance(1.15)


def save(img: Image.Image, rel: str, size: int) -> None:
    out = os.path.join(ROOT, rel)
    img.resize((size, size), Image.LANCZOS).save(out, optimize=True)
    print(rel, size)


def main() -> None:
    sq = square()
    save(sq, "assets/ui/icon/main_192.png", 192)
    save(sq, "assets/ui/icon/project_256.png", 256)
    save(sq, "assets/store/icon_512.png", 512)
    # 적응형 아이콘: 기기는 432 중 가운데 약 2/3만 보여 준다 (둥글게·네모로 잘림).
    # 그래서 네 영웅을 가운데 SAFE 크기에 넣고, 바깥은 같은 그림을 흐리게 키워 채운다 (이음매는 부드럽게).
    bg = sq.resize((432, 432), Image.LANCZOS).filter(ImageFilter.GaussianBlur(14))
    inner = int(432 * SAFE)
    art = sq.resize((inner, inner), Image.LANCZOS)
    m = Image.new("L", (inner, inner), 0)
    ImageDraw.Draw(m).ellipse([inner * 0.02, inner * 0.02, inner * 0.98, inner * 0.98], fill=255)
    m = m.filter(ImageFilter.GaussianBlur(inner * 0.06))
    o = (432 - inner) // 2
    bg.paste(art, (o, o), m)
    bg.save(os.path.join(ROOT, "assets/ui/icon/adaptive_background_432.png"), optimize=True)
    Image.new("RGBA", (432, 432), (0, 0, 0, 0)).save(os.path.join(ROOT, "assets/ui/icon/adaptive_foreground_432.png"))
    print("adaptive 432")


if __name__ == "__main__":
    main()
