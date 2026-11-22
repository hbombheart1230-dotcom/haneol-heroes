# 강화 카드 그림 — GPT 이미지 프롬프트

레벨업 카드 71개는 모두 그림이 있다 (`tools/art/make_upgrade_icons.py`가 기존 기술 그림·이펙트·영웅 카드로 만든다).
기술 강화는 그 기술 그림을 다르게 잘라 쓰고, 오른쪽 아래 표지(검=피해, 시계=재사용, 화살=범위, +1=개수, 모래시계=지속 …)로 구별한다.
**아래 12개는 기술에 묶이지 않은 강화라 기존 그림을 얹어 만든 임시 그림**이다. GPT 그림을 받으면 바꾼다.

넣는 법: 받은 PNG를 `assets/concept/upgrade_icons/<영웅>/<강화 id>.png`로 저장하고
`python tools/art/make_upgrade_icons.py`를 다시 돌리면 금테와 표지를 두른 아이콘으로 바뀐다 (코드 수정 없음).

공통 조건: **1024×1024 정사각형, 그림이 화면을 꽉 채움, 테두리·글자·숫자 없음, 오른쪽 아래 1/3은 비교적 단순하게** (표지가 올라간다).

공통 앞부분 (모든 프롬프트 앞에 붙임):
> Square game skill-upgrade icon art for a mobile action game, full-bleed painting with no frame, no border, no text, no numbers, single clear subject readable at small size, keep the bottom-right corner simple. Style: Korean ink-wash (sumi-e) brush painting with vivid glowing colour highlights and dark ink outlines, painterly, high detail, matching ornate fantasy Joseon/Goguryeo skill icons.

| 저장 경로 (`assets/concept/upgrade_icons/…`) | 강화 (효과) | 프롬프트 (공통 앞부분 뒤에) |
|---|---|---|
| `yi_sun_sin/dash_breath.png` | 순신 무영보 · 고른 숨 (대시 충전 -20%) | A Joseon admiral's armoured boots leaving a fast blue streak of sea mist and spray as he dashes across wave crests, calm breath shown as a curling wisp of mist, deep blue and cyan palette. |
| `yi_sun_sin/vitality.png` | 순신 강건 (최대 체력 +25) | Admiral Yi Sun-sin in dark blue Joseon armour and black wide-brim hat with red plume, standing firm with a steady glowing blue aura around his chest like a heartbeat of the sea, waist-up portrait. |
| `yi_sun_sin/blade.png` | 순신 기본 검 · 날 세우기 (기본 공격 피해 +30%) | A curved Joseon admiral's sword held edge-up, its blade freshly honed and glinting with a sharp cold blue light, sea-water droplets flying off the edge, dark stormy ocean behind. |
| `yi_sun_sin/swift.png` | 순신 발놀림 (이동 속도 +10%) | Light quick footwork over rippling water: a pair of Joseon soldier boots mid-stride leaving swift blue water trails and speed lines, foam splashing, blue and white palette. |
| `gwanggaeto/dash_breath.png` | 광개토 돌격 · 숨 고르기 (돌격 충전 -20%) | A Goguryeo king's war horse hooves and armoured legs charging forward wrapped in orange fire and crackling golden lightning, hot breath steaming, ember sparks, orange and gold palette. |
| `gwanggaeto/vitality.png` | 광개토 강건 (최대 체력 +30) | King Gwanggaeto in golden Goguryeo lamellar armour with feathered helmet, broad-chested and unshakable, a fiery orange aura pulsing around him, waist-up portrait. |
| `gwanggaeto/blade.png` | 광개토 대검 · 날 세우기 (기본 공격 피해 +30%) | A massive Goguryeo greatsword planted point-down, its edge glowing white-hot from being sharpened, sparks and small lightning arcs flying along the blade, orange fire behind. |
| `sejong/vitality.png` | 세종 강건 (최대 체력 +20) | King Sejong in a red royal dragon robe and black ikseongwan hat, calm and dignified, a warm golden glow of protection around him, waist-up portrait, red and gold palette. |
| `sejong/letters.png` | 세종 문자탄 · 또렷한 글자 (기본 공격 피해 +30%) | A single bold glowing golden Hangul consonant shaped brush stroke flying forward like a projectile, crisp sharp edges, ink trail and sparks, deep red background. (One Hangul letter allowed.) |
| `sejong/swift.png` | 세종 걸음 (이동 속도 +10%) | Royal Joseon slippers under a flowing red robe hem taking a quick light step, golden ink-brush trails and small floating Hangul strokes streaming behind, red and gold palette. |
| `shin_saimdang/vitality.png` | 사임당 강건 (최대 체력 +25) | Shin Saimdang in an ivory and soft pink Joseon hanbok, serene and composed, surrounded by a gentle aura of plum blossom petals and pale ink mist, waist-up portrait. |
| `shin_saimdang/brush.png` | 사임당 붓 · 날 세우기 (기본 공격 피해 +30%) | A painter's calligraphy brush with a sharp pointed tip dripping glossy black ink, a bold decisive ink stroke slashing across, small pink plum petals in the splash, pale paper background. |
