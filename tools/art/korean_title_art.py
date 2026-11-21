"""키아트의 영문 로고(HANEOL HEROES)를 덮고 붓글씨 한글 제목을 얹는다 (화면 글자는 모두 한글).

  python tools/art/korean_title_art.py
글꼴: assets/fonts/DeogonPrincess.ttf (국립한글박물관 덕온공주체, 게임 글꼴과 같다)
만드는 것: assets/ui/title_bg.png (720x1280), assets/ui/splash.png (450x800), assets/store/feature_graphic_1024x500.png
"""
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GOLD = (226, 178, 92)
PAPER = (242, 232, 210)
FONT = os.path.join(ROOT, "assets/fonts/DeogonPrincess.ttf")


def cover(img: Image.Image, y0: int, y1: int) -> Image.Image:
    """y0~y1을 어둡게 덮는다 (가운데는 거의 불투명, 위아래 끝만 부드럽게)."""
    w, _ = img.size
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    band = y1 - y0
    for i in range(band):
        t = i / band
        edge = min(t, 1 - t) * 8
        d.line([(0, y0 + i), (w, y0 + i)], fill=(14, 10, 10, int(252 * min(1.0, edge))))
    return Image.alpha_composite(img.convert("RGBA"), ov)


def title(img: Image.Image, cy: int, scale: float) -> Image.Image:
    w, _ = img.size
    d = ImageDraw.Draw(img)
    big = ImageFont.truetype(FONT, int(132 * scale))
    small = ImageFont.truetype(FONT, int(34 * scale))
    for txt, font, col, dy, stroke in (("한얼 영웅들", big, GOLD, 0, int(6 * scale)),
                                       ("역사의 전장에 선 네 영웅", small, PAPER, int(95 * scale), int(3 * scale))):
        bb = d.textbbox((0, 0), txt, font=font, stroke_width=stroke)
        x = (w - (bb[2] - bb[0])) / 2 - bb[0]
        y = cy + dy - (bb[3] - bb[1]) / 2 - bb[1]
        d.text((x, y), txt, font=font, fill=col, stroke_width=stroke, stroke_fill=(10, 6, 6))
    sz = int(70 * scale)  # 붉은 낙관 (한·얼)
    sx, sy = w / 2 + int(270 * scale), cy - int(40 * scale)
    d.rectangle([sx, sy, sx + sz, sy + sz], fill=(176, 30, 24))
    sf = ImageFont.truetype(FONT, int(30 * scale))
    for i, ch in enumerate("한얼"):
        bb = d.textbbox((0, 0), ch, font=sf)
        d.text((sx + sz / 2 - (bb[2] - bb[0]) / 2 - bb[0], sy + 6 * scale + i * 30 * scale - bb[1]), ch,
               font=sf, fill=(250, 235, 220))
    return img


def main() -> None:
    k = Image.open(os.path.join(ROOT, "assets/concept/keyart/keyart_portrait.png")).convert("RGB")
    w, h = k.size
    cw = int(h * 9 / 16)
    x0 = (w - cw) // 2
    t = k.crop((x0, 0, x0 + cw, h)).resize((720, 1280), Image.LANCZOS)
    t = title(cover(t, int(1280 * 0.63), int(1280 * 0.93)), int(1280 * 0.75), 1.0).convert("RGB")
    t.save(os.path.join(ROOT, "assets/ui/title_bg.png"), optimize=True)
    t.resize((450, 800), Image.LANCZOS).quantize(80, method=Image.Quantize.MEDIANCUT,
                                                 dither=Image.Dither.FLOYDSTEINBERG).save(
        os.path.join(ROOT, "assets/ui/splash.png"), optimize=True)
    lw = Image.open(os.path.join(ROOT, "assets/concept/keyart/keyart_landscape.png")).convert("RGB")
    W, H = lw.size
    ch = int(W * 500 / 1024)
    y0 = (H - ch) // 2
    g = lw.crop((0, y0, W, y0 + ch)).resize((1024, 500), Image.LANCZOS)
    g = title(cover(g, int(500 * 0.58), 580), int(500 * 0.78), 0.62).convert("RGB")  # 아래 끝 번짐은 화면 밖
    g.save(os.path.join(ROOT, "assets/store/feature_graphic_1024x500.png"), optimize=True)


if __name__ == "__main__":
    main()
