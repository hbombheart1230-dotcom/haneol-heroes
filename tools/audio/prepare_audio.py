"""CC0 효과음·음악을 게임용으로 다듬는다: 잘라내기, 끝 부드럽게, 크기 맞추기, 모노 OGG로 작게.

  python tools/audio/prepare_audio.py <원본 폴더>
원본 (모두 CC0, OpenGameArt — README 외부 자산 표):
  sword - StarNinjas/*.ogg, sword_clash.*.ogg (StarNinjas, 20 Sword Sound Effects)
  RPG Sound Pack/** (artisticdude), asianoriental1_0.ogg (Asianoriental1)
결과: assets/audio/sfx/<종류>_<번호>.ogg, assets/audio/music/<이름>.ogg
"""
import glob
import os
import sys

import numpy as np
import soundfile as sf

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX_RATE = 32000
MUSIC_RATE = 22050

## 종류 → [(원본 경로 패턴, 최대 길이 초, 음량 배율)]
SFX = {
    "slash": [("sword - StarNinjas/sword.3.ogg", 0.45, 0.8), ("sword - StarNinjas/sword.4.ogg", 0.45, 0.8),
              ("sword - StarNinjas/sword.6.ogg", 0.45, 0.8)],
    "hit": [("sword_clash.5.ogg", 0.22, 0.45), ("sword_clash.10.ogg", 0.22, 0.45)],
    "dash": [("RPG Sound Pack/battle/swing.wav", 0.25, 0.9), ("RPG Sound Pack/battle/swing2.wav", 0.2, 0.9)],
    "evade": [("RPG Sound Pack/battle/swing3.wav", 0.2, 1.0)],
    "counter": [("sword_clash.1.ogg", 0.8, 1.0)],
    "magic": [("RPG Sound Pack/battle/magic1.wav", 0.8, 0.9)],
    "hurt": [("RPG Sound Pack/inventory/armor-light.wav", 0.4, 0.9)],
    "die": [("RPG Sound Pack/NPC/gutteral beast/mnstr1.wav", 0.45, 0.6),
            ("RPG Sound Pack/NPC/gutteral beast/mnstr12.wav", 0.45, 0.6),
            ("RPG Sound Pack/NPC/gutteral beast/mnstr15.wav", 0.4, 0.6)],
    "ui": [("RPG Sound Pack/interface/interface1.wav", 0.25, 0.8)],
}
MUSIC = {"manchuria_395": ("asianoriental1_0.ogg", 0.55)}


def find(src: str, pattern: str) -> str:
    hits = glob.glob(os.path.join(src, "**", pattern), recursive=True)
    if not hits:
        raise SystemExit(f"원본을 찾지 못했습니다: {pattern}")
    return hits[0]


def load_mono(path: str, rate: int) -> np.ndarray:
    data, sr = sf.read(path, always_2d=True)
    m = data.mean(axis=1)
    if sr != rate:  # 선형 보간으로 표본 수 맞추기 (효과음 품질엔 충분)
        n = int(len(m) * rate / sr)
        m = np.interp(np.linspace(0, len(m) - 1, n), np.arange(len(m)), m)
    return m


def shape(m: np.ndarray, rate: int, max_s: float, gain: float) -> np.ndarray:
    nz = np.flatnonzero(np.abs(m) > 0.02)
    if nz.size:
        m = m[max(nz[0] - int(0.005 * rate), 0):]  # 앞 무음 자르기
    m = m[: int(max_s * rate)]
    fade = min(len(m), int(0.03 * rate))
    m[-fade:] *= np.linspace(1.0, 0.0, fade)
    peak = float(np.abs(m).max()) or 1.0
    return np.clip(m / peak * 0.95 * gain, -1.0, 1.0)


def main(src: str) -> None:
    out = os.path.join(ROOT, "assets", "audio", "sfx")
    os.makedirs(out, exist_ok=True)
    total = 0
    for kind, items in SFX.items():
        for i, (pat, max_s, gain) in enumerate(items):
            dest = os.path.join(out, f"{kind}_{i + 1}.ogg")
            sf.write(dest, shape(load_mono(find(src, pat), SFX_RATE), SFX_RATE, max_s, gain), SFX_RATE,
                     format="OGG", subtype="VORBIS")
            total += os.path.getsize(dest)
    mdir = os.path.join(ROOT, "assets", "audio", "music")
    os.makedirs(mdir, exist_ok=True)
    for name, (pat, gain) in MUSIC.items():
        m = load_mono(find(src, pat), MUSIC_RATE)
        m = np.clip(m / (float(np.abs(m).max()) or 1.0) * gain, -1.0, 1.0).astype(np.float32)
        dest = os.path.join(mdir, f"{name}.ogg")
        # 긴 곡을 한 번에 쓰면 libsndfile Vorbis가 멈춰서 4초씩 나눠 쓴다
        with sf.SoundFile(dest, "w", MUSIC_RATE, 1, format="OGG", subtype="VORBIS") as f:
            for k in range(0, len(m), MUSIC_RATE * 4):
                f.write(m[k:k + MUSIC_RATE * 4])
        total += os.path.getsize(dest)
    print(f"total {total // 1024} KiB")


if __name__ == "__main__":
    main(sys.argv[1])
