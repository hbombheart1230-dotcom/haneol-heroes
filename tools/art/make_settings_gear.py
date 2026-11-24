"""설정 단추 그림: 낡은 나무 톱니바퀴 (나뭇결·닳은 가장자리·금 간 자국·무쇠 축과 징).

  python tools/art/make_settings_gear.py   → assets/ui/icons/settings_gear.png (256x256, 투명 바탕)
그림은 코드로만 만든다 (외부 그림 없음). 씨앗이 고정이라 다시 만들어도 같다.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets/ui/icons/settings_gear.png")
S = 256          # 결과 크기
K = 4            # 크게 그려 줄여서 가장자리를 매끄럽게
TEETH = 8
R_OUT, R_BODY, R_HUB, R_HOLE = 0.47, 0.37, 0.15, 0.06  # 크기 대비 반지름
CHIPS = ((0.05, 0.10, 0.05), (2.42, 0.08, 0.035), (4.75, 0.12, 0.06))  # 이빨 깨짐: 각도, 폭, 깊이


def gear_mask(n: int) -> Image.Image:
    """톱니 모양 (이빨은 위가 좁은 사다리꼴, 끝이 조금씩 닳아 둥글다)."""
    m = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(m)
    c = n / 2
    pts = []
    steps = 720
    for i in range(steps):
        a = 2 * math.pi * i / steps
        ph = (a * TEETH / (2 * math.pi)) % 1.0  # 이빨 한 주기 안 위치
        if ph < 0.18 or ph > 0.82:
            r = R_OUT
        elif ph < 0.30:
            r = R_BODY + (R_OUT - R_BODY) * (0.30 - ph) / 0.12
        elif ph > 0.70:
            r = R_BODY + (R_OUT - R_BODY) * (ph - 0.70) / 0.12
        else:
            r = R_BODY
        r *= 1.0 + 0.018 * math.sin(a * 37.0) + 0.012 * math.sin(a * 91.0) + 0.006 * math.sin(a * 211.0)  # 닳아서 울퉁불퉁
        for chip_a, chip_w, chip_d in CHIPS:  # 이빨 끝이 떨어져 나간 자국
            if abs((a - chip_a + math.pi) % (2 * math.pi) - math.pi) < chip_w:
                r = min(r, R_OUT - chip_d)
        pts.append((c + math.cos(a) * r * n, c + math.sin(a) * r * n))
    d.polygon(pts, fill=255)
    d.ellipse([c - R_HOLE * n, c - R_HOLE * n, c + R_HOLE * n, c + R_HOLE * n], fill=0)
    return m.filter(ImageFilter.GaussianBlur(n * 0.002))


def wood(n: int, rng: np.random.Generator) -> np.ndarray:
    """나뭇결: 비스듬한 결 + 옹이 하나 + 잔 얼룩."""
    y, x = np.mgrid[0:n, 0:n] / n
    u = x * 0.35 + y * 0.94
    warp = 0.03 * np.sin(x * 9.0 + 1.3) + 0.02 * np.sin(y * 17.0)
    kx, ky = 0.66, 0.3
    knot = np.exp(-((x - kx) ** 2 + (y - ky) ** 2) / 0.004)
    rings = np.sin((u + warp) * 90.0 + knot * 9.0) * 0.5 + 0.5
    fine = np.sin((u + warp * 2) * 420.0) * 0.5 + 0.5
    noise = rng.normal(0, 1, (n // 8, n // 8))
    noise = np.array(Image.fromarray(((noise - noise.min()) / np.ptp(noise) * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)) / 255.0
    light = 0.55 + 0.25 * rings + 0.08 * fine + 0.15 * (noise - 0.5) - 0.35 * knot
    base = np.array([0.46, 0.35, 0.25])  # 햇볕에 바랜 회갈색
    dark = np.array([0.16, 0.10, 0.07])
    t = np.clip(light, 0, 1)[..., None]
    grime = np.clip((noise - 0.55) * 3.0, 0, 1)[..., None]  # 손때·얼룩
    return (dark + (base - dark) * t * 1.3) * (1.0 - 0.45 * grime)


def main() -> None:
    n = S * K
    rng = np.random.default_rng(7)
    mask = gear_mask(n)
    m = np.array(mask) / 255.0
    rgb = wood(n, rng)
    c = n / 2
    y, x = np.mgrid[0:n, 0:n]
    dist = np.hypot(x - c, y - c) / n
    # 가장자리 어둡게 (닳고 손때 묻음) + 왼쪽 위 빛
    edge = np.array(mask.filter(ImageFilter.GaussianBlur(n * 0.025))) / 255.0
    rgb *= (0.55 + 0.45 * edge)[..., None]
    lit = ((c - x) + (c - y)) / n
    rgb *= (1.0 + 0.25 * lit)[..., None]
    # 이빨 뿌리 쪽 홈 (몸통 둘레 어두운 고리)
    groove = np.exp(-((dist - R_BODY * 0.93) ** 2) / 0.00006)
    rgb *= (1.0 - 0.35 * groove)[..., None]
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    # 금 간 자국 두어 개
    for a0, l in ((0.6, 0.16), (3.6, 0.12), (5.2, 0.09)):
        p = (c + math.cos(a0) * R_BODY * 0.95 * n, c + math.sin(a0) * R_BODY * 0.95 * n)
        a = a0 + math.pi
        for _ in range(6):
            a += rng.uniform(-0.5, 0.5)
            q = (p[0] + math.cos(a) * l * n / 6, p[1] + math.sin(a) * l * n / 6)
            d.line([p, q], fill=(30, 16, 8), width=int(n * 0.006))
            p = q
    # 무쇠 축: 어두운 원판 + 밝은 테 + 징 여섯 개
    hub = R_HUB * n
    d.ellipse([c - hub, c - hub, c + hub, c + hub], fill=(48, 44, 42), outline=(120, 108, 92), width=int(n * 0.012))
    d.ellipse([c - hub * 0.7, c - hub * 0.7, c + hub * 0.7, c + hub * 0.7], outline=(30, 28, 26), width=int(n * 0.006))
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.3
        rr = (R_HUB + R_BODY) * 0.5 * n
        px, py = c + math.cos(a) * rr, c + math.sin(a) * rr
        s = n * 0.022
        d.ellipse([px - s, py - s, px + s, py + s], fill=(70, 64, 58), outline=(25, 22, 20), width=int(n * 0.004))
        d.ellipse([px - s * 0.45, py - s * 0.6, px, py - s * 0.15], fill=(150, 138, 120))
    # 그림자 (오른쪽 아래) 붙여서 투명 바탕에
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (n, n), (0, 0, 0, 150))
    sm = mask.filter(ImageFilter.GaussianBlur(n * 0.012))
    out.paste(shadow, (int(n * 0.012), int(n * 0.018)), sm)
    out.paste(img, (0, 0), mask)
    # 축 구멍은 다시 비운다
    hole = Image.new("L", (n, n), 0)
    ImageDraw.Draw(hole).ellipse([c - R_HOLE * n, c - R_HOLE * n, c + R_HOLE * n, c + R_HOLE * n], fill=255)
    out.paste((0, 0, 0, 0), (0, 0), hole)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.resize((S, S), Image.LANCZOS).save(OUT, optimize=True)
    print(f"{OUT}: {os.path.getsize(OUT) // 1024} KiB")


if __name__ == "__main__":
    main()
