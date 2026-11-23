"""무대·메뉴 음악을 다시 인코딩해 APK 를 줄인다 (128 → 약 95 kbps, docs/research/apk_size.md).

  python tools/audio/music_diet.py           assets/audio/music/**/*.ogg 중 110 kbps 넘는 것만 다시 쓴다
  python tools/audio/music_diet.py --check   바꿀 것이 있으면 목록을 찍고 1로 끝남

- 자르기 도구(cut_song.py·cut_boss.py)와 같은 write_ogg·OGG_LEVEL 을 쓴다. 새로 자른 곡은 처음부터 이 크기.
- 샘플 수가 그대로라 반복·구간 전환 시점(StageSong bpm·마디)이 바뀌지 않는다 (쓴 뒤 길이를 확인).
- 이미 줄인 파일은 건너뛰므로 여러 번 돌려도 같다.
"""
import glob
import os
import sys

import soundfile as sf

sys.path.insert(0, os.path.dirname(__file__))
from cut_song import ROOT, write_ogg  # noqa: E402

MAX_KBPS = 110.0


def kbps(path: str) -> float:
    info = sf.info(path)
    return os.path.getsize(path) * 8 / info.duration / 1000


def targets() -> list:
    files = sorted(glob.glob(os.path.join(ROOT, "assets/audio/music/**/*.ogg"), recursive=True))
    return [p for p in files if kbps(p) > MAX_KBPS]


def reencode(path: str) -> tuple:
    x, sr = sf.read(path, always_2d=False)
    before = os.path.getsize(path)
    tmp = path + ".tmp.ogg"
    write_ogg(tmp, x, sr)
    y, _ = sf.read(tmp, always_2d=False)
    if len(y) != len(x):
        os.remove(tmp)
        raise SystemExit(f"{path}: 길이가 바뀜 ({len(x)} → {len(y)} 샘플)")
    os.replace(tmp, path)
    return before, os.path.getsize(path)


def main(argv: list) -> int:
    todo = targets()
    if "--check" in argv:
        for p in todo:
            print(f"{kbps(p):.0f} kbps  {os.path.relpath(p, ROOT)}")
        return 1 if todo else 0
    tb = ta = 0
    for p in todo:
        b, a = reencode(p)
        tb += b
        ta += a
        print(f"{b / 1e6:5.2f} → {a / 1e6:5.2f} MB  {os.path.relpath(p, ROOT)}")
    print(f"합계 {tb / 1e6:.2f} → {ta / 1e6:.2f} MB ({len(todo)} 파일)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
