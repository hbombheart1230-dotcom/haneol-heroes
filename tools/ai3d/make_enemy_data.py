"""구운 적 시트로 적 데이터(.tres)를 만든다: 같은 역할의 기존 적(행동·수치)을 본떠 시트·이름·색·크기만 바꾼다.

  python tools/ai3d/make_enemy_data.py
역할: soldier→chaser, archer→archer, heavy→heavy, elite→elite_warrior, boss→boss_general
크기: 굽기 카메라(ortho)·칸 크기에서 월드 배율(약 97px/m)을 맞추고, 발이 그림자 위에 오게 한다.
"""
import json
import os
import re

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROLE_SRC = {"soldier": "chaser", "archer": "archer", "heavy": "heavy", "elite": "elite_warrior", "boss": "boss_general"}
PX_PER_M = 97.0

## (시트 이름, 역할, 화면 이름, 색 보정 또는 None, 보스면 크기 배율)
ENEMIES = [
    ("waegun_soldier", "soldier", "왜군 망령 졸병", "Color(0.82, 0.9, 1, 1)", 1.0),
    ("waegun_gunner", "archer", "왜군 망령 철포병", "Color(0.82, 0.9, 1, 1)", 1.0),
    ("waegun_heavy", "heavy", "왜군 망령 무사", "Color(0.82, 0.9, 1, 1)", 1.0),
    ("waegun_elite", "elite", "왜군 망령 사무라이 대장", "Color(1, 0.9, 0.7, 1)", 1.0),
    ("waegun_commander", "boss", "왜군 망령 수군 장수", "Color(0.85, 0.92, 1, 1)", 1.2),
    ("jurchen_soldier", "soldier", "여진 망령 전사", "Color(1, 0.96, 0.92, 1)", 1.0),
    ("jurchen_archer", "archer", "여진 망령 궁수", "Color(1, 0.96, 0.92, 1)", 1.0),
    ("jurchen_heavy", "heavy", "여진 망령 장사", "Color(1, 0.96, 0.92, 1)", 1.0),
    ("jurchen_elite", "elite", "여진 망령 용사", "Color(1, 0.9, 0.7, 1)", 1.0),
    ("jurchen_chieftain", "boss", "여진 망령 추장", "Color(1, 0.97, 0.94, 1)", 1.2),
    ("cc_mouse", "soldier", "수박 들쥐", None, 1.0),
    ("cc_grasshopper", "archer", "방아깨비 궁수", None, 1.0),
    ("cc_beetle", "heavy", "맨드라미 쇠똥벌레", None, 1.0),
    ("cc_mantis", "elite", "사마귀 검객", "Color(1, 0.95, 0.8, 1)", 1.0),
    ("cc_frog", "boss", "오이 덩굴 개구리 장군", None, 1.2),
]


def mean_feet(sheet_dir: str, frame: int) -> float:
    vals = []
    im = Image.open(os.path.join(sheet_dir, "run.png"))
    for d in range(8):
        for f in range(im.width // frame):
            box = im.crop((f * frame, d * frame, f * frame + frame, d * frame + frame)).getbbox()
            if box:
                vals.append(box[3] - frame / 2)
    return sum(vals) / max(len(vals), 1)


def make(name: str, role: str, label: str, tint, boss_scale: float) -> str:
    job_path = os.path.join(ROOT, f"tools/bake/jobs/{name}.json")
    if not os.path.exists(job_path):  # 아직 굽지 않음
        return ""
    job = json.load(open(job_path, encoding="utf-8"))
    frame, ortho = int(job["frame"]), float(job["ortho_size"])
    sheet_dir = os.path.join(ROOT, f"assets/sprites/{name}")
    if not os.path.exists(os.path.join(sheet_dir, f"{name}.tres")):
        return ""
    src = os.path.join(ROOT, f"data/enemies/{ROLE_SRC[role]}.tres")
    t = open(src, encoding="utf-8").read()
    scale = round(PX_PER_M * ortho / frame * boss_scale, 2)
    radius = float(re.search(r"\nbody_radius = ([0-9.]+)", t).group(1))
    off = round(-mean_feet(sheet_dir, frame) * scale + 0.7 * radius)
    t = re.sub(r'path="res://assets/sprites/[a-z_]+/[a-z_]+\.tres"', f'path="res://assets/sprites/{name}/{name}.tres"', t, count=1)
    t = re.sub(r'\nid = &"[a-z_]+"', f'\nid = &"{name}"', t, count=1)
    t = re.sub(r'\ndisplay_name = "[^"]*"', f'\ndisplay_name = "{label}"', t)
    if "\ndisplay_name = " not in t:
        t = t.replace(f'\nid = &"{name}"', f'\nid = &"{name}"\ndisplay_name = "{label}"', 1)
    t = re.sub(r"\nsprite_scale = [0-9.]+", f"\nsprite_scale = {scale}", t)
    t = re.sub(r"\nsprite_offset = Vector2\([^)]*\)", f"\nsprite_offset = Vector2(0, {off})", t)
    t = re.sub(r"\nsprite_tint = Color\([^)]*\)", "", t)
    if tint:
        t = t.replace("\nsprite_scale = ", f"\nsprite_tint = {tint}\nsprite_scale = ", 1)
    dest = os.path.join(ROOT, f"data/enemies/{name}.tres")
    with open(dest, "w", encoding="utf-8", newline="\n") as f:
        f.write(t)
    return dest


if __name__ == "__main__":
    for e in ENEMIES:
        out = make(*e)
        print(("ok   " if out else "skip ") + e[0])
