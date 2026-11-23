"""HUD 영웅 초상: 지금 게임 속 모델의 원화(새 디자인, assets/concept/redesign/heroes/<id>.png)에서 얼굴을 잘라
흰 바탕을 투명하게 한 정사각형 PNG로 만든다 (HeroBadge가 원으로 그린다).

  python tools/art/make_portraits.py
출력: assets/ui/portraits/<id>.png (SIZE px). assets/concept는 APK에서 빠지므로 게임용 사본을 여기에 둔다.
옛 영웅 카드 그림(assets/ui/heroes, 수염 난 순신 등)은 쓰지 않는다 — 3D 모델과 얼굴이 다르다.
"""
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SIZE = 192
# 원화(1254²)에서 얼굴 가운데 (x, y)와 자를 한 변 (px). 머리 장식이 조금 보이고 얼굴이 원 가운데에 오게.
FACES = {
    "yi_sun_sin": (619, 212, 210),
    "gwanggaeto": (648, 240, 210),
    "sejong": (627, 190, 210),
    "shin_saimdang": (585, 165, 210),
}
WHITE = 236  # 이보다 밝은 무채색이 가장자리와 이어져 있으면 바탕으로 보고 투명하게


def portrait(hero: str) -> Image.Image:
    x, y, s = FACES[hero]
    src = Image.open(os.path.join(ROOT, f"assets/concept/redesign/heroes/{hero}.png")).convert("RGBA")
    im = src.crop((x - s // 2, y - s // 2, x + s // 2, y + s // 2)).resize((SIZE, SIZE), Image.LANCZOS)
    r, g, b, a = im.split()
    key = Image.merge("RGB", (r, g, b)).convert("L").point(lambda v: 255 if v >= WHITE else 0)
    sat = Image.merge("RGB", (r, g, b)).convert("HSV").split()[1].point(lambda v: 255 if v < 18 else 0)
    cand = Image.composite(key, Image.new("L", im.size, 0), sat)
    for xy in [(i, 0) for i in range(SIZE)] + [(0, i) for i in range(SIZE)] + [(SIZE - 1, i) for i in range(SIZE)]:
        if cand.getpixel(xy) == 255:  # 가장자리와 이어진 흰 바탕만 (흰 깃·동정은 남긴다)
            ImageDraw.floodfill(cand, xy, 128)
    bg = cand.point(lambda v: 255 if v == 128 else 0).filter(ImageFilter.GaussianBlur(1.2))
    im.putalpha(Image.eval(bg, lambda v: 255 - v))
    return im


def main() -> None:
    out = os.path.join(ROOT, "assets/ui/portraits")
    os.makedirs(out, exist_ok=True)
    for hero in FACES:
        portrait(hero).save(os.path.join(out, f"{hero}.png"), optimize=True)
        print(hero)


if __name__ == "__main__":
    main()
