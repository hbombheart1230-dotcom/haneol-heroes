# 기술 그림 다시 그리기 — A안(움직이는 시트)·B안(부품 그림), 규격과 GPT 프롬프트

- **A안 (프레임 시트, 1~3장)**: 같은 이펙트를 6장 연속으로. 모양이 바뀌어야 하는 것(물마루가 부서짐, 폭발이 커짐)에만. GPT가 장마다 일관되게 그리기 어렵다.
- **B안 (부품 그림, 4~5장)**: 한 기술을 층별 낱장으로 (원판 / 바늘 / 바닥 자국 / 흩어지는 조각 / 이음매 없는 띠). GPT가 잘 그리는 낱장이고 게임의 조각 등장·일렁임·입자와 잘 맞는다. **대부분의 기술은 B안을 권한다.**
- 둘 다 없으면 지금 그림 그대로 돌아간다.

정지 그림(`docs/skill_vfx_prompts.md`)은 셰이더로 흔들고 흘려도 **모양 자체가 바뀌지는 않는다** (파도가 부서지고, 불길이 솟았다 꺼지는 움직임).
그 움직임은 같은 이펙트를 여러 장 그린 **프레임 시트**로 넣는다. 시트가 있으면 게임이 정지 그림 대신 장을 넘겨 그리고,
없으면 지금 방식 그대로다 (조각 등장·일렁임·먹 번짐은 시트 위에도 그대로 걸린다).

## 1. A안 규격

| 항목 | 둥근 이펙트 (대부분) | 띠 (파도격·벽력돌파·발묵) |
|---|---|---|
| 이미지 크기 | 1536 × 1024 (가로) | 1024 × 1536 (세로) |
| 칸 | 가로 3 × 세로 2 = **6장** (칸 512 × 512) | 가로 1 × 세로 6 = **6장** (칸 1024 × 256, 오른쪽 = 앞) |
| 진행 순서 | 왼쪽 위 → 오른쪽 → 다음 줄. 1장 = 시작(모이거나 작음), 6장 = 흩어지며 사라짐 | 위 → 아래 |
| 바탕 | **투명** (가능하면). 안 되면 **순백 #FFFFFF 단색** (그라데이션·그림자·종이 질감 없이) | 같음 |
| 중심 | 모든 장에서 이펙트 중심이 칸 한가운데, 같은 시점·같은 크기 틀 | 모든 장에서 띠가 칸 세로 가운데 |
| 여백 | 이펙트가 칸 테두리에서 8% 안쪽 (칸 경계를 넘거나 닿지 않게) | 왼쪽·오른쪽 끝은 칸 끝까지 가도 됨 |
| 금지 | 칸 테두리선, 번호, 글자(정음진 제외), 사람, 바닥, 그림자 | 같음 |
| 흰 바탕일 때 | 순백 하이라이트가 바탕에 닿지 않게 (닿으면 투명으로 빠짐). 하이라이트는 연한 하늘색·크림색으로 | 같음 |

### 파일과 폴더

1. GPT 원본 → `assets/concept/vfx_sheets/<기술 id>.png` (APK에 안 들어감, 원본 보관)
2. 가공:
   ```
   python tools/vfx/sheet_to_vfx.py assets/concept/vfx_sheets/<기술 id>.png <기술 id> --tween
   ```
   띠는 `--cols 1 --rows 6 --strip`, 되풀이(해일검기 물결)는 `--loop` 추가.
   결과 → `assets/vfx/sheets/<기술 id>.png` (256px 칸, 가로 4칸으로 다시 묶음) + 기술 데이터에 붙일 줄 출력.
3. 붙이기: `data/vfx/skill/<기술>.tres`에 출력된 줄 (`sheet` 또는 `strip_sheet`, `sheet_cols`·`sheet_rows`·`sheet_count`·`sheet_fps`).
   해일검기만 `data/heroes/yi_sun_sin.tres`의 `Skill_haeil`에 `wave_sheet`·`wave_sheet_grid`·`wave_sheet_fps`.

### 가공 도구가 하는 깜빡임 줄이기 (`tools/vfx/sheet_to_vfx.py`)

- **중심 고정**: 장마다 그림 무게중심을 모든 장의 가운데값으로 옮긴다 (GPT는 장마다 조금씩 어긋나 흔들려 보인다).
- **같은 틀**: 모든 장을 합친 영역으로 똑같이 잘라 크기가 장마다 튀지 않게.
- **앞뒤 섞기** (`--smooth 0.2` 기본): 장마다 앞뒤 장을 20%씩 섞어 모양이 갑자기 바뀌는 깜빡임을 줄인다.
- **사이 장** (`--tween`): 장 사이에 반반 섞은 장을 끼워 6장 → 11장 (되풀이면 12장).
- 그래도 장마다 모양이 크게 다르면 (GPT 연속 장면의 한계) 그 시트는 `--smooth 0.3`으로 올리거나 다시 그린다.

## 2. A안 GPT 프롬프트

**공통 앞부분** (모든 프롬프트 앞에):
> A sprite sheet for a 2D mobile game visual effect: ONE effect shown in 6 sequential animation frames on a 3 columns × 2 rows grid (left to right, top to bottom), each frame in its own equal square cell. Fully transparent background (if not possible: pure flat white #FFFFFF, no paper texture, no shadow). No grid lines, no numbers, no text, no people, no ground. Top-down view. **Every frame uses the same camera, the same scale and the same centre point; the effect stays centred in its cell with a margin, and only its shape changes gradually from frame to frame (consistent design, colours and brush style in all frames, like a hand-drawn animation).** Style: Korean ink-wash (sumi-e) brush painting with vivid glowing colour highlights and dark ink outlines, matching ornate fantasy skill icons. Frame 1 = the effect forming, frames 2–3 = full burst, frames 4–6 = breaking apart into ink wisps and fading.

**띠용 공통 앞부분** (파도격·벽력돌파·발묵):
> A sprite sheet for a 2D mobile game visual effect: ONE horizontal effect band shown in 6 sequential animation frames stacked vertically (1 column × 6 rows, top to bottom), each frame a wide 4:1 cell, the band running left to right with its leading edge on the right. Fully transparent background (if not possible: pure flat white #FFFFFF). No grid lines, no numbers, no text, no people. Same scale and vertical centre in every frame; only the shape changes gradually. Style: Korean ink-wash (sumi-e) brush painting with vivid glowing colour highlights and dark ink outlines. Frame 1 = the band starting to unroll from the left, frames 2–4 = full and surging forward, frames 5–6 = trailing off into ink spray.

### 우선순위 1 — 순신·해시계

| 순위 | 기술 id (파일) | 기술 | 프롬프트 (공통 앞부분 뒤에) | 가공 |
|---|---|---|---|---|
| 1 | `yi_sun_sin_haeil_wave` | 순신 해일검기 물결 (날아가는 탄, 되풀이) | A single crescent-shaped tidal wave blade flying to the right, deep blue and cyan water with white-blue foam crest; across the 6 frames the crest curls over, breaks into spray and re-forms so the cycle loops seamlessly (frame 6 leads back into frame 1). Keep the wave the same size in every frame. | `--loop --tween`, `Skill_haeil.wave_sheet` |
| 2 | `yi_sun_sin_counter` | 순신 강화 반격 | A ring of crashing sea water and orange-red flames swirling around an empty centre (the hero stands there): frame 1 small spark ring, frames 2–3 the fire-water ring erupts outward and spins, frames 4–6 the flames break into embers and the water into spray. | `--tween` |
| 3 | `yi_sun_sin_haeryong` | 순신 해룡참 | A sea dragon made of swirling ocean water coiling in a full circle around an empty centre: frame 1 a curl of water appears at the top, frames 2–3 the water dragon sweeps clockwise around the whole circle with its head and foam, frames 4–6 the dragon dissolves into waves and droplets. | `--tween` |
| 4 | `yi_sun_sin_pado` (띠) | 순신 파도격 | A long rushing wave band surging to the right, cyan and deep blue water with white-blue foam on the leading crest and spray behind. | `--cols 1 --rows 6 --strip --tween`, `strip_sheet` |
| 5 | `sejong_sundial` | 세종 해시계 멈춤 | A golden sundial magic circle seen from above WITHOUT the central pointer (no gnomon): frame 1 a thin golden ring appears, frames 2–3 the hour marks and engraved rings light up one after another clockwise, frames 4–6 the circle cracks into golden flakes and drifting light. | `--tween` (바늘은 게임이 따로 그림) |

### 나머지

| 기술 id (파일) | 기술 | 프롬프트 (공통 앞부분 뒤에) | 가공 |
|---|---|---|---|
| `sejong_meteor` | 세종 유성 (떨어진 자리 폭발) | A meteor impact explosion seen from above: frame 1 a bright orange flash point, frames 2–3 a fireball bursts with rock shards and smoke ring, frames 4–6 smoke and embers drift apart. | `--tween` |
| `sejong_constellation` | 세종 성좌진 (별 하나) | A single golden star bursting into light: frame 1 a tiny spark, frames 2–3 a four-pointed golden star flares with a soft halo and star dust, frames 4–6 it shrinks to twinkling dust. | `--tween` |
| `sejong_jeongeum` | 세종 정음진 | A ring of glowing golden Hangul consonants ㄱ ㄴ ㄷ ㄹ ㅁ ㅂ ㅅ ㅇ in a circle, brush-written stroke by stroke: frame 1 the first strokes appear, frames 2–3 all letters are written and glow, frames 4–6 the ink letters fade into golden mist. Keep each letter in the same place in every frame. | `--tween` |
| `gwanggaeto_quake` | 광개토 뇌진격 | A ground-shattering impact seen from above: frame 1 a bright point, frames 2–3 radiating cracks, flying rock shards and orange-gold flame shockwave, frames 4–6 dust and embers settle. | `--tween` |
| `gwanggaeto_conqueror` | 광개토 정복자의 일격 | A royal golden shockwave with a crown-like burst of light and lightning seen from above: frame 1 a golden flash, frames 2–3 the crown-shaped burst and ring of lightning expands, frames 4–6 it shatters into golden sparks. | `--tween` |
| `gwanggaeto_lightning` | 광개토 낙뢰 (맞은 자리) | A lightning strike impact seen from above: frame 1 a white-gold flash point, frames 2–3 crackling branches burst outward with sparks, frames 4–6 fading electric wisps. | `--tween` |
| `gwanggaeto_thunder_trail` (띠) | 광개토 벽력돌파 | A long band of crackling golden-white lightning running to the right with orange glow and sparks. | `--cols 1 --rows 6 --strip --tween`, `strip_sheet` |
| `shin_saimdang_plum` | 사임당 매화 만개 | A burst of pink plum blossoms seen from above: frame 1 buds on ink-wash branches, frames 2–3 the blossoms open and petals scatter outward, frames 4–6 petals drift away and fade. | `--tween` |
| `shin_saimdang_canvas` | 사임당 화폭 펼치기 | A horizontal painted scroll (hanging painting) unrolling from the centre to both sides: frame 1 a rolled scroll, frames 2–4 it unrolls showing an ink-wash landscape, frames 5–6 the painting glows and dissolves into ink. | `--tween` |
| `shin_saimdang_critter` | 사임당 풀벌레 부르기 | Butterflies and grasshoppers being painted out of ink: frame 1 ink blots, frames 2–3 the insects take shape in colour and lift off, frames 4–6 they fly outward leaving ink wisps. | `--tween` |
| `shin_saimdang_ink_bleed` (띠) | 사임당 발묵 | A long band of spreading black and violet ink running to the right, wet brush splatters bleeding outward. | `--cols 1 --rows 6 --strip --tween`, `strip_sheet` |
| `sejong_hit` · `yi_sun_sin_hit` 등 | 맞은 자리 (영웅별) | A small hit splash in the hero colour (blue water / golden glyph light / orange spark / black ink): frame 1 a point, frames 2–3 a sharp burst, frames 4–6 droplets fading. | 선택. 작은 이펙트라 정지 그림으로도 충분 |

## 3. A안 한계

- GPT의 연속 장면은 장마다 모양이 조금씩 다르다. 위 도구가 중심·크기·앞뒤 섞기로 줄이지만, 크게 다르면 다시 그려야 한다.
- 6장 × 사이 장 = 11장, 256px 칸 → 시트 하나 약 1024 × 768. 16개 다 넣어도 APK 약 3~5MB 늘어남 (30MiB 상한 안).
- 칸이 작으면 (256px) 큰 기술(지름 600px 이상)이 조금 흐려질 수 있다. 그때는 `--size 384`.


## 4. 기술마다 A안·B안 추천

교체: **지금 그림이 구조적으로 맞지 않아 새로 그리는 편이 나은 기술** (★).

| 기술 | 추천 | 교체 | 이유 |
|---|---|---|---|
| 순신 해일검기 | **A** (되풀이 물마루) + B (물보라 조각) | | 날아가는 동안 물마루가 부서졌다 다시 서는 "모양 변화"가 핵심. A가 어려우면 B만으로도 지금보다 낫다 |
| 순신 반격 | B | | 지금 불물결 고리는 구조가 맞다 (가운데 빈 고리). 바닥 그을음·불씨 조각만 더하면 됨 |
| 순신 해룡참 | B | ★ | 지금 용은 S자라서 한 바퀴 휘감는 연출(바라보는 방향부터 시계 방향)과 안 맞는다. 고리로 감긴 물 용이 맞다 |
| 순신 파도격 | B (이음매 없는 띠) | | 띠 구조는 맞다. 앞쪽 물마루가 더 또렷한 띠 + 물보라 조각 |
| 세종 해시계 | B | ★ | 지금 그림에 바늘(영침)이 박혀 있어 게임이 돌리는 그림자 바늘과 둘이 보인다. 바늘 없는 판 + 바늘 따로 |
| 세종 유성 | A (폭발) + B (불탄 자국) | | 폭발은 커지는 모양 변화. A가 어려우면 B 그을음 + 불씨 조각 |
| 세종 성좌진 | B | ★ | 지금 그림은 별자리 전체 한 장인데, 게임은 별을 하나씩 다른 자리에 찍는다. 별 하나 터짐 그림이 맞다 |
| 세종 정음진 | 그대로 | | 글자 고리 그림이 구조에 맞다 |
| 광개토 뇌진격 | B | | 충격 원판은 맞다. 금 간 바닥 + 돌 조각을 더하면 "내리찍음"이 산다 |
| 광개토 벽력돌파 | B (이음매 없는 띠) | | 띠 구조는 맞다 |
| 광개토 낙뢰 | 그대로 (A 선택) | | 번개 줄기는 코드가 그린다. 맞은 자리 그림만 A로 바꿀 수 있음 |
| 광개토 정복자의 일격 | B | | 원판은 맞다. 금 간 바닥 + 돌·금빛 조각 |
| 사임당 풀벌레 | B | ★ | 지금은 꽃잎 모양 코드 그림. 나비·방아깨비를 위에서 본 낱장 그림이 맞다 |
| 사임당 발묵 | B (이음매 없는 띠) | | 띠 구조는 맞다. 바닥 먹 웅덩이 그림을 더함 |
| 사임당 화폭 | B | ★ | 지금은 네모 그림. 가운데에서 양옆으로 펼쳐지는 연출에는 가로로 긴 두루마리 띠가 맞다 |
| 사임당 매화 만개 | B | | 원판은 맞다. 꽃잎 조각을 더함 |

## 5. B안 — 부품 그림

### 규격과 자리

| 부품 | 크기 | 모양 규칙 | 들어갈 자리 (데이터) |
|---|---|---|---|
| 원판 | 1024 × 1024 | 투명 바탕, 중심이 한가운데, 둥글게 (모서리 비움), 가운데 비워도 됨 | 기술 vfx `.tres`의 `decal` |
| 바늘 | 1024 × 256 | 투명 바탕, **왼쪽 끝 = 돌리는 축**, 오른쪽을 가리킴 | `hand_art` |
| 바닥 자국 | 1024 × 1024 | 투명 바탕, 위에서 본 바닥 무늬, 가장자리가 먹처럼 흐려짐 (게임이 세로로 눌러 깜) | `ground_art` (`ground_color` 알파 = 진하기) |
| 흩어지는 조각 | 512 × 512 낱장 6장 (또는 한 장에 3×2) | 투명 바탕, 칸 가운데, 서로 닿지 않게 | `part_art` (여러 장 번갈아) |
| 이음매 없는 띠 | 2048 × 512 | 투명 바탕, 왼쪽 = 꼬리(옅음), 오른쪽 = 머리(진함), 위아래 가장자리 흐림 | `strip` |
| 벌레 | 512 × 512 각각 | 투명 바탕, 위에서 본 모습, 머리 = 위 | 사임당 `Skill_tap`의 `butterfly_art`·`grasshopper_art` |
| 물마루 탄 | 1536 × 512 | 투명 바탕, 오른쪽 = 앞 | 순신 `Skill_haeil.wave_art` |

- 원판·바늘·바닥·띠·벌레: `tools/vfx/gpt_to_vfx.py` 방식(투명 정리·색 오염 제거)으로 다듬어 `assets/vfx/`에.
- 조각은 낱장으로 그리게 해 `assets/vfx/parts/<이름>_<n>.png`에 넣는 편이 쉽다. 한 장에 3×2로 받았으면
  `python tools/vfx/sheet_to_vfx.py <원본> <이름> --no-lock --smooth 0` 으로 칸을 맞춘 뒤 칸마다 잘라 쓴다.
- 원판·띠를 바꾸면 `art_fill`(칠해진 반지름 비율)이 달라진다. 처음엔 0.88로 두고 폰에서 판정과 비교해 맞춘다.
- `part_art`를 넣은 기술은 입자 `count`·`size`를 조각 그림에 맞게 (조각 지름 40~90px 권장).
- 슬롯이 비어 있으면 지금 그림·코드 그림 그대로다.

### 공통 앞부분 (B안)

> Game VFX sprite for a 2D top-down mobile action game, a single isolated element on a fully transparent background, no frame, no border, no text, no people, no ground unless asked. Style: Korean ink-wash (sumi-e) brush painting with vivid glowing colour highlights and dark ink outlines, painterly, matching ornate fantasy skill icons. Clean soft edges that fade like ink, nothing touching the image border.

### 기술별 프롬프트 (공통 앞부분 뒤에)

| 기술 · 부품 | 파일 → 자리 | 프롬프트 |
|---|---|---|
| ★ 해시계 · 원판 | `sundial_plate.png` → `sejong_sundial.decal` | A golden sundial dial seen exactly from above, perfectly circular and centred, engraved hour ring with 12 marks and concentric rings, **no pointer, no gnomon, no shadow line**, empty smooth centre, soft golden glow at the rim. |
| ★ 해시계 · 바늘 | `sundial_hand.png` → `sejong_sundial.hand_art` | A slender sundial gnomon shadow pointer lying horizontally, its pivot at the far left end and its sharp tip pointing right, dark ink shadow with a thin golden edge, 4:1 wide image. |
| ★ 해시계 · 바닥 | `sundial_ground.png` → `sejong_sundial.ground_art` | A faint circular pattern of golden light and ink wash on the floor seen from above, like the afterglow of a sundial, very soft edges. |
| ★ 해룡참 · 원판 | `sea_dragon_ring.png` → `yi_sun_sin_haeryong.decal` | A sea dragon made of swirling ocean water coiled in a complete circle around an empty centre, head at the top chasing its own tail clockwise, deep blue and cyan water, white-blue foam, perfectly centred ring. |
| 해룡참 · 조각 | `water_clump_1~6.png` → `yi_sun_sin_haeryong.part_art` | A small clump of splashing sea water and foam droplets, cyan and deep blue with white-blue highlights. (6장, 장마다 모양 다르게) |
| 해룡참 · 바닥 | `water_stain.png` → `yi_sun_sin_haeryong.ground_art` | A wet water splash mark on a wooden deck seen from above, dark blue-grey wet stain with a few droplets, soft fading edges. |
| 반격 · 바닥 | `scorch.png` → `yi_sun_sin_counter.ground_art` | A circular scorch mark seen from above, black ink and burnt orange edges with faint embers, empty soft centre. |
| 반격 · 조각 | `ember_1~6.png` → `yi_sun_sin_counter.part_art` | A small flame ember with burning sparks and an ink smoke wisp, orange-red. (6장) |
| 해일검기 · 물마루 | `tidal_crest.png` → `Skill_haeil.wave_art` | A single crescent tidal wave crest moving to the right, curling foam at the front, water thinning to spray at the back, deep blue and cyan, 3:1 wide. |
| 해일검기 · 물보라 | `spray_1~6.png` → `yi_sun_sin_haeil_wake.part_art` | A small burst of sea spray and foam. (6장) |
| 파도격 · 띠 | `wave_band.png` → `yi_sun_sin_pado.strip` | A long horizontal rushing wave band, a faint thin water trail on the left growing into a tall foaming crest on the right, cyan and deep blue, 4:1 wide, top and bottom edges fading. |
| ★ 성좌진 · 별 | `star_burst.png` → `sejong_constellation.decal` | One four-pointed golden star flaring with a soft round halo and fine star dust, perfectly centred. |
| 성좌진 · 조각 | `stardust_1~6.png` → `sejong_constellation.part_art` | A tiny golden sparkle and star-dust cluster. (6장) |
| 유성 · 바닥 | `meteor_scorch.png` → `sejong_meteor.ground_art` | A meteor impact crater seen from above, cracked dark earth with glowing orange cracks and ash, soft edges. |
| 뇌진격 · 바닥 | `cracked_ground.png` → `gwanggaeto_quake.ground_art` | Cracked ground seen from above, dark radiating fissures with a faint orange-gold glow inside the cracks, dust at the edges, circular, soft edges. |
| 뇌진격·정복자 · 조각 | `rock_1~6.png` → `gwanggaeto_quake.part_art`, `gwanggaeto_conqueror.part_art` | A flying rock shard or dirt chunk with a little gold spark. (6장) |
| 벽력돌파 · 띠 | `thunder_band.png` → `gwanggaeto_thunder_trail.strip` | A long horizontal band of crackling golden-white lightning running to the right, thin on the left and bright on the right, 4:1 wide. |
| 정복자 · 바닥 | `royal_crater.png` → `gwanggaeto_conqueror.ground_art` | A large circular shattered-ground crater seen from above with a faint golden crown-shaped glow in the cracks. |
| ★ 풀벌레 · 나비 | `butterfly.png` → 사임당 `Skill_tap.butterfly_art` | A single ink-painted butterfly seen from directly above, wings fully open, pink and white with dark ink outlines, head pointing up. |
| ★ 풀벌레 · 방아깨비 | `grasshopper.png` → 사임당 `Skill_tap.grasshopper_art` | A single ink-painted green grasshopper seen from directly above, head pointing up, long back legs, in the style of Joseon insect-and-flower paintings. |
| 발묵 · 바닥 | `ink_pool.png` → `shin_saimdang_ink_bleed.ground_art` | A spreading pool of black and violet ink seen from above, wet bleeding edges. |
| ★ 화폭 · 두루마리 띠 | `scroll_band.png` → `shin_saimdang_canvas.decal` | A wide horizontal hanging-scroll painting fully unrolled, wooden rollers at the left and right ends, an ink-wash landscape with plum blossoms in the middle, 3:1 wide, centred. |
| 매화 · 조각 | `plum_petal_1~6.png` → `shin_saimdang_plum.part_art` | A single pink plum blossom petal or small blossom. (6장) |

## 6. 하데스 슬라이스 (순신 · 한산 · 왜군 지휘관) — 필요한 그림

슬라이스를 끝내려면 아래 그림이 있으면 된다. 순서대로 그리면 된다. 공통 앞부분(B안)은 위와 같다.
슬롯이 비어 있으면 지금 그림이나 코드 그림이 그대로 쓰인다 (`ring_art`, 글자 낙인).

| 순위 | 그림 · 파일 → 자리 | 프롬프트 (공통 앞부분 뒤에) |
|---|---|---|
| 1 | ★ 해룡참 · 원판 `sea_dragon_ring.png` → `yi_sun_sin_haeryong.decal` | (위 B안 표와 같음) |
| 2 | ★ 몹 등장 먹 번짐 원 `spawn_ink_bloom.png` → `data/feel/combat_feel.tres`의 `spawn_warn_art` | A dark ink blot spreading on rice paper seen exactly from above, a rough circular bloom of black ink with feathered bleeding edges and a faint dull-red seal-ink tint at the centre, empty soft middle, perfectly centred, 1:1. |
| 3 | ★ 보스 단계 낙인 `boss_phase_seal.png` → 왜군 지휘관 `Phase_2`·`Phase_3`의 `seal_art` | A square red Korean seal stamp (dojang) impression with bold carved strokes of a war drum emblem, cinnabar red ink on transparent background, slightly uneven pressed edges, 1:1, no readable text. |
| 4 | 반격 · 바닥 `scorch.png`, 반격 · 조각 `ember_1~6.png` | (위 B안 표와 같음) |
| 5 | 파도격 · 띠 `wave_band.png` | (위 B안 표와 같음) |
| 6 | 해일검기 · 물마루 `tidal_crest.png`, 물보라 `spray_1~6.png` | (위 B안 표와 같음) |
| 7 | 해룡참 · 조각 `water_clump_1~6.png`, 바닥 `water_stain.png` | (위 B안 표와 같음) |

- 바닥이 어두워졌기 때문에 (명도 ×0.68, 채도 ×0.48), 그림은 **밝은 색 + 진한 먹 외곽선**이 잘 읽힌다. 게임도 붓 효과에 먹 외곽선을 한 겹 깐다 (`fx_ink_outline`).
- 등장 원은 게임이 세로로 눌러(0.55배) 바닥에 눕혀 그린다. 완전한 원으로 그리면 된다.
