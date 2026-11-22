"""적 시트 용량: 원본 PNG와 가져온 텍스처(.ctex, APK에 들어가는 것) 바이트를 동작별로 적는다.

python tools/shots/sheet_sizes.py waegun_soldier waegun_gunner ... > 결과.txt
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def sizes(name: str) -> dict:
    out = {}
    for png in sorted((ROOT / "assets/sprites" / name).glob("*.png")):
        imp = png.with_suffix(".png.import")
        ctex = 0
        if imp.exists():
            m = re.search(r'dest_files=\["res://(.*?)"', imp.read_text(encoding="utf-8"))
            if m and (ROOT / m.group(1)).exists():
                ctex = (ROOT / m.group(1)).stat().st_size
        out[png.stem] = (png.stat().st_size, ctex)
    return out


if __name__ == "__main__":
    for n in sys.argv[1:]:
        s = sizes(n)
        print(f"{n}: png {sum(v[0] for v in s.values()):,} ctex {sum(v[1] for v in s.values()):,}  "
              + " ".join(f"{k}={v[1] // 1024}K" for k, v in s.items()))
