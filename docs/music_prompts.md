# 배경 음악 Suno 프롬프트

무대별 국악풍 배경 음악을 Suno로 만들 때 쓰는 프롬프트다. 사용자가 Suno 유료 구독 중이라 상업적 사용이 가능하다 (구독 중 만든 곡). 곡이 생기면 `tools/audio/prepare_audio.py`의 MUSIC 표에 넣고 `StageTheme.music`에 연결한다.

공통 원칙:
- **가사 없음** (Instrumental 켜기). 전투 중 집중을 방해하지 않게.
- **반복용**: 처음과 끝이 자연스럽게 이어지도록 "seamless loop, no intro, no fade out"를 넣는다.
- 길이는 1분 30초~2분 30초면 충분하다 (용량).
- 서양 오케스트라만으로 가지 않게 국악기 이름을 앞에 둔다.

| 장면 | Style 칸 (영문) |
|---|---|
| 타이틀 (입장 화면) | `epic Korean traditional orchestral, solo daegeum flute intro then janggu and buk drums join, gayageum and haegeum, majestic, cinematic, slow build, instrumental` |
| 무대 1 · 395년 만주 벌판 (광개토) | `Korean traditional battle music, fast buk war drums, nabal horn, haegeum, galloping rhythm, steppe cavalry charge, intense, gugak fusion, seamless loop, no intro, no fade out, instrumental` |
| 무대 2 · 1419 대마도 / 1433 파저강 (세종) | `daechwita royal military march, taepyeongso, nabal, jing gong, buk drums, stately and determined, Joseon army, seamless loop, instrumental` |
| 무대 3 · 그림 세계 (사임당) | `dreamy Korean traditional, gayageum and yanggeum, soft daegeum, light percussion, ink painting world, mystical, gentle but rhythmic, seamless loop, instrumental` |
| 무대 4 · 1592 한산도·명량·노량 해전 (순신) | `heroic Korean naval battle music, rapid buk drums, geomungo, ajaeng, ocean waves, tense and tragic, gugak orchestral, seamless loop, no intro, no fade out, instrumental` |
| 보스전 (공통) | `intense Korean traditional boss battle, pounding buk and jing, taepyeongso, dissonant haegeum, rising tension, gugak metal fusion, seamless loop, instrumental` |
| 승리 짧은 곡 | `short triumphant Korean fanfare, taepyeongso and buk, 10 seconds, instrumental` |
| 패배 짧은 곡 | `short somber Korean daegeum solo phrase, 8 seconds, instrumental` |

곡 이름(Title)은 무대 이름으로: 예) `만주 벌판 395`.
