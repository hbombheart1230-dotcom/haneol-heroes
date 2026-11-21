"""CC0 효과음·음악을 게임용으로 다듬는다: 잘라내기, 끝 부드럽게, 크기 맞추기, 모노 OGG로 작게.

  python tools/audio/prepare_audio.py <원본 폴더> [종류 ...]
종류를 주면 그 효과음만 다시 만든다 (음악은 건너뜀). 예: ... <폴더> hurt
원본 (모두 CC0, OpenGameArt — README 외부 자산 표):
  sword - StarNinjas/*.ogg, sword_clash.*.ogg (StarNinjas, 20 Sword Sound Effects)
  RPG Sound Pack/** (artisticdude), asianoriental1_0.ogg (Asianoriental1)
  hits/hit*.mp3.flac (Independent.nu, 37 hits/punches)
  rpg80/*.ogg (rubberduck, 80 CC0 RPG SFX), scifi/*.ogg (rubberduck, 50 CC0 Sci-Fi SFX)
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

## 종류 → [(원본 경로 패턴, 최대 길이 초, 음량 배율[, 재생 속도])]. 재생 속도 < 1이면 낮고 묵직하게.
SFX = {
    "slash": [("sword - StarNinjas/sword.3.ogg", 0.45, 0.8), ("sword - StarNinjas/sword.4.ogg", 0.45, 0.8),
              ("sword - StarNinjas/sword.6.ogg", 0.45, 0.8)],
    # 명중 몸통 ("퍽"): 모든 영웅 공통. 재질 겹은 영웅 데이터 hit_sfx (mat_*)
    "hit": [("hits/hit17.mp3.flac", 0.2, 0.8), ("hits/hit22.mp3.flac", 0.2, 0.8), ("hits/hit28.mp3.flac", 0.2, 0.8),
            ("hits/hit32.mp3.flac", 0.2, 0.8)],
    "mat_blade": [("rpg80/blade_01.ogg", 0.18, 0.8), ("rpg80/blade_03.ogg", 0.18, 0.8)],
    "mat_water": [("RPG Sound Pack/inventory/bubble.wav", 0.22, 0.9), ("rpg80/creature_slime_03.ogg", 0.22, 0.8)],
    "mat_fire": [("rpg80/spell_fire_06.ogg", 0.3, 0.8), ("rpg80/spell_fire_06.ogg", 0.3, 0.8, 0.88)],
    "mat_blunt": [("rpg80/stones_01.ogg", 0.22, 0.9), ("rpg80/stones_04.ogg", 0.15, 0.9)],
    "mat_lightning": [("scifi/shoot_02.ogg", 0.15, 0.7), ("scifi/misc_07.ogg", 0.16, 0.7)],
    "mat_glyph": [("rpg80/item_gem_01.ogg", 0.18, 0.7), ("rpg80/item_gem_03.ogg", 0.12, 0.7)],
    "mat_ink": [("rpg80/creature_slime_03.ogg", 0.22, 0.8, 0.9), ("RPG Sound Pack/NPC/slime/slime1.wav", 0.1, 0.8)],
    "mat_brush": [("RPG Sound Pack/inventory/cloth.wav", 0.22, 0.9), ("RPG Sound Pack/inventory/cloth-heavy.wav", 0.2, 0.9)],
    # 확인음: 큰 타격 "팅", 정예·보스 처치 "쿵" (낮게)
    "confirm_big": [("RPG Sound Pack/inventory/metal-ringing.wav", 0.35, 0.8)],
    "confirm_kill": [("hits/hit35.mp3.flac", 0.6, 1.0, 0.7), ("hits/hit19.mp3.flac", 0.6, 1.0, 0.7)],
    "dash": [("RPG Sound Pack/battle/swing.wav", 0.25, 0.9), ("RPG Sound Pack/battle/swing2.wav", 0.2, 0.9)],
    "evade": [("RPG Sound Pack/battle/swing3.wav", 0.2, 1.0)],
    "counter": [("sword_clash.1.ogg", 0.8, 1.0)],
    "magic": [("RPG Sound Pack/battle/magic1.wav", 0.8, 0.9)],
    "hurt": [("hits/hit26.mp3.flac", 0.35, 1.0, 0.85), ("hits/hit30.mp3.flac", 0.35, 1.0, 0.85)],  # 둔탁한 타격 (갑옷 부스럭 대신)
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


def slow(m: np.ndarray, speed: float) -> np.ndarray:
    """speed배 빠르기로 (1보다 작으면 길고 낮아짐)."""
    if abs(speed - 1.0) < 1e-6:
        return m
    n = int(len(m) / speed)
    return np.interp(np.linspace(0, len(m) - 1, n), np.arange(len(m)), m)


def main(src: str, only: list) -> None:
    out = os.path.join(ROOT, "assets", "audio", "sfx")
    os.makedirs(out, exist_ok=True)
    total = 0
    for kind, items in SFX.items():
        if only and kind not in only:
            continue
        for i, item in enumerate(items):
            pat, max_s, gain = item[:3]
            speed = item[3] if len(item) > 3 else 1.0
            dest = os.path.join(out, f"{kind}_{i + 1}.ogg")
            m = slow(load_mono(find(src, pat), SFX_RATE), speed)
            sf.write(dest, shape(m, SFX_RATE, max_s, gain), SFX_RATE, format="OGG", subtype="VORBIS")
            total += os.path.getsize(dest)
    if only:
        print(f"total {total // 1024} KiB")
        return
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
    main(sys.argv[1], sys.argv[2:])
