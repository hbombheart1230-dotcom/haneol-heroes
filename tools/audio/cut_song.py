"""무대 노래를 구간(전주·1절·후렴·후주)으로 잘라 StageSong 데이터를 만들고 무대에 연결한다.

  python tools/audio/cut_song.py <노래 파일> <무대 id> --bpm 92 [--bar-beats 4] [--offset 0.0]
         [--bars intro=0-8,verse=8-24,chorus=24-40,outro=40-end]

- 마디 번호는 0부터, 끝 마디는 빼고 (8-24 = 9번째~24번째 마디). end = 곡 끝.
- --offset: 첫 박(다운비트)이 나오는 시각(초). Suno 곡은 보통 0.
- --bpm auto: 박자를 대충 재서 쓴다 (임시 곡용, 진짜 노래는 숫자로 준다).
- 결과: assets/audio/music/<무대>/{intro,verse,chorus,outro}.ogg, data/songs/<무대>.tres,
  data/stages/<무대>.tres 에 song = ... 연결.
"""
import argparse
import os
import re

import numpy as np
import soundfile as sf

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SECTIONS = ["intro", "verse", "chorus", "outro"]
EDGE_FADE = 0.006  # 자른 자리 딸깍 소리 없애기 (초)


def estimate_bpm(x: np.ndarray, sr: int) -> float:
    """에너지 변화 자기상관으로 60~180 BPM 중 가장 그럴듯한 값."""
    hop = 512
    frames = len(x) // hop
    env = np.array([np.sqrt(np.mean(x[i * hop:(i + 1) * hop] ** 2)) for i in range(frames)])
    onset = np.maximum(np.diff(env), 0)
    onset -= onset.mean()
    ac = np.correlate(onset, onset, mode="full")[len(onset) - 1:]
    fps = sr / hop
    lags = np.arange(len(ac))
    bpm = np.where(lags > 0, 60.0 * fps / np.maximum(lags, 1), 0)
    ok = (bpm >= 60) & (bpm <= 180)
    return float(round(bpm[ok][np.argmax(ac[ok])], 1))


def parse_bars(spec: str) -> dict:
    out = {}
    for part in spec.split(","):
        name, rng = part.split("=")
        a, b = rng.split("-")
        out[name.strip()] = (int(a), None if b == "end" else int(b))
    return out


def cut(x: np.ndarray, sr: int, start: float, end: float) -> np.ndarray:
    seg = x[int(start * sr):int(end * sr)].copy()
    n = max(1, int(EDGE_FADE * sr))
    if len(seg) > 2 * n:
        ramp = np.linspace(0.0, 1.0, n)
        seg[:n] = (seg[:n].T * ramp).T
        seg[-n:] = (seg[-n:].T * ramp[::-1]).T
    return seg


def write_ogg(path: str, seg: np.ndarray, sr: int) -> None:
    """libsndfile은 OGG를 한 번에 크게 쓰면 죽는 경우가 있어 조금씩 나눠 쓴다."""
    ch = 1 if seg.ndim == 1 else seg.shape[1]
    with sf.SoundFile(path, "w", samplerate=sr, channels=ch, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(seg), 4096):
            f.write(seg[i:i + 4096])


def link_stage(stage: str) -> None:
    p = os.path.join(ROOT, f"data/stages/{stage}.tres")
    t = open(p, encoding="utf-8").read()
    t = re.sub(r'path="res://data/songs/[^"]+\.tres" id="song"', f'path="res://data/songs/{stage}.tres" id="song"', t)
    if 'id="song"' not in t:
        t = re.sub(r"(\n\[ext_resource [^\n]*\]\n)(?!\[ext_resource)",
                   rf'\1[ext_resource type="Resource" path="res://data/songs/{stage}.tres" id="song"]\n', t, count=1)
    if "\nsong = " not in t:
        t = t.replace("\nmusic = ", '\nsong = ExtResource("song")\nmusic = ', 1)
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(t)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("stage")
    ap.add_argument("--bpm", default="auto")
    ap.add_argument("--bar-beats", type=int, default=4)
    ap.add_argument("--offset", type=float, default=0.0)
    ap.add_argument("--bars", default="intro=0-8,verse=8-24,chorus=24-40,outro=40-end")
    a = ap.parse_args()
    x, sr = sf.read(a.src, always_2d=False)
    bpm = estimate_bpm(x if x.ndim == 1 else x.mean(axis=1), sr) if a.bpm == "auto" else float(a.bpm)
    bar = 60.0 / bpm * a.bar_beats
    total = len(x) / sr
    bars = parse_bars(a.bars)
    out_dir = os.path.join(ROOT, f"assets/audio/music/{a.stage}")
    os.makedirs(out_dir, exist_ok=True)
    for name in SECTIONS:
        s, e = bars[name]
        start = a.offset + s * bar
        end = total if e is None else a.offset + e * bar
        if start >= total:
            raise SystemExit(f"{name}: 시작 마디 {s}가 곡 길이({total:.1f}s)를 넘습니다")
        seg = cut(x, sr, start, min(end, total))
        write_ogg(os.path.join(out_dir, f"{name}.ogg"), seg, sr)
        print(f"{name}: {start:.2f}s ~ {min(end, total):.2f}s ({(min(end, total) - start) / bar:.1f} bars)")
    ext = ['[ext_resource type="Script" path="res://scripts/data/stage_song.gd" id="1_song"]']
    ext += [f'[ext_resource type="AudioStream" path="res://assets/audio/music/{a.stage}/{n}.ogg" id="{n}"]' for n in SECTIONS]
    body = ['[resource]', 'script = ExtResource("1_song")'] + [f'{n} = ExtResource("{n}")' for n in SECTIONS]
    body += [f"bpm = {bpm}", f"bar_beats = {a.bar_beats}"]
    os.makedirs(os.path.join(ROOT, "data/songs"), exist_ok=True)
    with open(os.path.join(ROOT, f"data/songs/{a.stage}.tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write('[gd_resource type="Resource" script_class="StageSong" format=3]\n\n' + "\n".join(ext) + "\n\n" + "\n".join(body) + "\n")
    link_stage(a.stage)
    print(f"{a.stage}: bpm {bpm}, bar {bar:.2f}s → data/songs/{a.stage}.tres")


if __name__ == "__main__":
    main()
