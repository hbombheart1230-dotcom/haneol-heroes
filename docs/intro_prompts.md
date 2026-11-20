# 이야기 인트로 — 대본 초안 · 그림 프롬프트 · 음악

> **상태: 초안 (사용자 승인 전).** 망령이 깨어난 이유는 시나리오 정본(docs/scenario.md 4장)에서 아직 미확정이다.
> 승인되면 scenario.md 3장에 정본으로 옮긴다. 게임 데이터: `data/intro/story_intro.tres` (장면·글·음악).

## 대본 (장면 5개, 약 37초, 화면 누르면 다음 장면 · "건너뛰기")

| # | 위 붓글씨 | 글줄 | 그림 (지금은 임시) |
|---|---|---|---|
| 1 | 서기 395년 | 영락 5년, 광개토왕은 / 북쪽 벌판에서 비려를 무찔렀다. / 그날의 승리는 훗날 큰 비석에 새겨졌다. | 만주 벌판 지도 |
| 2 | — | 쓰러진 군대는 흙이 되었으나 / 그 원한은 끝내 흩어지지 않았다. | 같은 지도, 어둡게 |
| 3 | 그리고 지금 | 땅이 갈라지고, 거란의 망령이 깨어났다. / 망령의 기운은 시대를 거슬러 번져 / 북방의 여진, 바다의 왜군, / 그림 속 들판까지 잠을 깨웠다. | 같은 지도, 푸르스름하게 |
| 4 | 한얼 | 시대는 달라도 영웅의 혼은 이어진다. / 한얼이 네 영웅을 불러냈다. / 물결의 순신, 문자의 세종, / 수묵의 사임당, 천둥의 광개토. | 초충도 종이 |
| 5 | 역사가 전설이 된다 | — | 타이틀 키아트 |

사실 확인: 395년(영락 5년) 비려 정벌은 광개토대왕릉비 기록, 비석은 414년 장수왕이 세움 ("훗날").

## GPT 그림 프롬프트 (세로 2:3, 장면마다 한 장)

공통 앞부분:
```
Portrait 2:3 cinematic story illustration for a Korean historical fantasy game intro. Hand-painted semi-realistic style with Korean ink-wash texture, dramatic lighting, muted palette with a few strong accents. The lower third stays darker and simple (white story text will be placed there), the top area calm (a title will sit there). No text, no letters, no UI, no frame.
```

1. `Year 395, Goguryeo cavalry under a young king in his 20s (Gwanggaeto) charging across an autumn Manchurian steppe at dawn, banners and dust, a defeated Biryeo camp burning in the distance. Epic wide shot.`
2. `The same steppe after the battle at dusk: broken spears, fallen banners and helmets half-buried in the earth, crows, a cold wind; quiet, mournful, no bodies shown.`
3. `Night: the steppe earth cracks open with pale blue-green ghost light, a phantom army of Khitan-style warriors rising from the ground as translucent ink-smoke figures, eyes glowing; the ghostly light spreads to the horizon.`
4. `Four streams of light descending from a starry sky into an ink-wash landscape: a blue ocean wave, a golden thunderbolt, glowing Hangul-like letters, and a swirl of black ink with flowers; symbolic, no people.`
5. (선택) `The four young heroes seen from behind on a hill facing the phantom army at dawn: an admiral with a sword, a king with a scroll of glowing letters, a woman painter with a giant brush, a warrior king with thunder; heroic silhouette.` — 비우면 지금 타이틀 키아트를 쓴다.

## 음악 (Suno)

```
Korean traditional cinematic intro, slow build: solo daegeum flute and gayageum open over low drones, then janggu and buk drums rise, haegeum melody, epic swell at the end. Mysterious, solemn, then heroic. Instrumental, 40 seconds.
```
내 노래를 쓸 거면 첫 곡의 도입부(악기만)를 40초로 잘라 써도 된다 (docs/music_prompts.md).

## 뮤비 (나중, 입장 화면 전에)

- 동영상 재생은 Godot의 Theora(.ogv)를 쓴다. **엔진 다이어트(PR #20)에서 theora 모듈을 껐다** → 뮤비를 넣을 때 `module_theora_enabled`를 다시 켜고 엔진을 다시 빌드한다 (APK가 조금 커진다).
- Suno 뮤비(mp4)는 ffmpeg로 .ogv로 바꾼다. 크기가 크면 해상도 720p·짧게.

---

# 영웅 이야기 (영웅을 처음 고를 때 한 번, 무대 전에)

> **상태: 초안 (사용자 승인 전).** 데이터: `data/intro/story_<영웅>.tres` — `tools/art/make_hero_stories.py`가 만든다.
> 그림을 `assets/intro/<영웅>/s1.png` ~ `s5.png`로 넣고 스크립트를 다시 돌리면 임시 그림이 바뀐다.
> 흐름: 입장 → 공통 이야기(처음 한 번) → 영웅 고르기 → **그 영웅 이야기** → 그 영웅의 무대.

GPT에 줄 때: 공통 앞부분(위 "GPT 그림 프롬프트")을 붙이고, **그 영웅의 일러스트(assets/ui/heroes/<영웅>.png)를 같이 올려** 얼굴·옷이 같게 해 달라고 한다. 글자는 그림에 넣지 않는다.

## 광개토 — 만주 벌판 (395)

| # | 붓글씨 | 글줄 | 그림 프롬프트 |
|---|---|---|---|
| 1 | 광개토 | 열여덟에 왕위에 올라 / 북으로 남으로 땅을 넓힌 고구려의 왕. | `The young Goguryeo king (attached character) standing on a fortress wall of Gungnae at dawn, looking north over vast lands, royal banners.` |
| 2 | — | 그가 무찌른 비려의 군대가 / 천육백 년의 잠에서 깨어 / 다시 벌판을 덮었다. | `Night steppe, a vast ghostly nomad army of pale blue ink-smoke riders spreading across the plain under a full moon.` |
| 3 | — | 한얼의 천둥이 / 잠든 왕의 혼을 깨운다. | `A golden thunderbolt strikes a stone stele on the steppe; the young king's spirit forms from the lightning, eyes opening.` |
| 4 | — | 다시 말에 올라라, / 영락의 왕이여. | `The king mounting an armored warhorse, golden lightning crackling around his spear and cape, wind and dust.` |
| 5 | 만주 벌판 | 벌판의 망령을 쓸어라. | `The king charging alone into the ghostly army, a wave of golden thunder ahead of him, wide dramatic shot.` |

## 세종 — 경복궁 (1433)

| # | 붓글씨 | 글줄 | 그림 프롬프트 |
|---|---|---|---|
| 1 | 세종 | 백성을 위해 글자를 만든 / 조선의 임금. | `The young Joseon king (attached character) at a low desk by candlelight in a scholars' hall, scrolls and brushes around him, warm light.` |
| 2 | 서기 1433년 | 최윤덕 장군이 / 북방 파저강의 여진을 토벌한 해. | `Early Joseon army marching north through snowy mountains along a frozen river, banners, a general on horseback, wide shot.` |
| 3 | — | 그 여진의 망령이 강을 건너 / 경복궁 뜰까지 밀려왔다. | `Night, Gyeongbokgung palace courtyard, ghostly northern hunter warriors in fur hats made of pale ink smoke pouring through the gate.` |
| 4 | — | 한얼은 그에게 글자의 힘을 주었다. / 소리를 담은 획이 빛이 되어 떠오른다. | `The king raising his hand; glowing golden brush strokes, dots and lines (no readable letters) swirl around him like stars.` |
| 5 | 경복궁 | 궁궐을 지켜라. | `The king standing on the throne hall steps facing the ghost army in the courtyard, golden strokes forming a shield of light.` |

## 사임당 — 초충도

| # | 붓글씨 | 글줄 | 그림 프롬프트 |
|---|---|---|---|
| 1 | 사임당 | 풀과 벌레를 / 살아 있는 듯 그린 조선의 화가. | `The young Joseon woman painter (attached character) painting grass, insects and a watermelon on silk at a low table, soft daylight.` |
| 2 | — | 망령의 기운이 그림에 스며들자 / 그림 속 들쥐와 벌레들이 눈을 떴다. | `Close-up of the painting: a painted field mouse beside a watermelon opens glowing eyes, faint dark mist seeping into the silk.` |
| 3 | — | 수박을 갉던 들쥐, 오이 덩굴의 개구리, / 사마귀까지 붓 밖으로 기어 나왔다. | `Painted creatures (mouse, frog, mantis, beetle) crawling out of the scroll into the room, still in ink-painting style, playful but eerie.` |
| 4 | — | 한얼은 그녀의 붓에 깃들었다. / 먹 한 획이 칼이 되고, 꽃이 방패가 된다. | `The painter holding a giant brush; a sweeping black ink stroke becomes a blade, petals swirl into a shield around her.` |
| 5 | 초충도 | 그림 속으로 들어가라. | `The painter stepping into her own painting world of giant flowers, vines and paper texture, seen from behind.` |

## 순신 — 한산도 (1592)

| # | 붓글씨 | 글줄 | 그림 프롬프트 |
|---|---|---|---|
| 1 | 순신 | 바다를 지켜 / 나라를 지킨 조선의 장수. | `The young Joseon admiral (attached character) on the deck of a panokseon at dawn, hand on sword, sea wind, flags.` |
| 2 | 서기 1592년 | 한산도 앞바다, / 학이 날개를 펴듯 배를 벌려 / 왜 수군을 크게 무찔렀다. | `Bird's-eye view of a Joseon fleet spread in a crane-wing formation around an island, enemy ships trapped in the middle, smoke.` |
| 3 | — | 그날 가라앉은 왜군의 망령이 / 검은 물결을 타고 다시 떠올랐다. | `Night sea, ghostly Imjin-war Japanese ships and soldiers of pale blue ink smoke rising from black waves.` |
| 4 | — | 한얼의 물결이 / 그의 칼에 감긴다. | `The admiral drawing his sword; a spiral of blue sea water wraps around the blade, glowing.` |
| 5 | 한산도 | 다시 바다로 나서라. | `The admiral standing at the bow facing the ghost fleet, a great wave rising behind his ship.` |

사실 확인: 광개토 18세 즉위(391), 1433 최윤덕 파저강 토벌, 1592 한산도 대첩 학익진. 훈민정음은 1443년 창제라 세종 1장은 "글자를 만든 임금"이라는 인물 소개로만 쓴다.
