"""여는 영상을 Theora .ogv 로 만든다 (APK 용량, docs/research/apk_size.md).

  python tools/video/encode_opening.py [원본 mp4] [출력 ogv] [--kbps 1800] [--width 544]

- 원본: build/video_src/opening.mp4 (Suno 뮤직비디오, 768×1344 10초, 저장소에 넣지 않음).
- 소리는 넣지 않는다 (제목 음악이 따로 시작, 6da20af). 화면비 4:7 유지, 크기는 16의 배수에 가깝게.
- 720×1260·약 4.3 Mbps(5.45 MB) → 544×952·1.8 Mbps(약 2.3 MB, 1.2 Mbps 는 두루마리 글씨가 뭉개져 뺌). 화면은 세로 720 논리 폭이라 544 는 1.3배 확대.
"""
import argparse
import os
import subprocess

import imageio_ffmpeg

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def encode(src: str, out: str, kbps: int, width: int) -> int:
    height = round(width * 7 / 4 / 8) * 8
    cmd = [imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error", "-i", src, "-an",
           "-vf", f"scale={width}:{height}:flags=lanczos", "-c:v", "libtheora", "-b:v", f"{kbps}k", "-r", "24", out]
    subprocess.run(cmd, check=True)
    return os.path.getsize(out)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src", nargs="?", default=os.path.join(ROOT, "build/video_src/opening.mp4"))
    ap.add_argument("out", nargs="?", default=os.path.join(ROOT, "assets/video/opening.ogv"))
    ap.add_argument("--kbps", type=int, default=1800)
    ap.add_argument("--width", type=int, default=544)
    a = ap.parse_args()
    if not os.path.exists(a.src):
        raise SystemExit(f"원본이 없습니다: {a.src}")
    n = encode(a.src, a.out, a.kbps, a.width)
    print(f"{a.out}: {n / 1e6:.2f} MB")


if __name__ == "__main__":
    main()
