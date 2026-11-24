"""보스 판 노래 자르기: 같은 아리랑을 국악기로 세고 빠르게 다시 만든 곡(Suno)에서 뒷부분 힘찬 구간을 반복용으로 잘라
무대 노래(StageSong)의 boss 구간으로 넣는다. 보스가 나오면 이 구간으로 겹쳐 넘어간다.

  python tools/audio/cut_boss.py <원본 폴더>      (폴더 안: <무대 id>.mp3, build/music_src/boss)
- 박(beat)을 찾아 첫 박을 첫 마디로 보고, 아래 표의 마디 번호(4박 = 한 마디, 8마디 단위)로 자른다.
- 곡이 끝으로 갈수록 세지므로 뒤쪽 85~110초를 쓴다 (보스전 동안 반복).
- 결과: assets/audio/music/<무대>/boss.ogg, data/songs/<무대>.tres 에 boss·boss_bpm.
프롬프트·설정: docs/song_prompts.md 7-1절.
"""
import os
import re
import sys

import librosa
import numpy as np
import soundfile as sf

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.dirname(__file__))
from cut_song import cut, write_ogg  # noqa: E402  같은 자르기·쓰기 (끝 딸깍 없애기, 조금씩 쓰기)

## 무대 → (시작 마디, 끝 마디). 8마디 단위.
LOOPS = {
    "hansan_1592": (68, 124),
    "manchuria_395": (56, 96),
    "gyeongbokgung_1433": (48, 104),
    "chochungdo": (60, 124),
}


def bar_times(path: str) -> tuple:
    y, sr = librosa.load(path, sr=22050, mono=True)
    tempo, beats = librosa.beat.beat_track(y=y, sr=sr, units="time")
    return float(np.atleast_1d(tempo)[0]), beats[::4]


def link_song(stage: str, bpm: float) -> None:
    p = os.path.join(ROOT, f"data/songs/{stage}.tres")
    t = open(p, encoding="utf-8").read()
    line = f'[ext_resource type="AudioStream" path="res://assets/audio/music/{stage}/boss.ogg" id="boss"]'
    if 'id="boss"' not in t:
        t = t.replace(f'path="res://assets/audio/music/{stage}/outro.ogg" id="outro"]',
                      f'path="res://assets/audio/music/{stage}/outro.ogg" id="outro"]\n{line}', 1)
    t = re.sub(r"\nboss = [^\n]*", "", t)
    t = re.sub(r"\nboss_bpm = [^\n]*", "", t)
    t = t.rstrip("\n") + f'\nboss = ExtResource("boss")\nboss_bpm = {bpm:.1f}\n'
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(t)


def main(src: str) -> None:
    for stage, (a, b) in LOOPS.items():
        path = os.path.join(src, f"{stage}.mp3")
        bpm, bars = bar_times(path)
        x, sr = sf.read(path, always_2d=False)
        start, end = float(bars[a]), float(bars[min(b, len(bars) - 1)])
        seg = cut(x, sr, start, end)
        write_ogg(os.path.join(ROOT, f"assets/audio/music/{stage}/boss.ogg"), seg, sr)
        link_song(stage, bpm)
        print(f"{stage}: {bpm:.1f} BPM, bars {a}-{b} = {start:.1f}s ~ {end:.1f}s ({end - start:.0f}s)")


if __name__ == "__main__":
    main(sys.argv[1])
