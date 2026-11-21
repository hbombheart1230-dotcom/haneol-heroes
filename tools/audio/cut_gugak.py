"""국악 덧소리 자르기: 공유마당 장구·꽹과리 연주 녹음에서 센 한 타씩 골라 짧은 효과음으로 만든다.

  python tools/audio/cut_gugak.py <원본 폴더>
원본 (공공누리 제1유형, (재)전주정보문화산업진흥원, 공유마당 — README 외부 자산 표):
  janggu.mp3   = 전통악기_장구_치다_보통속도_Ver.1_MKH418_ST_192 (wrtSn=13287485)
  kkwaenggwari.mp3 = 전통악기_꽹과리_치다_연주_MKH418_ST_192 (wrtSn=13287481)
결과: assets/audio/sfx/gugak_big_<n>.ogg (꽹과리, 큰 타격), gugak_kill_<n>.ogg (장구 "덩", 정예·보스 처치)
타는 소리 시작점(온셋)을 찾아 앞뒤가 비어 있는 센 타를 고르고, 끝을 부드럽게 줄인 뒤 크기를 맞춘다.
"""
import os
import subprocess
import sys

import imageio_ffmpeg
import numpy as np
import soundfile as sf

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RATE = 32000  # 다른 효과음과 같다 (prepare_audio.py SFX_RATE)
## 결과 종류 → (원본 파일, 고를 타 수, 길이 초, 다음 타까지 최소 간격 초, 크기)
JOBS = {
    "gugak_big": ("kkwaenggwari.mp3", 2, 0.35, 0.12, 0.85),
    "gugak_kill": ("janggu.mp3", 2, 0.7, 0.25, 0.95),
}


def decode(path: str) -> np.ndarray:
    exe = imageio_ffmpeg.get_ffmpeg_exe()
    raw = subprocess.run([exe, "-v", "quiet", "-i", path, "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()


def onsets(x: np.ndarray, hop: int = 256) -> list:
    """에너지가 갑자기 오르는 곳 [(표본 위치, 그 뒤 최고 크기)]."""
    frames = len(x) // hop
    e = np.array([np.sqrt(np.mean(x[i * hop:(i + 1) * hop] ** 2)) for i in range(frames)])
    flux = np.maximum(np.diff(e, prepend=0.0), 0.0)
    thr = flux.mean() + 2.5 * flux.std()
    out = []
    i = 1
    while i < frames - 1:
        if flux[i] > thr and flux[i] >= flux[i - 1] and flux[i] >= flux[i + 1]:
            start = max(i - 1, 0) * hop
            out.append((start, float(np.abs(x[start:start + hop * 8]).max())))
            i += 6
        else:
            i += 1
    return out


def pick(x: np.ndarray, count: int, length: float, gap: float) -> list:
    """앞 gap초가 조용하고 다음 타가 length 안에 겹치지 않는 센 타 count개."""
    hits = onsets(x)
    starts = [s for s, _ in hits]
    good = []
    for k, (s, peak) in enumerate(hits):
        prev_ok = k == 0 or s - starts[k - 1] >= gap * RATE
        next_ok = k == len(hits) - 1 or starts[k + 1] - s >= length * RATE * 0.8
        if prev_ok and next_ok:
            good.append((peak, s))
    good.sort(reverse=True)
    return sorted(s for _, s in good[:count])


def shape(seg: np.ndarray, gain: float) -> np.ndarray:
    n = len(seg)
    fade_in = min(int(0.003 * RATE), n)
    fade_out = int(n * 0.45)
    seg = seg.copy()
    seg[:fade_in] *= np.linspace(0.0, 1.0, fade_in)
    seg[-fade_out:] *= np.linspace(1.0, 0.0, fade_out) ** 2
    return seg / max(np.abs(seg).max(), 1e-6) * gain


def main(src: str) -> None:
    out_dir = os.path.join(ROOT, "assets/audio/sfx")
    for kind, (name, count, length, gap, gain) in JOBS.items():
        x = decode(os.path.join(src, name))
        chosen = pick(x, count, length, gap)
        for n, s in enumerate(chosen, 1):
            seg = shape(x[s:s + int(length * RATE)], gain)
            out = os.path.join(out_dir, f"{kind}_{n}.ogg")
            sf.write(out, seg, RATE, format="OGG", subtype="VORBIS")
            print(f"{kind}_{n}.ogg  from {name} @ {s / RATE:.2f}s  {len(seg) / RATE:.2f}s")


if __name__ == "__main__":
    main(sys.argv[1])
