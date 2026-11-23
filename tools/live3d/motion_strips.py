"""motion_pick.py 결과로 슬롯마다 나란히 띠: 맨 위 = 지금 구간, 아래 = 후보 (칸 8개, 오른쪽 아래 45° 방향).
python tools/live3d/motion_strips.py <scan 폴더> <picks.json> <출력 폴더>
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

COLS = 8
SCALE = 1.5
DIR = 1  # 0 = 오른쪽, 시계 방향 45°씩 → 1 = 오른쪽 아래
FONT = "assets/fonts/DeogonPrincess.ttf"
FILES = {"1타": "hit1", "2타": "hit2", "3타": "hit3", "마무리": "finisher", "반격": "counter", "뒤로 빠지기": "backoff"}


def row(folder, clip, start, end, label, font):
    meta = json.load(open(os.path.join(folder, clip + ".json"), encoding="utf-8"))
    im = Image.open(os.path.join(folder, clip + ".png")).convert("RGBA")
    c = meta["cell"]
    s = int(c * SCALE)
    out = Image.new("RGBA", (s * COLS + 260, s), (222, 214, 196, 255))
    for i in range(COLS):
        t = start + (end - start) * i / (COLS - 1)
        f = min(int(round(t * meta["fps"])), meta["frames"] - 1)
        cell = im.crop((f * c, DIR * c, (f + 1) * c, (DIR + 1) * c)).resize((s, s))
        out.alpha_composite(cell, (260 + i * s, 0))
        ImageDraw.Draw(out).text((262 + i * s, 2), f"{t:.2f}", fill=(60, 50, 40, 255))
    ImageDraw.Draw(out).multiline_text((6, 8), label, fill=(30, 25, 20, 255), font=font, spacing=4)
    return out


def main():
    folder, picks, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
    os.makedirs(out_dir, exist_ok=True)
    p = json.load(open(picks, encoding="utf-8"))
    font = ImageFont.truetype(FONT, 20)
    for slot, cands in p["slots"].items():
        rows = []
        cur = p["current"].get(slot)
        if cur:
            rows.append(row(folder, cur["clip"], cur["start"], cur["end"],
                            f"지금 {slot}\n{cur['clip']}\n{cur['start']}-{cur['end']}s\n기울기 {cur['tilt']:.0f}° 이동 {cur['shift']:.2f}\n칼끝 호 {cur['arc']:.0f}°", font))
        for k, c in enumerate(cands):
            rows.append(row(folder, c["clip"], c["start"], c["end"],
                            f"후보 {k + 1}\n{c['clip']}\n{c['start']}-{c['end']}s 맞닿음 {c['strike']}\n기울기 {c['tilt']:.0f}° 이동 {c['shift']:.2f}\n칼끝 호 {c['arc']:.0f}°", font))
        sheet = Image.new("RGBA", (rows[0].width, sum(r.height for r in rows) + 4 * len(rows)), (90, 80, 70, 255))
        y = 0
        for r in rows:
            sheet.alpha_composite(r, (0, y))
            y += r.height + 4
        sheet.convert("RGB").save(os.path.join(out_dir, f"pick_{FILES[slot]}.png"))
    # 1·2·3타를 한 동작에서 이어 자른 묶음
    rows = []
    for ch in p["chains"]:
        cuts = ch["cuts"]
        for i in range(3):
            h = ch["hits"][i]
            rows.append(row(folder, ch["clip"], cuts[i], cuts[i + 1],
                            f"{ch['clip']} {i + 1}타\n{cuts[i]}-{cuts[i + 1]}s 맞닿음 {h['strike']}\n기울기 {h['tilt']:.0f}° 이동 {h['shift']:.2f}\n칼끝 호 {h['arc']:.0f}°", font))
    sheet = Image.new("RGBA", (rows[0].width, sum(r.height for r in rows) + 4 * len(rows)), (90, 80, 70, 255))
    y = 0
    for r in rows:
        sheet.alpha_composite(r, (0, y))
        y += r.height + 4
    sheet.convert("RGB").save(os.path.join(out_dir, "pick_chain123.png"))
    print("done", out_dir)


if __name__ == "__main__":
    main()
