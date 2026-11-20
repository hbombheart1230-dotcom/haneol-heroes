# 무대 노래 4곡 — Suno 프롬프트 · 가사 · 설정 · 자른 구간

> 결정 (2026-11-20): 무대마다 1곡, **구간 넘나들기** — 전주(입장·이야기) / 1절(평소, 반복) / 후렴(보스, 반복) / 후주(승리).
> 목소리는 사용자 본인 노래(보컬 분리본)를 살린다: 페르소나(목소리) 추천, 커버면 오디오 영향으로 조절.
> 곡이 오면 `python tools/audio/cut_song.py <파일> <무대> --bpm N --offset S --bars intro=a-b,verse=..,chorus=..,outro=..-end`
> 원곡 mp3는 `build/music_src/` (깃 제외)에만 둔다. 가사는 초안이며 사용자가 Suno에서 쓴 최종본이 기준.

## 공통 규칙 (모든 곡)

- 빠르기 처음부터 끝까지 일정 (장단 하나로).
- 가사 칸 구조: `[Intro]` 악기만 → `[Verse]` → `[Chorus]` → `[Instrumental Break]` → `[Chorus]` → `[Outro]` 악기만 → `[End]`
- 2:30–3:30, 만든 뒤 BPM을 알려 준다 (모르면 분석해서 맞춤).
- 1절은 평소 내내 반복되니 짧게, 후렴은 보스 등장이라 가장 힘 있게.
- 한국적인 느낌: 스타일에 계면조·시김새·판소리/정가/민요 창법을 적고, 대중가요식 진행은 제외 스타일로 뺀다.

| 화면 설정 | 순신 | 광개토 | 세종 | 사임당 |
|---|---|---|---|---|
| 기이함 | 20–25% | 30% | 35% | 40% |
| 스타일 영향 | 60–65% | 70–75% | 80% | 75% |
| 오디오 영향 (커버) | 70–80% | 40% | 25% | 25% |
| 다양성 | 정상 | 정상 | 정상 | 정상 |

## 1. 순신 — 한산도 `한산 학익진`

스타일:
```
Korean pansori fusion, epic naval battle, jajinmori 12/8 rhythm, steady tempo 96 BPM, buk war drums, janggu, daegeum, haegeum, taepyeongso, gayageum, ocean waves, male pansori vocal with chuimsae shouts, cinematic, powerful anthemic chorus, instrumental intro and outro
```
제외: `EDM, trap, autotune, rap, tempo change, fade out`

가사:
```
[Intro]
[Instrumental: daegeum solo over ocean waves, buk drum enters]

[Verse]
남해 바다 새벽 안개
둥 둥 북소리 물을 가른다
검은 물결 일어나니
가라앉은 망령이로구나
(얼씨구!)

[Chorus]
학의 날개 펼쳐라
한산 바다 가로질러
물결이여 일어나라
칼끝 따라 나아가라
둥 둥 둥 둥
이 바다는 우리가 지킨다

[Instrumental Break]
[Instrumental: taepyeongso and drums build]

[Chorus]
(같음)

[Outro]
[Instrumental: drums slow down, one final buk hit]

[End]
```
**쓴 판:** 첫 번째 버전 (`build/music_src/hansan_1592_v1.mp3`), 72.1 BPM, 첫 박 0.02s — 전주 0–2 / 1절 2–19 / 후렴 19–27 / 후주 54–끝 마디.
두 번째 버전은 `hansan_1592_v2.mp3`에 보관.

## 2. 광개토 — 만주 벌판 `영락의 천둥` (비장하게, 멜로디 바꾸기)

스타일:
```
Korean traditional epic, solemn tragic heroism, Goguryeo war march, jungmori 12/8 rhythm, steady tempo 76 BPM, pentatonic gyemyeonjo mode, ajaeng and geomungo low drones, daegak horn and taepyeongso calls, jing gong, heavy buk war drums, male pansori vocal with deep sigimsae ornamentation and rough husky tone, not a pop melody, cinematic, instrumental intro and outro
```
제외: `K-pop, pop ballad, western chord progression, EDM, autotune, rap, tempo change, fade out`

가사:
```
[Intro]
[Instrumental: low ajaeng drone, distant daegak horn, slow buk drum]

[Verse]
북녘 하늘 천둥이 울고
말발굽에 벌판이 운다
잠든 비석 깨어나니
영락의 왕이 돌아왔다
(어허!)

[Chorus]
천둥이여 길을 열어라
광개토의 깃발 아래
천 년 망령 쓸어 내고
땅 끝까지 달려가자
둥 둥 둥 둥
영락의 이름으로

[Instrumental Break]
[Instrumental: taepyeongso cry, war drums gather like a cavalry charge]

[Chorus]
(같음)

[Outro]
[Instrumental: drums stop, one long jing gong, wind over the steppe]

[End]
```
**주의 (2026-11-21):** 순신 곡과 화음·조성이 거의 같아(크로마 유사도 0.99) 들으면 같은 노래로 느껴짐 → 원곡 오디오 없이(페르소나, 오디오 영향 0) 다른 조성으로 다시 만들 것.
**쓴 판:** 첫 번째 버전 (`manchuria_395_v1.mp3`), 72 BPM, 첫 박 0.2s — 전주 0–2 / 1절 2–19 / 후렴 19–27 / 후주 56–끝.
두 번째 버전은 `manchuria_395_v2.mp3`에 보관.

## 3. 세종 — 경복궁 `나랏말씀` (궁중·대취타, 멜로디 많이 바꾸기)

스타일:
```
Korean royal court music meets battle march, daechwita royal military procession, steady tempo 92 BPM 4/4, taepyeongso and nabal trumpet calls, yonggo drum, jing and jabara cymbals, pyeonjong bronze bells and pyeongyeong stone chimes, ajaeng and daegeum, majestic and dignified, male jeongga court singing style with long sustained notes, call and response chant, pentatonic, not a pop melody, cinematic, instrumental intro and outro
```
제외: `K-pop, pop ballad, western chord progression, rock guitar, EDM, autotune, rap, tempo change, fade out`

가사:
```
[Intro]
[Instrumental: pyeonjong bells and stone chimes, slow taepyeongso call, yonggo drum enters]

[Verse]
근정전 달빛 아래
붓 끝에 별이 내린다
궁문 밖 북녘 바람
망령의 무리 몰려오누나
(지화자!)

[Chorus]
소리를 담아 빛이 되어라
백성의 말이 방패가 되리
하늘의 별아 글이 되어라
이 궁궐을 내가 지키리
둥 둥 둥 둥
나랏말씀이 빛나리라

[Instrumental Break]
[Instrumental: daechwita march, taepyeongso and nabal trumpets, jabara cymbals crash]

[Chorus]
(같음)

[Outro]
[Instrumental: march slows, bronze bells ring, one final jing]

[End]
```
**v2 (2026-11-21, "너무 경박해 진지하게"):** 종묘제례악·정가풍 68 BPM으로 다시 — 기이함 20%, 스타일 영향 85%, 오디오 영향 25%;
제외에 `upbeat, cheerful, playful, bouncy, festive, march, fast tempo, jabara cymbals, chuimsae shouts` 추가, 지화자 뺌.
후렴: 백성의 소리를 글로 새겨 / 어둠을 밝히는 빛이 되라 / 하늘의 별이 글이 되니 / 이 나라를 내가 지키리 / 둥 둥 둥 둥 / 나랏말씀이 빛나리라
(새 곡이 오면 다시 자른다.)

**쓴 판 (v1, 교체 예정):** `gyeongbokgung_1433_v1.mp3`, 122 BPM, 첫 박 0.17s — 전주 0–7 / 1절 7–23 / 후렴 23–31 / 후주 62–끝.

## 4. 사임당 — 초충도 `먹빛 정원` (가야금 산조·굿거리)

스타일:
```
Korean traditional sanjo fantasy, dreamy ink-painting garden, gutgeori 12/8 rhythm, steady tempo 84 BPM, gayageum sanjo lead, haegeum, danso and sogeum flutes, yanggeum hammered dulcimer, light janggu, soft buk accents, playful yet mysterious, minyo style vocal with gentle sigimsae, whispered chuimsae, pentatonic, not a pop melody, cinematic, instrumental intro and outro
```
제외: `K-pop, pop ballad, western chord progression, rock, EDM, autotune, rap, tempo change, fade out, heavy drums`
목소리: 사용자 목소리 그대로 (여성 목소리도 한 번 시험해 볼 것)

가사:
```
[Intro]
[Instrumental: gayageum plucks like falling drops of ink, soft danso melody]

[Verse]
비단 위에 먹을 갈아
풀벌레를 그려 넣으니
수박 넝쿨 사이로
들쥐 눈이 반짝이네
(얼쑤!)

[Chorus]
붓을 들어 춤을 추자
한 획에 꽃이 피고
두 획에 칼이 되니
그림 속을 지켜 내리
사뿐 사뿐 사뿐
먹빛 따라 날아가리

[Instrumental Break]
[Instrumental: fast gayageum sanjo run, haegeum answers, janggu speeds the groove]

[Chorus]
(같음)

[Outro]
[Instrumental: gayageum slows, last note rings like a brush lifting from paper]

[End]
```
**쓴 판:** `chochungdo_v1.mp3`, 84 BPM, 첫 박 0.26s — 전주 0–4 / 1절 4–20 / 후렴 28–36 / 후주 44–끝.

## 5. 오프닝 영상 곡 (Suno 곡 + Suno 뮤비 MP4, 입장 화면 앞)

- 30–45초, 세로 9:16 (안 되면 정사각). 커버 그림: 프롤로그 5번(네 영웅) 또는 타이틀 그림 → 뮤비 화풍이 게임과 맞음.
- 설정: 기이함 25%, 스타일 영향 80%, **원곡 오디오 없음** (커버로 만들면 순신·광개토처럼 같은 곡이 됨).
- 게임에 넣기: 엔진의 영상 모듈(theora)을 다시 켜고 템플릿 다시 빌드 → MP4를 세로 .ogv로 변환, 화면 누르면 건너뜀.

스타일:
```
Korean traditional epic overture, cinematic game opening theme, four heroes awakening against a phantom army, steady tempo 80 BPM, starts quiet and mysterious then builds to a powerful climax, low ajaeng drone, daegeum solo, haegeum, gayageum, pyeonjong bronze bells, heavy buk and geongo war drums, taepyeongso call at the climax, male and female choir chanting, pentatonic gyemyeonjo mode, not a pop melody, ink painting atmosphere, short instrumental ending
```
제외: `K-pop, pop ballad, western chord progression, rock guitar, EDM, autotune, rap, tempo change, fade out, cheerful, playful`

가사:
```
[Intro]
[Instrumental: low ajaeng drone, daegeum, one bronze bell]

[Build]
[Instrumental: buk drums, gayageum, haegeum, choir hum]

[Chant]
한얼이여 깨어나라
천 년의 어둠을 가르리라

[Climax]
[Instrumental: taepyeongso, full drums, pyeonjong bells]

[Outro]
[One long bell]

[End]
```

## 6. 다시 정함 (2026-11-21): 민요로 바꾸기

사용자 노래 멜로디가 너무 들어가 "중국스럽다" → 누구나 아는 전통 곡으로 (멜로디 저작권 없음), 목소리는 Suno **Voice**(사용자 녹음본, 다시 안 부름), 원곡 업로드 안 함.

| 무대 | 곡 |
|---|---|
| 메인 뮤비 | 본조 아리랑 |
| 순신 (한산도) | 진도아리랑 (명량의 바다) |
| 광개토 (만주) | 밀양아리랑 |
| 사임당 (초충도) | 정선아리랑 (강원, 사임당 고향) |
| 세종 (경복궁) | 종묘제례악 (진지하게, §3 v2 프롬프트) |

이전 가사를 살리고 후렴에 그 아리랑의 전통 후렴을 넣는다. 강강술래는 "사람들이 잘 모른다"로 뺌.
멜로디 안내 음원: `tools/audio/melody_guide.py` (Suno가 가락을 못 맞출 때만).

순신 스타일: `Korean folk song Jindo Arirang, famous traditional melody with the refrain "ari arirang seuri seurirang arariga nanne", southern coast namdo minyo style with deep yukjabaegi sigimsae, semachi 9/8 rhythm, steady tempo 96 BPM, janggu and buk, ajaeng, haegeum, daegeum, gayageum, ocean waves, naval battle energy, chorus sings the refrain, authentic Korean folk melody, not a pop song, instrumental intro and outro`
순신 후렴: 아리 아리랑 서리 서리랑 / 아라리가 났네 / 아리랑 응응응 아라리가 났네
