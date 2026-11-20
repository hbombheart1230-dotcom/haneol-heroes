"""영웅 이야기 데이터(data/intro/story_<영웅>.tres) 만들기 + 영웅 데이터에 연결.

  python tools/art/make_hero_stories.py

- 대본: 아래 STORIES (초안, 사용자 승인 전 — docs/intro_prompts.md에도 같은 내용).
- 그림: assets/intro/<영웅>/s1.png ~ s5.png가 있으면 그것, 없으면 임시 그림(영웅 일러스트·무대 지도).
  GPT 그림을 그 자리에 넣고 다시 실행하면 된다.
"""
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

## 영웅: (무대 지도 임시 그림, 장면들 [(위 붓글씨, [글줄...]), ...])
STORIES = {
    "gwanggaeto": ("manchuria_395", [
        ("광개토", ["열여덟에 왕위에 올라", "북으로 남으로 땅을 넓힌 고구려의 왕."]),
        ("", ["그가 무찌른 비려의 군대가", "천육백 년의 잠에서 깨어", "다시 벌판을 덮었다."]),
        ("", ["한얼의 천둥이", "잠든 왕의 혼을 깨운다."]),
        ("", ["다시 말에 올라라,", "영락의 왕이여."]),
        ("만주 벌판", ["벌판의 망령을 쓸어라."]),
    ]),
    "sejong": ("gyeongbokgung_1433", [
        ("세종", ["백성을 위해 글자를 만든", "조선의 임금."]),
        ("서기 1433년", ["최윤덕 장군이", "북방 파저강의 여진을 토벌한 해."]),
        ("", ["그 여진의 망령이 강을 건너", "경복궁 뜰까지 밀려왔다."]),
        ("", ["한얼은 그에게 글자의 힘을 주었다.", "소리를 담은 획이 빛이 되어 떠오른다."]),
        ("경복궁", ["궁궐을 지켜라."]),
    ]),
    "shin_saimdang": ("chochungdo", [
        ("사임당", ["풀과 벌레를", "살아 있는 듯 그린 조선의 화가."]),
        ("", ["망령의 기운이 그림에 스며들자", "그림 속 들쥐와 벌레들이 눈을 떴다."]),
        ("", ["수박을 갉던 들쥐, 오이 덩굴의 개구리,", "사마귀까지 붓 밖으로 기어 나왔다."]),
        ("", ["한얼은 그녀의 붓에 깃들었다.", "먹 한 획이 칼이 되고, 꽃이 방패가 된다."]),
        ("초충도", ["그림 속으로 들어가라."]),
    ]),
    "yi_sun_sin": ("hansan_1592", [
        ("순신", ["바다를 지켜", "나라를 지킨 조선의 장수."]),
        ("서기 1592년", ["한산도 앞바다,", "학이 날개를 펴듯 배를 벌려", "왜 수군을 크게 무찔렀다."]),
        ("", ["그날 가라앉은 왜군의 망령이", "검은 물결을 타고 다시 떠올랐다."]),
        ("", ["한얼의 물결이", "그의 칼에 감긴다."]),
        ("한산도", ["다시 바다로 나서라."]),
    ]),
}

## 임시 그림 (진짜 그림이 없을 때): 장면 번호 → "card"(영웅 일러스트) 또는 "map"(무대 지도), 덧칠 색
PLACEHOLDER = {1: ("card", "Color(1, 1, 1, 1)"), 2: ("map", "Color(0.75, 0.7, 0.65, 1)"),
               3: ("map", "Color(0.35, 0.45, 0.5, 1)"), 4: ("card", "Color(0.8, 0.85, 1, 1)"),
               5: ("map", "Color(1, 1, 1, 1)")}


def quote(s: str) -> str:
    return '"' + s.replace('"', '\\"') + '"'


def make(hero: str) -> str:
    stage, scenes = STORIES[hero]
    ext = ['[ext_resource type="Script" path="res://scripts/data/intro_data.gd" id="1_data"]',
           '[ext_resource type="Script" path="res://scripts/data/intro_slide.gd" id="2_slide"]',
           f'[ext_resource type="Texture2D" path="res://assets/ui/heroes/{hero}.png" id="card"]',
           f'[ext_resource type="Texture2D" path="res://assets/backgrounds/{stage}.png" id="map"]']
    subs, real = [], 0
    for n, (caption, lines) in enumerate(scenes, 1):
        own = f"assets/intro/{hero}/s{n}.png"
        if os.path.exists(os.path.join(ROOT, own)):
            ext.append(f'[ext_resource type="Texture2D" path="res://{own}" id="s{n}"]')
            img, tint = f"s{n}", "Color(1, 1, 1, 1)"
            real += 1
        else:
            img, tint = PLACEHOLDER[n]
        body = [f'[sub_resource type="Resource" id="slide{n}"]', 'script = ExtResource("2_slide")',
                f'image = ExtResource("{img}")', f"tint = {tint}"]
        if caption:
            body.append(f"caption = {quote(caption)}")
        body.append("lines = PackedStringArray(" + ", ".join(quote(x) for x in lines) + ")")
        body.append(f"duration = {5.5 + 1.0 * len(lines):.1f}")
        body.append("pan = Vector2(0, -0.02)" if n % 2 else "pan = Vector2(0.02, 0)")
        subs.append("\n".join(body))
    text = ('[gd_resource type="Resource" script_class="IntroData" format=3]\n\n' + "\n".join(ext) + "\n\n"
            + "\n\n".join(subs) + '\n\n[resource]\nscript = ExtResource("1_data")\n'
            + 'slides = Array[ExtResource("2_slide")]([' + ", ".join(f'SubResource("slide{n}")' for n in range(1, len(scenes) + 1)) + "])\n")
    with open(os.path.join(ROOT, f"data/intro/story_{hero}.tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    link(hero)
    return f"{hero}: {len(scenes)} scenes, real art {real}/{len(scenes)}"


def link(hero: str) -> None:
    """data/heroes/<영웅>.tres에 story = 이야기 데이터를 건다 (이미 있으면 그대로)."""
    p = os.path.join(ROOT, f"data/heroes/{hero}.tres")
    t = open(p, encoding="utf-8").read()
    if 'id="story"' not in t:
        t = re.sub(r"(\n\[ext_resource [^\n]*\]\n)(?!\[ext_resource)",
                   rf'\1[ext_resource type="Resource" path="res://data/intro/story_{hero}.tres" id="story"]\n', t, count=1)
    if "\nstory = " not in t:
        t = t.replace(f'\nhome_stage = ', f'\nstory = ExtResource("story")\nhome_stage = ', 1)
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(t)


if __name__ == "__main__":
    for h in STORIES:
        print(make(h))
