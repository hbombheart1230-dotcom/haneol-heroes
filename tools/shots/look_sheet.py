"""찍은 화면 여러 장을 가로로 나란히 붙이고 칸마다 이름·측정값을 적는다 (look_shot.gd 결과 비교용).

python tools/shots/look_sheet.py <출력 png> <이름>=<그림 png>[@측정용 png] ...
측정용 그림을 주면 그 값을, 아니면 보이는 그림의 값을 적는다 (HUD 위 5%·아래 10% 제외).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from measure_look import measure  # noqa: E402

FONT = "C:/Windows/Fonts/malgunbd.ttf"


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def main(out, cells):
    shots = []
    for c in cells:
        name, paths = c.split("=", 1)
        show, _, meas = paths.partition("@")
        shots.append((name, Image.open(show).convert("RGB"), measure(meas or show, 0.05, 0.1)))
    w, h = shots[0][1].size
    head = 150
    sheet = Image.new("RGB", (w * len(shots), h + head), (14, 12, 10))
    d = ImageDraw.Draw(sheet)
    for i, (name, im, m) in enumerate(shots):
        sheet.paste(im, (i * w, head))
        d.text((i * w + 14, 10), name, font=font(30), fill=(240, 220, 170))
        d.text((i * w + 14, 56), "밝기 %.2f  편차 %.2f" % (m["mean"], m["std"]), font=font(24), fill=(220, 220, 220))
        d.text((i * w + 14, 92), "상위5%% %.2f  채도 %.2f" % (m["p95"], m["sat"]), font=font(24), fill=(220, 220, 220))
    sheet.save(out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
