"""민요 멜로디 안내 음원 만들기 (Suno 커버에 올려 멜로디를 잡는 용도): 가야금풍 뜯는 소리 + 북 장단.

  python tools/audio/melody_guide.py ganggangsullae   → build/music_src/guides/ganggangsullae.wav (+ .ogg)

- 전통 민요 멜로디는 저작권이 없다. 이 파일은 그 멜로디를 단순 합성한 것이라 다른 음원을 쓰지 않는다.
- 멜로디는 아래 SONGS에 음표로 적는다 (기억에 의존한 초안 → 사용자가 귀로 확인하고 고친다).
  음표: (음 이름, 길이[박]) — 음 이름 "A3"·"C4" 등, "-" 는 쉼. 12/8 장단이면 1박 = 점4분.
"""
import os
import sys

import numpy as np
import soundfile as sf

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SR = 44100
NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def freq(name: str) -> float:
    step = NOTE[name[0]] + (1 if "#" in name else 0)
    octave = int(name[-1])
    return 440.0 * 2 ** ((step + 12 * (octave + 1) - 69) / 12)


def pluck(f: float, dur: float, bright: float = 0.996) -> np.ndarray:
    """가야금처럼 뜯는 소리 (Karplus-Strong) + 살짝 꺾는 농현."""
    n = int(dur * SR)
    period = max(2, int(SR / f))
    buf = np.random.uniform(-1, 1, period)
    out = np.empty(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = bright * 0.5 * (buf[i % period] + buf[(i + 1) % period])
    t = np.arange(n) / SR
    out *= np.exp(-t * 2.2)
    return out


def flute(f: float, dur: float) -> np.ndarray:
    """대금처럼 부는 소리: 사인 + 숨소리 + 느린 떨림."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.3, 0, 1)
    tone = np.sin(2 * np.pi * f * np.cumsum(vib) / SR) + 0.25 * np.sin(4 * np.pi * f * np.cumsum(vib) / SR)
    breath = np.random.normal(0, 0.04, n)
    env = np.clip(t / 0.06, 0, 1) * np.clip((dur - t) / 0.08, 0, 1)
    return (tone + breath) * env * 0.5


def buk(dur: float, strong: bool) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * (70 + 60 * np.exp(-t * 30)) * t) * np.exp(-t * (9 if strong else 14))
    slap = np.random.normal(0, 1, n) * np.exp(-t * 60) * 0.3
    return (body + slap) * (0.9 if strong else 0.5)


def render(spec: dict) -> np.ndarray:
    beat = 60.0 / spec["bpm"]
    total = sum(d for _, d in spec["melody"]) * beat + 2.0
    mix = np.zeros(int(total * SR))
    t = 0.0
    for name, d in spec["melody"]:
        if name != "-":
            voice = pluck if spec.get("voice", "pluck") == "pluck" else flute
            s = voice(freq(name), d * beat + 0.4) * 0.6
            i = int(t * SR)
            mix[i:i + len(s)] += s[:len(mix) - i]
        t += d * beat
    # 북 장단: 한 마디(bar_beats 박)마다 첫 박 세게, 나머지 박 약하게 (12/8 = 박마다 3분할 중 첫 소리)
    beats = int(sum(d for _, d in spec["melody"]))
    for b in range(beats):
        strong = b % spec["bar_beats"] == 0
        s = buk(0.5, strong)
        i = int(b * beat * SR)
        mix[i:i + len(s)] += s[:len(mix) - i] * 0.5
    mix /= max(np.abs(mix).max(), 1e-6) * 1.1
    return mix


## 자진 강강술래 (전라남도 해안 민요, 메기고 받기). 계면조 (라·도·레·미·솔), 12/8 자진모리, 96 BPM.
## 메기는 소리 2마디 + 받는 소리 "강강술래" 1마디 형식을 되풀이.
CALL_1 = [("A4", 1), ("A4", 0.5), ("C5", 0.5), ("D5", 1), ("C5", 1)]
CALL_2 = [("E5", 1), ("D5", 0.5), ("C5", 0.5), ("A4", 1), ("C5", 1)]
CALL_3 = [("D5", 1), ("E5", 0.5), ("D5", 0.5), ("C5", 1), ("A4", 1)]
RESPONSE = [("E5", 1), ("E5", 1), ("D5", 0.5), ("C5", 0.5), ("A4", 1)]  # 강 - 강 - 술 래 -
SONGS = {
    "ganggangsullae": {
        "bpm": 96, "bar_beats": 4,
        "melody": [("-", 4)] + (CALL_1 + RESPONSE + CALL_2 + RESPONSE + CALL_3 + RESPONSE + CALL_1 + RESPONSE) * 2,
    },
}


def main(name: str) -> None:
    spec = SONGS[name]
    audio = render(spec)
    out = os.path.join(ROOT, "build/music_src/guides")
    os.makedirs(out, exist_ok=True)
    sf.write(os.path.join(out, f"{name}.wav"), audio, SR, subtype="PCM_16")
    print(f"{name}: {len(audio) / SR:.1f}s → build/music_src/guides/{name}.wav")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "ganggangsullae")
