# 움직이는 기술 그림 시트 — 규격과 GPT 프롬프트

정지 그림(`docs/skill_vfx_prompts.md`)은 셰이더로 흔들고 흘려도 **모양 자체가 바뀌지는 않는다** (파도가 부서지고, 불길이 솟았다 꺼지는 움직임).
그 움직임은 같은 이펙트를 여러 장 그린 **프레임 시트**로 넣는다. 시트가 있으면 게임이 정지 그림 대신 장을 넘겨 그리고,
없으면 지금 방식 그대로다 (조각 등장·일렁임·먹 번짐은 시트 위에도 그대로 걸린다).

## 1. 규격

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

## 2. GPT 프롬프트

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

## 3. 한계

- GPT의 연속 장면은 장마다 모양이 조금씩 다르다. 위 도구가 중심·크기·앞뒤 섞기로 줄이지만, 크게 다르면 다시 그려야 한다.
- 6장 × 사이 장 = 11장, 256px 칸 → 시트 하나 약 1024 × 768. 16개 다 넣어도 APK 약 3~5MB 늘어남 (30MiB 상한 안).
- 칸이 작으면 (256px) 큰 기술(지름 600px 이상)이 조금 흐려질 수 있다. 그때는 `--size 384`.
