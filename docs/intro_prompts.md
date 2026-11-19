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
