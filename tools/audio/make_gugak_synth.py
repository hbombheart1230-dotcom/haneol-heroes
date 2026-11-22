"""기술 소리 층용 국악기 소리를 합성한다 (녹음 없음 → 라이선스 걱정 없음, 저장소가 만든 자산).

  python tools/audio/make_gugak_synth.py
결과: assets/audio/sfx/
  gugak_buk_<n>.ogg   북 (낮은 가죽 울림: 음높이가 떨어지는 사인 + 짧은 잡음 "둥")
  gugak_jing_<n>.ogg  징 (비조화 배음, 느린 감쇠, 살짝 올라가는 "웅")
  gugak_pyeon_<n>.ogg 편경 (돌 경쇠: 높은 비조화 배음, 맑게 짧게)
  gugak_gaya_<n>.ogg  가야금 (카플러스-스트롱 뜯음 + 뒤에 농현 떨림)
녹음된 국악기(공유마당 장구·꽹과리)는 tools/audio/cut_gugak.py. 이건 그 녹음이 없는 악기를 채우는 임시 소리다.
"""
import os

import numpy as np
import soundfile as sf

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio", "sfx")
RATE = 32000  # 다른 효과음과 같다
RNG = np.random.default_rng(7)


def t_axis(sec: float) -> np.ndarray:
    return np.arange(int(sec * RATE)) / RATE


def env(t: np.ndarray, attack: float, decay: float) -> np.ndarray:
    a = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    return a * np.exp(-t / decay)


def lowpass(x: np.ndarray, k: float) -> np.ndarray:
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += k * (v - acc)
        y[i] = acc
    return y


def buk(f0: float) -> np.ndarray:
    t = t_axis(0.55)
    f = f0 * (1.0 + 0.5 * np.exp(-t / 0.03))  # 치는 순간 높았다가 떨어진다
    body = np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(t, 0.002, 0.16)
    thump = lowpass(RNG.standard_normal(len(t)), 0.08) * env(t, 0.001, 0.025) * 3.0
    return body + thump


def jing(f0: float) -> np.ndarray:
    t = t_axis(1.6)
    out = np.zeros_like(t)
    bend = 1.0 + 0.015 * (1.0 - np.exp(-t / 0.4))  # "웅" 하고 살짝 올라간다
    for ratio, amp, dec in [(1.0, 1.0, 0.9), (1.52, 0.45, 0.6), (2.07, 0.3, 0.45), (2.61, 0.18, 0.35), (3.43, 0.1, 0.25)]:
        for det in (-0.6, 0.6):  # 맥놀이
            out += amp * 0.5 * np.sin(2 * np.pi * np.cumsum(f0 * ratio * bend + det) / RATE) * np.exp(-t / dec)
    hit = lowpass(RNG.standard_normal(len(t)), 0.2) * env(t, 0.001, 0.02)
    return out * np.clip(t / 0.012, 0.0, 1.0) + hit * 0.5


def pyeon(f0: float) -> np.ndarray:
    t = t_axis(0.7)
    out = np.zeros_like(t)
    for ratio, amp, dec in [(1.0, 1.0, 0.35), (2.76, 0.5, 0.18), (5.40, 0.25, 0.09), (8.93, 0.12, 0.05)]:
        out += amp * np.sin(2 * np.pi * f0 * ratio * t) * np.exp(-t / dec)
    click = RNG.standard_normal(len(t)) * env(t, 0.0005, 0.004) * 0.3
    return out * np.clip(t / 0.002, 0.0, 1.0) + click


def gaya(f0: float) -> np.ndarray:
    n = int(0.9 * RATE)
    period = int(RATE / f0)
    buf = lowpass(RNG.uniform(-1, 1, period), 0.5)
    out = np.zeros(n)
    for i in range(n):  # 카플러스-스트롱 (뜯은 줄)
        out[i] = buf[i % period]
        buf[i % period] = 0.996 * 0.5 * (buf[i % period] + buf[(i + 1) % period])
    t = t_axis(0.9)
    vib = 1.0 + 0.012 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.2) / 0.2, 0.0, 1.0)  # 농현
    idx = np.clip(np.cumsum(vib) - 1, 0, n - 1)
    return np.interp(idx, np.arange(n), out)


def finish(x: np.ndarray, gain: float) -> np.ndarray:
    x = x / (np.abs(x).max() + 1e-9) * gain
    fade = min(len(x), int(0.04 * RATE))
    x[-fade:] *= np.linspace(1.0, 0.0, fade)
    return x.astype(np.float32)


JOBS = {
    "gugak_buk": [lambda: buk(72.0), lambda: buk(64.0)],
    "gugak_jing": [lambda: jing(196.0)],
    "gugak_pyeon": [lambda: pyeon(784.0), lambda: pyeon(880.0)],
    "gugak_gaya": [lambda: gaya(293.7), lambda: gaya(392.0)],
}
GAIN = {"gugak_buk": 0.95, "gugak_jing": 0.85, "gugak_pyeon": 0.7, "gugak_gaya": 0.8}


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for kind, makers in JOBS.items():
        for n, make in enumerate(makers, 1):
            path = os.path.join(OUT, f"{kind}_{n}.ogg")
            sf.write(path, finish(make(), GAIN[kind]), RATE, format="OGG", subtype="VORBIS")
            print(path)


if __name__ == "__main__":
    main()
