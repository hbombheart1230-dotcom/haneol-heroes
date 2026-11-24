"""노랫소리 끔용 반주 만들기: 원곡에서 목소리 없는 구간만 모아 한 줄로 잇고, 끝→처음이 이어지는 반복 ogg로 쓴다.

  python tools/audio/make_vocal_off.py [원곡 폴더(기본 build/music_src)]
- 재료(구간 계획): tools/audio/vocal_off_plan.json (곡·초·상대 세기). 구간은 마디 경계에서, 양끝 한 마디씩 안쪽으로 잘라 둔 것.
- 이음매: 같은 판끼리는 1.5초 겹쳐 넘기고, 판이 다르면 1.5초 페이드 아웃 → 0.3초 틈 → 페이드 인.
  끝에서 처음으로 돌아가는 자리는 끝 1.5초를 처음 1.5초와 겹쳐 (한 파일이 끊김 없이 돈다).
- 원음 그대로 (분리·필터 없음), 구간끼리 음량만 맞춘다.
- 결과: assets/audio/music/<무대>/instrumental_stage.ogg, instrumental_boss.ogg (StageSong.instrumental_stage / _boss).
- 짧은 곡을 Suno 반주 판으로 바꿀 때는 같은 이름으로 파일만 갈아 끼우면 된다.
"""
import json
import os
import sys

import librosa
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from cut_song import write_ogg  # noqa: E402  같은 쓰기 (조금씩 나눠 쓰기)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SR = 44100
XF = 1.5
GAP = 0.3
TARGET_RMS = 0.12


def _fade(n: int, kind: str) -> np.ndarray:
    t = np.linspace(0, 1, n)[:, None]
    return np.sqrt(t) if kind == "in" else np.sqrt(1 - t)


def _rms(x: np.ndarray) -> float:
    return float(np.sqrt((x ** 2).mean() + 1e-12))


def _load(src_dir: str, name: str, cache: dict) -> np.ndarray:
    if name not in cache:
        x, _ = librosa.load(os.path.join(src_dir, name), sr=SR, mono=False)
        cache[name] = x.T if x.ndim > 1 else np.stack([x, x], 1)
    return cache[name]


def assemble(sections: list, src_dir: str, cache: dict) -> np.ndarray:
    out = None
    prev = None
    n = int(XF * SR)
    for sec in sections:
        x = _load(src_dir, sec["src"], cache)[int(sec["t0"] * SR):int(sec["t1"] * SR)].copy()
        x *= TARGET_RMS * 10 ** (sec["lvl_db"] / 20) / _rms(x)
        if out is None:
            out = x
        elif sec["src"] == prev and len(out) > n and len(x) > n:
            out[-n:] = out[-n:] * _fade(n, "out") + x[:n] * _fade(n, "in")
            out = np.concatenate([out, x[n:]])
        else:
            out[-n:] *= _fade(n, "out")
            x[:n] *= _fade(n, "in")
            out = np.concatenate([out, np.zeros((int(GAP * SR), 2)), x])
        prev = sec["src"]
    return out


def to_loop(x: np.ndarray) -> np.ndarray:
    """끝 1.5초를 처음 1.5초와 겹쳐 끝→처음이 끊김 없이 이어지게 (그만큼 짧아진다)."""
    n = int(XF * SR)
    body = x[:-n].copy()
    body[:n] = x[-n:] * _fade(n, "out") + x[:n] * _fade(n, "in")
    peak = float(np.abs(body).max())
    return body / max(1.0, peak / 0.95)


def main(src_dir: str) -> None:
    plan = json.load(open(os.path.join(os.path.dirname(__file__), "vocal_off_plan.json"), encoding="utf-8"))
    cache: dict = {}
    for stage, kinds in plan["stages"].items():
        for kind, sections in kinds.items():
            loop = to_loop(assemble(sections, src_dir, cache))
            path = os.path.join(ROOT, f"assets/audio/music/{stage}/instrumental_{kind}.ogg")
            write_ogg(path, loop, SR)
            print(f"{stage}/{kind}: {len(loop) / SR:.1f}s, {len(sections)}구간")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "music_src"))
