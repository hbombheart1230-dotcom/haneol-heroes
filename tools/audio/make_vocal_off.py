"""노랫소리 끔용 반주 만들기: 원곡에서 목소리 없는 구간만 모아 바짝 이어 붙이고, 끝→처음도 틈 없이 이어지는 반복 ogg로 쓴다.

  python tools/audio/make_vocal_off.py [원곡 폴더(기본 build/music_src)] [--out 폴더]
- 재료(구간 계획): tools/audio/vocal_off_plan.json (곡·초). 구간 앞뒤의 조용한 꼬리와 구간 안의 긴 조용한 부분(0.5초 넘게 -13dB 아래)은 잘라 낸다.
- 이음매는 모두 박자 위에서 0.3초 같은 세기(등전력) 겹침으로 바로 잇는다. 페이드 아웃·틈 없음.
  각 구간은 박자 경계에서 자르고 양끝 0.15초를 더 얹어 겹친다. 박자는 원곡 전체에서 한 번 찾는다(librosa).
- 판(v1/v2)이 다르면 빠르기·조성이 튀므로 같은 판끼리 모아 붙인다 (판이 바뀌는 자리는 곡당 한 번). 둘째 판의 첫머리(전주)는 둘째 판에 다른 구간이 있으면 뺀다.
- 구간 음량은 모두 같은 RMS로 맞춘다 (조용한 구간이 꺼지지 않게). 원음 그대로 (분리·필터 없음).
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
XF = 0.3  # 이음매 겹침 (초)
TARGET_RMS = 0.12
QUIET_DB = -13.0  # 구간 세기(상위 10%)보다 이만큼 낮으면 조용한 부분
QUIET_RUN = 0.5  # 이보다 길게 조용하면 잘라 낸다 (초). 앞뒤 꼬리는 길이와 상관없이 뺀다
MIN_PIECE = 2.0
HOP = 0.05


def _rms(x: np.ndarray) -> float:
    return float(np.sqrt((x ** 2).mean() + 1e-12))


def _load(src_dir: str, name: str, cache: dict) -> np.ndarray:
    if name not in cache:
        x, _ = librosa.load(os.path.join(src_dir, name), sr=SR, mono=False)
        cache[name] = x.T if x.ndim > 1 else np.stack([x, x], 1)
    return cache[name]


def _beats(src_dir: str, name: str, cache: dict) -> np.ndarray:
    key = "beats:" + name
    if key not in cache:
        mono = _load(src_dir, name, cache).mean(1)
        y = librosa.resample(mono, orig_sr=SR, target_sr=22050)
        _, fr = librosa.beat.beat_track(y=y, sr=22050, units="time")
        cache[key] = np.asarray(fr, dtype=float)
    return cache[key]


def _group(name: str) -> str:
    return "v2" if "_v2." in name else "v1"


def split_quiet(x: np.ndarray, t0: float) -> list:
    """구간을 앞뒤 조용한 꼬리와 안쪽 긴 조용한 부분에서 잘라 (시작, 끝) 초 목록으로 (원곡 시각)."""
    hop = int(HOP * SR)
    n = len(x) // hop
    if n < 2:
        return []
    env = np.array([_rms(x[i * hop:(i + 1) * hop]) for i in range(n)])
    db = 20 * np.log10(env / (np.percentile(env, 90) + 1e-9) + 1e-9)
    loud = db > QUIET_DB
    need = int(QUIET_RUN / HOP)
    pieces, start, quiet = [], None, 0  # start: 지금 조각의 첫 시끄러운 칸
    last = None  # 지금 조각의 마지막 시끄러운 칸
    for i in range(n):
        if loud[i]:
            if start is None:
                start = i
            last = i
            quiet = 0
        else:
            quiet += 1
            if start is not None and quiet >= need:  # 긴 조용한 부분: 조각을 닫는다
                pieces.append((t0 + start * HOP, t0 + (last + 1) * HOP))
                start = None
    if start is not None:
        pieces.append((t0 + start * HOP, t0 + (last + 1) * HOP))
    return pieces


def snap(beats: np.ndarray, a: float, b: float):
    """(a, b)를 안쪽 박 위로 맞춘다. 박이 모자라면 None."""
    inside = beats[(beats >= a) & (beats <= b)]
    if len(inside) < 3 or inside[-1] - inside[0] < MIN_PIECE:
        return None
    return float(inside[0]), float(inside[-1])


def pieces_of(sections: list, src_dir: str, cache: dict) -> list:
    """계획 구간 → 잘라 다듬은 조각 목록 [{src, group, a, b}] (박 위, 원곡 시각)."""
    out = []
    for sec in sections:
        x = _load(src_dir, sec["src"], cache)
        seg = x[int(sec["t0"] * SR):int(sec["t1"] * SR)]
        beats = _beats(src_dir, sec["src"], cache)
        for a, b in split_quiet(seg, sec["t0"]):
            sn = snap(beats, a, b)
            if sn:
                out.append({"src": sec["src"], "group": _group(sec["src"]), "a": sn[0], "b": sn[1], "intro": sec["t0"] < 1.0})
    return out


def order(pieces: list) -> list:
    """같은 판끼리 모아 시간순. 조각이 더 긴 판이 먼저. 둘째 판의 짧은 전주(8초 아래)는 다른 조각이 있으면 뺀다."""
    groups: dict = {}
    for p in pieces:
        groups.setdefault(p["group"], []).append(p)
    names = sorted(groups, key=lambda g: -sum(p["b"] - p["a"] for p in groups[g]))
    res = []
    for gi, g in enumerate(names):
        items = sorted(groups[g], key=lambda p: (p["src"], p["a"]))
        if gi > 0 and any(not p["intro"] for p in items):
            items = [p for p in items if not (p["intro"] and p["b"] - p["a"] < 8.0)]
        res += items
    return res


def _xfade(n: int):
    t = np.linspace(0, 1, n)[:, None]
    return np.cos(t * np.pi / 2), np.sin(t * np.pi / 2)  # 등전력: 두 소리가 겹쳐도 세기가 일정


def assemble(pieces: list, src_dir: str, cache: dict) -> np.ndarray:
    n = int(XF * SR)
    h = n // 2
    out = None
    for p in pieces:
        x = _load(src_dir, p["src"], cache)
        a = max(0, int(p["a"] * SR) - h)
        b = min(len(x), int(p["b"] * SR) + h)
        seg = x[a:b].copy()
        seg *= TARGET_RMS / _rms(seg)
        if out is None:
            out = seg
        else:
            fo, fi = _xfade(n)
            out[-n:] = out[-n:] * fo + seg[:n] * fi
            out = np.concatenate([out, seg[n:]])
    return out


def to_loop(x: np.ndarray) -> np.ndarray:
    """끝 0.3초를 처음 0.3초와 겹쳐 끝→처음이 틈 없이 이어지게 (그만큼 짧아진다)."""
    n = int(XF * SR)
    fo, fi = _xfade(n)
    body = x[:-n].copy()
    body[:n] = x[-n:] * fo + x[:n] * fi
    peak = float(np.abs(body).max())
    return body / max(1.0, peak / 0.95)


def main(src_dir: str, out_dir: str) -> None:
    plan = json.load(open(os.path.join(os.path.dirname(__file__), "vocal_off_plan.json"), encoding="utf-8"))
    cache: dict = {}
    rows = []
    for stage, kinds in plan["stages"].items():
        for kind, sections in kinds.items():
            ps = order(pieces_of(sections, src_dir, cache))
            loop = to_loop(assemble(ps, src_dir, cache))
            path = os.path.join(out_dir, f"{stage}/instrumental_{kind}.ogg")
            os.makedirs(os.path.dirname(path), exist_ok=True)
            write_ogg(path, loop, SR)
            sw = sum(1 for i in range(1, len(ps)) if ps[i]["group"] != ps[i - 1]["group"])
            rows.append(f"{stage}/{kind}: {len(loop) / SR:.1f}s, 조각 {len(ps)}, 판 바뀜 {sw}번(+반복 이음매)")
            print(rows[-1])


if __name__ == "__main__":
    argv = sys.argv[1:]
    out = os.path.join(ROOT, "assets/audio/music")
    if "--out" in argv:
        i = argv.index("--out")
        out = argv[i + 1]
        del argv[i:i + 2]
    main(argv[0] if argv else os.path.join(ROOT, "build", "music_src"), out)
