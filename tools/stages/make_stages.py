"""무대 데이터(.tres) 만들기: 바닥 색, 소품 그림, 적 구성, 이름. 역사 연표는 docs/scenario.md 3.2.

  python tools/stages/make_stages.py
아직 없는 적(굽지 않은 시트)은 빼고 만든다 → 그 칸은 장면 기본값(거란)을 쓴다. 다 구운 뒤 다시 실행한다.
배경 지도는 다음에 tools/art/make_backgrounds.py가 덧붙인다 (이 스크립트를 다시 돌리면 그것도 다시).
"""
import glob
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

STAGES = {
    "gyeongbokgung_1433": {
        "year": "1433년", "title": "경복궁", "hero": "세종",
        "subtitle": "세종 15년, 최윤덕이 파저강의 여진을 토벌한 해",
        "props": "gyeongbokgung", "card": "palace_gate", "skip_props": ["onggi_jars"], "floor": ("Color(0.78, 0.76, 0.72, 1)", "Color(0.35, 0.34, 0.33, 1)"),
        "grass": ("Color(0.32, 0.36, 0.22, 0.55)", 2.0), "rock": ("Color(0.5, 0.49, 0.47, 0.6)", 1.0),
        "army": ["jurchen_soldier", "jurchen_archer", "jurchen_heavy"], "elite": "jurchen_elite", "boss": "jurchen_chieftain",
    },
    "chochungdo": {
        "year": "그림 속", "title": "초충도", "hero": "사임당",
        "subtitle": "신사임당이 그린 풀과 벌레의 그림",
        "props": "chochungdo", "card": "watermelon", "skip_props": ["watermelon"], "floor": ("Color(0.95, 0.93, 0.86, 1)", "Color(0.55, 0.5, 0.42, 1)"),
        "grass": ("Color(0.36, 0.45, 0.25, 0.6)", 6.0), "rock": ("Color(0.45, 0.42, 0.36, 0.5)", 0.8),
        "army": ["cc_mouse", "cc_grasshopper", "cc_beetle"], "elite": "cc_mantis", "boss": "cc_frog",
    },
    "hansan_1592": {
        "year": "1592년", "title": "한산도", "hero": "순신",
        "subtitle": "학익진으로 왜 수군을 크게 무찌른 한산도 대첩",
        "props": "hansan", "card": "geobukseon", "floor": ("Color(0.6, 0.48, 0.34, 1)", "Color(0.25, 0.18, 0.12, 1)"),
        "grass": ("Color(0.2, 0.16, 0.12, 0.0)", 0.0), "rock": ("Color(0.3, 0.26, 0.22, 0.5)", 0.6),
        "army": ["waegun_soldier", "waegun_gunner", "waegun_heavy"], "elite": "waegun_elite", "boss": "waegun_commander",
        "skip_props": ["geobukseon", "barrels_jars", "wreck_burning", "wreck_sinking", "wreck_banner", "sea_rocks"],
    },
}


def exists(enemy: str) -> bool:
    return os.path.exists(os.path.join(ROOT, f"data/enemies/{enemy}.tres"))


def make(sid: str, s: dict) -> str:
    props = sorted(os.path.basename(p)[:-4] for p in glob.glob(os.path.join(ROOT, f"assets/props/{s['props']}/*.png")))
    props = [p for p in props if p not in s.get("skip_props", [])]
    ext = ['[ext_resource type="Script" path="res://scripts/world/stage_theme.gd" id="1_theme"]',
           '[ext_resource type="AudioStream" path="res://assets/audio/music/manchuria_395.ogg" id="2_music"]']
    ext += [f'[ext_resource type="Texture2D" path="res://assets/props/{s["props"]}/{p}.png" id="p_{p}"]' for p in props]
    army = [e for e in s["army"] if exists(e)]
    ext += [f'[ext_resource type="Resource" path="res://data/enemies/{e}.tres" id="e_{e}"]'
            for e in army + [x for x in (s["elite"], s["boss"]) if exists(x)]]
    ext.append(f'[ext_resource type="Resource" path="res://data/breakables/{sid}.tres" id="b_{sid}"]')
    # 무대 노래 (tools/audio/cut_song.py). 이 무대 노래가 아직 없으면 첫 무대 노래를 임시로.
    song = next((x for x in (sid, "manchuria_395") if os.path.exists(os.path.join(ROOT, f"data/songs/{x}.tres"))), None)
    if song:
        ext.append(f'[ext_resource type="Resource" path="res://data/songs/{song}.tres" id="song"]')
    body = ["[resource]", 'script = ExtResource("1_theme")', f'id = &"{sid}"', f'year_label = "{s["year"]}"',
            f'title = "{s["title"]}"', f'subtitle = "{s["subtitle"]}"', 'music = ExtResource("2_music")',
            f'hero_hint = "{s["hero"]}"', f'breakable = ExtResource("b_{sid}")']
    if song:
        body.append('song = ExtResource("song")')
    if army:
        body += ["spawn_table = Array[ExtResource(\"3_enemy\")]([" + ", ".join(f'ExtResource("e_{e}")' for e in army) + "])",
                 "spawn_weights = PackedFloat32Array(" + ", ".join(["6", "2", "1"][: len(army)]) + ")",
                 "unlock_times = PackedFloat32Array(" + ", ".join(["0", "10", "20"][: len(army)]) + ")"]
        ext.append('[ext_resource type="Script" path="res://scripts/data/enemy_data.gd" id="3_enemy"]')
    for key in ("elite", "boss"):
        if exists(s[key]):
            body.append(f'{key} = ExtResource("e_{s[key]}")')
    card = s.get("card", props[0] if props else "")
    if card:  # 무대 고르기 카드 그림 (흩뿌리기에서 뺀 소품이어도 된다: 거북선)
        if card not in props:
            ext.append(f'[ext_resource type="Texture2D" path="res://assets/props/{s["props"]}/{card}.png" id="p_{card}"]')
        body.append(f'card_art = ExtResource("p_{card}")')
    body += [f"floor_base = {s['floor'][0]}", f"floor_stain = {s['floor'][1]}",
             f"grass_per_mpx = {s['grass'][1]}", f"grass_color = {s['grass'][0]}",
             f"rock_per_mpx = {s['rock'][1]}", f"rock_color = {s['rock'][0]}",
             "clear_radius = 260.0", f"seed = {sum(ord(c) for c in sid) * 7}",
             "prop_textures = Array[Texture2D]([" + ", ".join(f'ExtResource("p_{p}")' for p in props) + "])",
             "picture_props_per_mpx = 6.0"]
    text = '[gd_resource type="Resource" script_class="StageTheme" format=3]\n\n' + "\n".join(ext) + "\n\n" + "\n".join(body) + "\n"
    dest = os.path.join(ROOT, f"data/stages/{sid}.tres")
    with open(dest, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    return f"{sid}: props {len(props)}, army {len(army)}, elite {exists(s['elite'])}, boss {exists(s['boss'])}"


if __name__ == "__main__":
    for sid, s in STAGES.items():
        print(make(sid, s))
