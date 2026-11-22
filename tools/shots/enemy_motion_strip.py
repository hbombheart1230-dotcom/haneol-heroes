"""적 동작 프레임 띠: 구운 시트(assets/sprites/<이름>/*.png)를 한 장으로 모아 본다.

python tools/shots/enemy_motion_strip.py <이름> <출력.png> [--dir=1]
줄 = 동작 (지정 방향의 모든 칸, strike 칸은 빨간 테두리), 마지막 두 줄 = 대기·공격 strike 칸의 8방향.
시트 칸 크기·칸 수·strike 는 <이름>.tres 에서 읽는다 (Godot 없이 돌아감).
"""
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
BG = (58, 64, 70, 255)


def read_set(name: str) -> dict:
    text = (ROOT / "assets/sprites" / name / f"{name}.tres").read_text(encoding="utf-8")

    def arr(key: str) -> list:
        m = re.search(rf"^{key} = \w+\[?\w*\]?\(\[?(.*?)\]?\)$", text, re.M)
        return [x.strip().strip('"') for x in m.group(1).split(",")] if m else []

    frame = int(re.search(r"^frame_size = (\d+)", text, re.M).group(1))
    return {"frame": frame, "names": arr("anim_names"), "counts": [int(x) for x in arr("frame_counts")],
            "fps": [float(x) for x in arr("fps")], "strikes": [int(x) for x in arr("strike_frames")]}


def cell(sheet: Image.Image, frame: int, row: int, col: int) -> Image.Image:
    return sheet.crop((col * frame, row * frame, (col + 1) * frame, (row + 1) * frame))


def build(name: str, out: Path, d: int = 1) -> Path:
    s = read_set(name)
    f = s["frame"]
    sheets = {n: Image.open(ROOT / "assets/sprites" / name / f"{n}.png").convert("RGBA") for n in s["names"]}
    width = max(max(s["counts"]), 8)
    rows = len(s["names"]) + 2
    label_w = 90
    img = Image.new("RGBA", (label_w + width * f, rows * f), BG)
    draw = ImageDraw.Draw(img)
    for r, n in enumerate(s["names"]):
        cnt, strike = s["counts"][r], s["strikes"][r]
        draw.text((4, r * f + 4), f"{n}\n{cnt}f {s['fps'][r]:.0f}fps\n{cnt / s['fps'][r]:.2f}s", fill="white")
        for c in range(cnt):
            img.alpha_composite(cell(sheets[n], f, d, c), (label_w + c * f, r * f))
            if c == strike:
                draw.rectangle((label_w + c * f, r * f, label_w + (c + 1) * f - 1, (r + 1) * f - 1), outline="red", width=3)
    idle_i = s["names"].index("idle") if "idle" in s["names"] else 0
    atk = "attack" if "attack" in s["names"] else s["names"][0]
    atk_i = s["names"].index(atk)
    for k, (n, col) in enumerate([(s["names"][idle_i], 0), (atk, max(s["strikes"][atk_i], 0))]):
        r = len(s["names"]) + k
        draw.text((4, r * f + 4), f"{n} 8dir\nframe {col}", fill="yellow")
        for dd in range(8):
            img.alpha_composite(cell(sheets[n], f, dd, col), (label_w + dd * f, r * f))
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out)
    return out


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--"))
    print(build(args[0], Path(args[1]), int(opts.get("dir", "1"))))
