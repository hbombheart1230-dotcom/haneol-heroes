"""GPT 그림이 오기 전 임시 그림 (같은 파일 이름으로 덮어쓰면 바로 바뀐다).

  python tools/vfx/make_placeholders.py [--force]   (이미 있는 그림은 건너뜀)
wave_strip / lightning_strip / ink_strip: 가로로 긴 띠 (경로를 따라 늘려 그림), explosion: 유성 충돌,
proj_water / proj_spear / proj_ink: 원거리 탄 (오른쪽 = 날아가는 방향).
"""
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
V = os.path.join(ROOT, "assets/vfx")


def load(name: str) -> Image.Image:
    return Image.open(os.path.join(V, f"{name}.png")).convert("RGBA")


def band(img: Image.Image, top: float, bottom: float, size: tuple) -> Image.Image:
    w, h = img.size
    return img.crop((0, int(h * top), w, int(h * bottom))).resize(size, Image.LANCZOS)


def feather(img: Image.Image, edge: float = 0.14) -> Image.Image:
    """띠·탄 가장자리를 부드럽게 (네모난 잘린 자국이 보이지 않게)."""
    import numpy as np
    a = np.asarray(img).astype(np.float32)
    h, w = a.shape[:2]
    x = np.minimum(np.arange(w) / (w * edge), (w - 1 - np.arange(w)) / (w * edge)).clip(0, 1)
    y = np.minimum(np.arange(h) / (h * edge * 2), (h - 1 - np.arange(h)) / (h * edge * 2)).clip(0, 1)
    a[..., 3] *= np.outer(y, x)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def save(img: Image.Image, name: str) -> None:
    path = os.path.join(V, f"{name}.png")
    if os.path.exists(path) and "--force" not in sys.argv:  # GPT 그림이 들어온 것은 덮어쓰지 않는다
        print("skip", name)
        return
    img = feather(img) if name != "explosion" else img
    img.save(os.path.join(V, f"{name}.png"), optimize=True)
    print("ok", name)


if __name__ == "__main__":
    save(band(load("wave"), 0.0, 0.42, (512, 128)), "wave_strip")
    save(band(load("lightning").rotate(90, expand=True), 0.3, 0.7, (512, 128)), "lightning_strip")
    save(band(load("ink"), 0.3, 0.7, (512, 128)), "ink_strip")
    save(load("quake").resize((256, 256), Image.LANCZOS), "explosion")
    save(band(load("wave"), 0.0, 0.42, (192, 64)), "proj_water")
    save(band(load("lightning").rotate(90, expand=True), 0.35, 0.65, (192, 48)), "proj_spear")
    save(band(load("ink"), 0.35, 0.65, (192, 64)), "proj_ink")
