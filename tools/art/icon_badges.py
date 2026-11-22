"""강화 카드 아이콘 귀퉁이에 붙이는 효과 표지 (코드로 그린다). make_upgrade_icons.py가 쓴다.

표지는 무엇이 좋아지는지 한눈에 보이게 한다: 피해(검), 재사용(시계), 범위(바깥 화살표), 개수(+), 지속(모래시계) 등.
같은 기술의 강화 둘이 함께 나와도 표지가 달라 구별된다.
"""
import math

from PIL import Image, ImageDraw

# 표지 종류 → (바탕색, 기호색)
COLORS = {
    "damage": ((150, 30, 24), (255, 226, 190)),
    "cooldown": ((24, 70, 130), (210, 236, 255)),
    "range": ((28, 100, 52), (220, 255, 220)),
    "width": ((28, 100, 52), (220, 255, 220)),
    "count": ((140, 96, 14), (255, 240, 190)),
    "duration": ((84, 40, 120), (240, 220, 255)),
    "stun": ((120, 96, 10), (255, 245, 150)),
    "slow": ((30, 60, 110), (180, 220, 255)),
    "window": ((110, 80, 20), (255, 232, 170)),
    "heal": ((26, 110, 60), (220, 255, 225)),
    "hp": ((130, 20, 36), (255, 200, 205)),
    "speed": ((20, 100, 110), (210, 255, 250)),
    "charge": ((120, 90, 10), (255, 244, 160)),
    "major": ((120, 80, 0), (255, 232, 120)),
}
GOLD = (232, 190, 96)


def _poly(d, pts, c, s, ox, oy):
    d.polygon([(ox + x * s, oy + y * s) for x, y in pts], fill=c)


def _sym_damage(d, c, s, ox, oy):  # 위로 선 검
    _poly(d, [(0, -0.78), (0.13, -0.55), (0.13, 0.22), (-0.13, 0.22), (-0.13, -0.55)], c, s, ox, oy)
    _poly(d, [(-0.42, 0.22), (0.42, 0.22), (0.42, 0.36), (-0.42, 0.36)], c, s, ox, oy)
    _poly(d, [(-0.08, 0.36), (0.08, 0.36), (0.08, 0.66), (-0.08, 0.66)], c, s, ox, oy)
    d.ellipse([ox - 0.13 * s, oy + 0.62 * s, ox + 0.13 * s, oy + 0.86 * s], fill=c)


def _sym_cooldown(d, c, s, ox, oy):  # 시계 + 되감는 화살
    w = max(2, int(s * 0.12))
    d.arc([ox - 0.62 * s, oy - 0.62 * s, ox + 0.62 * s, oy + 0.62 * s], 300, 210, fill=c, width=w)
    a = math.radians(210)
    tx, ty = ox + 0.62 * s * math.cos(a), oy + 0.62 * s * math.sin(a)
    _poly(d, [(0, -0.26), (0.3, 0.06), (-0.22, 0.14)], c, s, tx, ty)
    d.line([ox, oy, ox, oy - 0.38 * s], fill=c, width=w)
    d.line([ox, oy, ox + 0.3 * s, oy + 0.12 * s], fill=c, width=w)


def _arrow(d, c, s, ox, oy, ang, r0, r1):
    ca, sa = math.cos(ang), math.sin(ang)
    w = max(2, int(s * 0.13))
    d.line([ox + ca * r0 * s, oy + sa * r0 * s, ox + ca * r1 * s, oy + sa * r1 * s], fill=c, width=w)
    hx, hy = ox + ca * (r1 + 0.12) * s, oy + sa * (r1 + 0.12) * s
    px, py = -sa, ca
    d.polygon([(hx, hy), (hx - ca * 0.3 * s + px * 0.2 * s, hy - sa * 0.3 * s + py * 0.2 * s),
               (hx - ca * 0.3 * s - px * 0.2 * s, hy - sa * 0.3 * s - py * 0.2 * s)], fill=c)


def _sym_range(d, c, s, ox, oy):  # 네 방향으로 퍼지는 화살
    for k in range(4):
        _arrow(d, c, s, ox, oy, math.radians(45 + 90 * k), 0.12, 0.5)


def _sym_width(d, c, s, ox, oy):  # 좌우로 벌어지는 화살
    _arrow(d, c, s, ox, oy, 0.0, 0.0, 0.5)
    _arrow(d, c, s, ox, oy, math.pi, 0.0, 0.5)
    d.line([ox - 0.7 * s, oy - 0.45 * s, ox - 0.7 * s, oy + 0.45 * s], fill=c, width=max(2, int(s * 0.08)))
    d.line([ox + 0.7 * s, oy - 0.45 * s, ox + 0.7 * s, oy + 0.45 * s], fill=c, width=max(2, int(s * 0.08)))


def _sym_count(d, c, s, ox, oy):  # +1
    _poly(d, [(-0.66, -0.1), (-0.06, -0.1), (-0.06, 0.1), (-0.66, 0.1)], c, s, ox, oy)
    _poly(d, [(-0.46, -0.3), (-0.26, -0.3), (-0.26, 0.3), (-0.46, 0.3)], c, s, ox, oy)
    _poly(d, [(0.22, -0.48), (0.42, -0.6), (0.48, -0.6), (0.48, 0.6), (0.28, 0.6), (0.28, -0.34), (0.16, -0.28)],
          c, s, ox, oy)


def _sym_duration(d, c, s, ox, oy):  # 모래시계
    _poly(d, [(-0.46, -0.66), (0.46, -0.66), (0.46, -0.54), (-0.46, -0.54)], c, s, ox, oy)
    _poly(d, [(-0.46, 0.54), (0.46, 0.54), (0.46, 0.66), (-0.46, 0.66)], c, s, ox, oy)
    _poly(d, [(-0.36, -0.54), (0.36, -0.54), (0.06, 0), (0.36, 0.54), (-0.36, 0.54), (-0.06, 0)], c, s, ox, oy)


def _star(d, c, s, ox, oy, r):
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        rr = r if k % 2 == 0 else r * 0.45
        pts.append((ox + math.cos(a) * rr * s, oy + math.sin(a) * rr * s))
    d.polygon(pts, fill=c)


def _sym_stun(d, c, s, ox, oy):  # 머리 위 도는 별 셋
    for k, (x, y) in enumerate([(-0.42, 0.1), (0, -0.3), (0.42, 0.1)]):
        _star(d, c, s, ox + x * s, oy + y * s, 0.28 if k == 1 else 0.22)
    d.arc([ox - 0.6 * s, oy - 0.2 * s, ox + 0.6 * s, oy + 0.6 * s], 200, 340, fill=c, width=max(2, int(s * 0.07)))


def _sym_slow(d, c, s, ox, oy):  # 아래로 누르는 겹 갈매기
    for k in range(2):
        y = oy + (k * 0.42 - 0.3) * s
        d.line([ox - 0.5 * s, y - 0.1 * s, ox, y + 0.3 * s, ox + 0.5 * s, y - 0.1 * s], fill=c,
               width=max(2, int(s * 0.15)), joint="curve")


def _sym_window(d, c, s, ox, oy):  # 방패
    _poly(d, [(-0.5, -0.6), (0.5, -0.6), (0.5, 0.0), (0, 0.66), (-0.5, 0.0)], c, s, ox, oy)
    bg = (110, 80, 20)
    _poly(d, [(-0.06, -0.42), (0.06, -0.42), (0.06, 0.32), (-0.06, 0.32)], bg, s, ox, oy)
    _poly(d, [(-0.32, -0.16), (0.32, -0.16), (0.32, -0.04), (-0.32, -0.04)], bg, s, ox, oy)


def _sym_heal(d, c, s, ox, oy):  # 녹색 십자
    _poly(d, [(-0.18, -0.6), (0.18, -0.6), (0.18, 0.6), (-0.18, 0.6)], c, s, ox, oy)
    _poly(d, [(-0.6, -0.18), (0.6, -0.18), (0.6, 0.18), (-0.6, 0.18)], c, s, ox, oy)


def _sym_hp(d, c, s, ox, oy):  # 하트
    r = 0.3 * s
    d.ellipse([ox - 0.6 * s, oy - 0.55 * s, ox - 0.6 * s + 2 * r, oy - 0.55 * s + 2 * r], fill=c)
    d.ellipse([ox + 0.6 * s - 2 * r, oy - 0.55 * s, ox + 0.6 * s, oy - 0.55 * s + 2 * r], fill=c)
    _poly(d, [(-0.58, -0.17), (0.58, -0.17), (0, 0.66)], c, s, ox, oy)


def _sym_speed(d, c, s, ox, oy):  # 오른쪽 겹 갈매기
    for k in range(2):
        x = ox + (k * 0.42 - 0.3) * s
        d.line([x - 0.1 * s, oy - 0.5 * s, x + 0.3 * s, oy, x - 0.1 * s, oy + 0.5 * s], fill=c,
               width=max(2, int(s * 0.15)), joint="curve")


def _sym_charge(d, c, s, ox, oy):  # 번개
    _poly(d, [(0.12, -0.7), (-0.4, 0.08), (-0.04, 0.08), (-0.16, 0.7), (0.4, -0.12), (0.04, -0.12)], c, s, ox, oy)


def _sym_major(d, c, s, ox, oy):  # 큰 별
    _star(d, c, s, ox, oy + 0.04 * s, 0.68)


SYMBOLS = {name[5:]: fn for name, fn in list(globals().items()) if name.startswith("_sym_")}


def badge(kind: str, size: int) -> Image.Image:
    """size×size RGBA 표지. 4배로 그려 줄여서 가장자리가 부드럽다."""
    big = size * 4
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    bg, fg = COLORS[kind]
    m = big * 0.04
    d.ellipse([m, m + big * 0.03, big - m, big - m + big * 0.03], fill=(0, 0, 0, 150))  # 그림자
    d.ellipse([m, m, big - m, big - m], fill=GOLD)
    m2 = big * 0.11
    d.ellipse([m2, m2, big - m2, big - m2], fill=bg)
    SYMBOLS[kind](d, fg, big * 0.3, big / 2, big / 2)
    return img.resize((size, size), Image.LANCZOS)
