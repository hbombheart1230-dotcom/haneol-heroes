"""무대 배경 지도: GPT 원본(assets/concept/stages/maps/<무대>.png)을 게임용으로 다듬고 무대 데이터에 넣는다.

  python tools/stages/make_stages.py      # (무대 데이터를 다시 만들었다면 먼저)
  python tools/art/make_backgrounds.py

- PLAY: 원본에서 걸어 다닐 곳(벽·난간·하늘 안쪽) 픽셀 영역. 이 영역이 전장(Arena.rect)에 꼭 맞게 지도 위치를 정한다.
- 2배 Lanczos 확대 + 살짝 선명하게 → assets/backgrounds/<무대>.png
- 지도 밖(카메라가 전장 끝에서 보는 곳)은 floor_base 단색: 지도 가장자리 평균색으로 맞춘다.
"""
import os
import re

from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ARENA = (-900.0, -1400.0, 1800.0, 2800.0)  # scripts/world/arena.gd rect
UPSCALE = 2

## 무대 id: (원본에서 걸어 다닐 영역 x0, y0, x1, y1 [원본 픽셀], 소품을 가장자리에서 띄울 거리, 흩뿌릴 소품 밀도)
PLAY = {
    "manchuria_395": ((40, 150, 990, 1500), 260.0, 2.0),
    "gyeongbokgung_1433": ((120, 330, 900, 1420), 260.0, 1.5),
    "chochungdo": ((0, 0, 1024, 1536), 300.0, 2.0),
    "hansan_1592": ((60, 200, 965, 1470), 260.0, 2.0),
}


def place(play: tuple, size: tuple) -> tuple:
    """걸을 영역이 전장을 덮도록 (짧은 쪽에 맞춰 키움) 지도 전체의 월드 Rect2를 돌려준다."""
    x0, y0, x1, y1 = play
    ax, ay, aw, ah = ARENA
    k = max(aw / (x1 - x0), ah / (y1 - y0))
    cx, cy = (x0 + x1) / 2 * k, (y0 + y1) / 2 * k  # 걸을 영역 가운데 (지도 왼쪽 위 기준, 월드 단위)
    return (round(ax + aw / 2 - cx), round(ay + ah / 2 - cy), round(size[0] * k), round(size[1] * k))


def edge_color(im: Image.Image) -> str:
    w, h = im.size
    band = 24
    px = []
    for box in ((0, 0, w, band), (0, h - band, w, h), (0, 0, band, h), (w - band, 0, w, h)):
        px += list(im.crop(box).resize((8, 8)).getdata())
    r, g, b = (sum(p[i] for p in px) / len(px) / 255 for i in range(3))
    return f"Color({r:.3f}, {g:.3f}, {b:.3f}, 1)"


def upsert(text: str, key: str, value: str) -> str:
    line = f"{key} = {value}"
    if re.search(rf"^{key} = .*$", text, flags=re.M):
        return re.sub(rf"^{key} = .*$", line, text, flags=re.M)
    return text.rstrip("\n") + "\n" + line + "\n"


def make(sid: str) -> str:
    play, inset, density = PLAY[sid]
    src = Image.open(os.path.join(ROOT, f"assets/concept/stages/maps/{sid}.png")).convert("RGB")
    big = src.resize((src.width * UPSCALE, src.height * UPSCALE), Image.LANCZOS)
    big = big.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
    os.makedirs(os.path.join(ROOT, "assets/backgrounds"), exist_ok=True)
    big.save(os.path.join(ROOT, f"assets/backgrounds/{sid}.png"), optimize=True)
    x, y, w, h = place(play, src.size)
    tres = os.path.join(ROOT, f"data/stages/{sid}.tres")
    t = open(tres, encoding="utf-8").read()
    t = upsert(t, "background_path", f'"res://assets/backgrounds/{sid}.png"')
    t = upsert(t, "background_rect", f"Rect2({x}, {y}, {w}, {h})")
    t = upsert(t, "prop_inset", f"{inset}")
    t = upsert(t, "picture_props_per_mpx", f"{density}")
    t = upsert(t, "floor_base", edge_color(src))
    t = upsert(t, "grass_per_mpx", "0.0")  # 지도에 이미 그려져 있다
    t = upsert(t, "rock_per_mpx", "0.0")
    with open(tres, "w", encoding="utf-8", newline="\n") as f:
        f.write(t)
    return f"{sid}: map Rect2({x}, {y}, {w}, {h}), x{w / src.width:.2f}"


if __name__ == "__main__":
    for sid in PLAY:
        print(make(sid))
