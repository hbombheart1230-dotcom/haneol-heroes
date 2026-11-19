"""게임에서 쓰는 글자만 남긴 글꼴 만들기 (한글 글꼴은 원본이 수 MB라 APK 용량 때문에).

게임 안 글자는 모두 data/·scripts/·scenes/에서 나오므로 그 파일들의 글자 + ASCII만 남긴다.
글자를 새로 쓰면 다시 실행한다 (tests/test_fonts.gd가 빠진 글자를 잡는다).

  python tools/fonts/subset_fonts.py <원본 폴더>
원본 (OFL, Google Fonts): NanumBrushScript-Regular.ttf (제목 붓글씨), SongMyung-Regular.ttf (본문, 옛 목판 인쇄풍)
"""
import glob
import os
import sys

from fontTools import subset

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FONTS = {"NanumBrushScript-Regular.ttf": "brush_title.ttf", "SongMyung-Regular.ttf": "jeongeum_body.ttf"}
EXTRA = "0123456789%+-×·•●○◆★…~!?.,:;'\"()[]/<>「」『』"


def used_chars() -> str:
    chars = set(chr(c) for c in range(0x20, 0x7F)) | set(EXTRA)
    for pat in ("data/**/*.tres", "scripts/**/*.gd", "scenes/**/*.tscn"):
        for f in glob.glob(os.path.join(ROOT, pat), recursive=True):
            with open(f, encoding="utf-8") as fh:
                chars |= set(fh.read())
    return "".join(sorted(c for c in chars if ord(c) >= 0x20))


def main(src_dir: str) -> None:
    text = used_chars()
    for src, dst in FONTS.items():
        opts = subset.Options()
        opts.layout_features = ["*"]
        opts.hinting = False
        font = subset.load_font(os.path.join(src_dir, src), opts)
        sub = subset.Subsetter(opts)
        sub.populate(text=text)
        sub.subset(font)
        out = os.path.join(ROOT, "assets", "fonts", dst)
        subset.save_font(font, out, opts)
        print(f"{dst}: {os.path.getsize(out) // 1024} KiB, {len(text)} chars")


if __name__ == "__main__":
    main(sys.argv[1])
