"""앱 아이콘: 저장소에 있는 그림만 잘라 겹쳐 만든다 (생성형 도구 없음 — 자르기·겹치기·색 맞춤).

사용자 결정 2026-11-26: "영웅 한 명 얼굴 크게". 얼굴은 젊은 순신(새 원화 assets/concept/redesign/heroes/yi_sun_sin.png),
배경은 순신 이야기 그림의 밤바다(assets/intro/yi_sun_sin/s*.png)를 흐리고 먹빛으로 눌러 쓴다.

  python tools/art/make_app_icon.py --candidates            # 후보 넷 + 비교 시트 (build/preview/app_icon/)
  python tools/art/make_app_icon.py --apply <후보 이름> [--store <폴더>]  # 고른 후보로 아이콘 한 벌 쓰기:
      assets/ui/icon/adaptive_foreground_432.png  (안드로이드 적응형 앞 층, 투명 바탕, 얼굴은 안전 원 안)
      assets/ui/icon/adaptive_background_432.png (적응형 뒤 층, 밤바다)
      assets/ui/icon/main_192.png                  (기본 아이콘, 둥근 사각)
      assets/ui/icon/project_256.png               (편집기·데스크톱)
      build/release/store/icon_512.png             (Play 스토어 512×512, 32비트 PNG, 알파 없음;
                                                    worktree에서 돌리면 --store C:/Haneol-Heroes/build/release/store)

적응형 아이콘: 108dp 중 가운데 72dp가 보이고 66dp 원이 안전 영역 → 432px 기준 보이는 칸 288, 안전 원 지름 264.
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageOps

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HERO = "assets/concept/redesign/heroes/yi_sun_sin.png"  # 1254², 흰 바탕, 젊은 얼굴 (얼굴 가운데 약 638,185)
PREVIEW = "build/preview/app_icon"
CURRENT = "assets/ui/icon/main_192.png"

# 후보: 영웅 그림에서 자를 정사각형 (가운데 x, y, 한 변), 배경 그림과 그 안 자를 자리 (가운데 x, y, 한 변 비율),
# 배경 밝기, 먹빛 둥근 테두리 여부, 설명.
CANDIDATES = {
    "a_face": {"crop": (638, 190, 230), "bg": None, "dim": 1.0,
               "note": "얼굴 아주 크게 (갓 챙은 잘림), 뒤는 단색 먹빛 — 48px에서 가장 잘 읽힘"},
    "b_hat": {"crop": (636, 190, 330), "bg": ("assets/intro/yi_sun_sin/s5.png", (0.5, 0.42, 0.62)), "dim": 0.55,
              "note": "갓 챙 전체 + 붉은 끈 + 얼굴, 뒤는 해일 밤바다"},
    "c_plume": {"crop": (600, 190, 470), "bg": ("assets/intro/yi_sun_sin/s3.png", (0.5, 0.35, 0.7)), "dim": 0.5,
                "note": "공작 깃·붉은 깃털까지 넣은 머리 + 어깨, 뒤는 소용돌이 물결과 달"},
    "d_wave": {"crop": (636, 200, 360), "bg": ("assets/intro/yi_sun_sin/s5.png", (0.45, 0.45, 0.55)), "dim": 0.95,
               "note": "갓·얼굴, 뒤 물결을 밝게 (푸른 바다가 보이게)"},
}


def _load(rel):
    return Image.open(os.path.join(ROOT, rel)).convert("RGBA")


def cutout(img: Image.Image, tol: int = 26, min_area: int = 900) -> Image.Image:
    """흰 바탕을 지운다: 가장자리와 이어진 거의 흰 칸, 그리고 갇힌 흰 칸 중 min_area px보다 큰 덩어리
    (붉은 끈과 목 사이 틈). 눈 흰자위 같은 작은 흰 칸은 그대로."""
    import numpy as np
    from scipy import ndimage
    a = np.asarray(img.convert("RGB")).astype(np.int16)
    white = (a >= 255 - tol).all(axis=2)
    lab, n = ndimage.label(white)
    sizes = ndimage.sum(white, lab, range(1, n + 1))
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    drop = np.zeros(n + 1, bool)
    for k in range(1, n + 1):
        drop[k] = k in edge or sizes[k - 1] >= min_area
    bg = drop[lab]
    alpha = Image.fromarray(np.where(bg, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
    out = img.copy()
    out.putalpha(ImageChops.multiply(alpha, img.getchannel("A")))
    return out


def _square(img, cx, cy, side):
    return img.crop((cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2))


def background(spec, size: int, dim: float) -> Image.Image:
    if spec is None:  # 단색 먹빛 + 아래 푸른 물결 띠 (이야기 그림 s5 아래쪽을 띠로)
        bg = Image.new("RGBA", (size, size), (16, 20, 30, 255))
        wave = _load("assets/intro/yi_sun_sin/s5.png")
        band = wave.crop((0, 820, 1024, 1180)).resize((size, int(size * 0.42)), Image.LANCZOS)
        band = ImageEnhance.Brightness(band).enhance(0.55)
        fade = Image.linear_gradient("L").resize(band.size)  # 위는 투명, 아래로 진하게
        band.putalpha(fade)
        bg.alpha_composite(band, (0, size - band.height))
        return bg
    rel, (fx, fy, fs) = spec
    src = _load(rel)
    side = int(min(src.size) * fs)
    cx, cy = int(src.width * fx), int(src.height * fy)
    bg = _square(src, cx, cy, side).resize((size, size), Image.LANCZOS).filter(ImageFilter.GaussianBlur(size / 160))
    bg = ImageEnhance.Brightness(bg).enhance(dim)
    vign = Image.radial_gradient("L").resize((size, size))  # 가장자리 먹빛 (가운데 얼굴이 뜨게)
    dark = Image.new("RGBA", (size, size), (8, 10, 16, 255))
    return Image.composite(dark, bg, ImageEnhance.Brightness(vign).enhance(0.9))


def hero_layer(name: str, size: int, cut: Image.Image) -> Image.Image:
    cx, cy, side = CANDIDATES[name]["crop"]
    return _square(cut, cx, cy, side).resize((size, size), Image.LANCZOS)


def compose(name: str, size: int, cut: Image.Image) -> Image.Image:
    c = CANDIDATES[name]
    img = background(c["bg"], size, c["dim"])
    fg = hero_layer(name, size, cut)
    glow = fg.getchannel("A").filter(ImageFilter.GaussianBlur(size / 60))  # 얼굴 둘레 옅은 먹 그림자
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow.putalpha(glow.point(lambda v: int(v * 0.6)))
    img.alpha_composite(shadow)
    img.alpha_composite(fg)
    return img


def rounded(img: Image.Image, r: float = 0.22) -> Image.Image:
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, img.width - 1, img.height - 1], int(img.width * r), fill=255)
    out = img.copy()
    out.putalpha(m)
    return out


def circle(img: Image.Image, frac: float = 1.0) -> Image.Image:
    """가운데 frac 지름 원만 남김 (frac 0.61 = 적응형 안전 원 66/108)."""
    m = Image.new("L", img.size, 0)
    d = img.width * frac
    o = (img.width - d) / 2
    ImageDraw.Draw(m).ellipse([o, o, o + d, o + d], fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), m)
    return out


def candidates() -> None:
    os.makedirs(os.path.join(ROOT, PREVIEW), exist_ok=True)
    cut = cutout(_load(HERO))
    cols = []
    cur = _load(CURRENT).resize((512, 512), Image.LANCZOS)
    cols.append(("지금", cur))
    for n in CANDIDATES:
        im = compose(n, 512, cut)
        im.convert("RGB").save(os.path.join(ROOT, PREVIEW, f"{n}_512.png"))
        cols.append((n, im))
    cell, small = 300, 48
    sheet = Image.new("RGB", (len(cols) * (cell + 20) + 20, cell * 2 + small * 2 + 120), (235, 230, 220))
    d = ImageDraw.Draw(sheet)
    from PIL import ImageFont
    font = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 14) if os.path.exists("C:/Windows/Fonts/malgun.ttf") else None
    for i, (n, im) in enumerate(cols):
        x = 20 + i * (cell + 20)
        d.text((x, 2), n, fill=(0, 0, 0), font=font)
        sheet.paste(rounded(im.resize((cell, cell), Image.LANCZOS)), (x, 20), rounded(im.resize((cell, cell), Image.LANCZOS)))
        c = circle(im.resize((cell, cell), Image.LANCZOS), 1.0)
        sheet.paste(c, (x, 30 + cell), c)
        s = rounded(im.resize((small, small), Image.LANCZOS))
        sheet.paste(s, (x, 50 + cell * 2), s)
        s2 = circle(im.resize((small, small), Image.LANCZOS), 0.61 / 0.667)  # 적응형: 보이는 칸 안의 안전 원
        sheet.paste(s2, (x + small + 20, 50 + cell * 2), s2)
        safe = circle(im.resize((cell // 3, cell // 3), Image.LANCZOS), 0.61)
        sheet.paste(safe, (x + small * 2 + 50, 40 + cell * 2), safe)
    sheet.save(os.path.join(ROOT, PREVIEW, "compare.png"))
    print("candidates ->", PREVIEW)


def apply(name: str, store: str = "") -> None:
    cut = cutout(_load(HERO))
    icon_dir = os.path.join(ROOT, "assets/ui/icon")
    # 적응형: 앞 층은 얼굴만 (투명 바탕), 보이는 288칸 안에 그림 전체가 들어가게 가운데 288에 둔다.
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    fg.alpha_composite(hero_layer(name, 288, cut), (72, 72))
    fg.save(os.path.join(icon_dir, "adaptive_foreground_432.png"))
    c = CANDIDATES[name]
    bg = background(c["bg"], 432, c["dim"])
    bg.convert("RGB").save(os.path.join(icon_dir, "adaptive_background_432.png"))
    rounded(compose(name, 192, cut)).save(os.path.join(icon_dir, "main_192.png"))
    rounded(compose(name, 256, cut)).save(os.path.join(icon_dir, "project_256.png"))
    store = store or os.path.join(ROOT, "build/release/store")
    os.makedirs(store, exist_ok=True)
    compose(name, 512, cut).convert("RGB").save(os.path.join(store, "icon_512.png"))
    print("applied", name)


if __name__ == "__main__":
    if "--apply" in sys.argv:
        st = sys.argv[sys.argv.index("--store") + 1] if "--store" in sys.argv else ""
        apply(sys.argv[sys.argv.index("--apply") + 1], st)
    else:
        candidates()
