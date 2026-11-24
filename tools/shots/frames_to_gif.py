"""finisher_gif.gd 출력 폴더 → GIF (실제 간격, 느리게 보기 배율) + 칸 띠 PNG.
python tools/shots/frames_to_gif.py <폴더> <출력 gif> [느리게=2.0] [띠 칸 간격 ms=50] [제목]
표시: 노랑 테 = 몹이 피해를 입은 칸, 파랑 = 타 시작, 빨강 = 4타(마무리) 시작.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

COLORS = {"h": (255, 216, 50), "s": (80, 150, 255), "f": (255, 64, 64)}


def load(folder: Path):
    rows = []
    for i, line in enumerate((folder / "times.txt").read_text().splitlines()):
        parts = line.split(" ", 1)
        rows.append((int(parts[0]), parts[1] if len(parts) > 1 else "", folder / f"f_{i:03d}.png"))
    return rows


def mark(img: Image.Image, flags: str, t: int, title: str) -> Image.Image:
    im = img.convert("RGB")
    d = ImageDraw.Draw(im)
    for k, ch in enumerate(c for c in "fhs" if c in flags):
        d.rectangle([k * 5, k * 5, im.width - 1 - k * 5, im.height - 1 - k * 5], outline=COLORS[ch], width=5)
    d.text((10, im.height - 18), f"{t} ms  {title}", fill=(255, 255, 255))
    return im


def main() -> None:
    folder = Path(sys.argv[1])
    out = Path(sys.argv[2])
    slow = float(sys.argv[3]) if len(sys.argv) > 3 else 2.0
    step = int(sys.argv[4]) if len(sys.argv) > 4 else 50
    title = sys.argv[5] if len(sys.argv) > 5 else ""
    rows = load(folder)
    frames, durs = [], []
    for i, (t, flags, p) in enumerate(rows):
        nxt = rows[i + 1][0] if i + 1 < len(rows) else t + 33
        frames.append(mark(Image.open(p), flags, t, title))
        durs.append(max(int((nxt - t) * slow), 20))
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=durs, loop=0)
    # 띠: step ms마다 가장 가까운 칸, 그 사이 표시는 모아서
    cells = []
    t_end = rows[-1][0]
    j = 0
    for t in range(0, t_end + 1, step):
        flags = ""
        while j < len(rows) and rows[j][0] <= t:
            flags += rows[j][1]
            last = rows[j]
            j += 1
        if j == 0:
            continue
        cells.append(mark(Image.open(last[2]), flags, t, ""))
    w, h = cells[0].size
    strip = Image.new("RGB", (w * len(cells), h))
    for k, c in enumerate(cells):
        strip.paste(c, (k * w, 0))
    strip.save(out.with_suffix(".png"))


if __name__ == "__main__":
    main()
