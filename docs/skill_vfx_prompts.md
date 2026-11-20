# 기술 이펙트 그림 — GPT 이미지 프롬프트

받은 PNG는 `assets/vfx/<파일 이름>.png`로 넣으면 그대로 바뀐다 (코드 수정 없음).
공통 조건: **1024×1024, 투명 배경(PNG), 가운데 정렬, 테두리·글자·사람 없음** (glyphs만 글자).
아이콘(`assets/ui/icons/`)과 같은 화풍: 수묵 붓 터치 + 선명한 색 하이라이트, 어두운 먹 윤곽.

공통 앞부분 (모든 프롬프트 앞에 붙임):
> Game VFX sprite, single effect centered on a fully transparent background, no frame, no border, no people, no text, top-down view for a mobile action game. Style: Korean ink-wash (sumi-e) brush painting with vivid glowing colour highlights and dark ink outlines, painterly, high detail, matching ornate fantasy skill icons.

| 파일 | 기술 | 프롬프트 (공통 앞부분 뒤에) |
|---|---|---|
| `wave.png` | 순신 해룡참·파도격·해일검기·반격 | A circular burst of crashing ocean waves curling outward in a ring, deep blue and cyan water with white foam crests and spray droplets, brush-stroke swirls. |
| `foam.png` | 순신 적중 | A small splash of white sea foam and cyan water droplets bursting outward, loose brush flecks. |
| `lightning.png` | 광개토 낙뢰·벽력돌파 | A vertical jagged lightning bolt striking down, golden-white core with orange glow, crackling side branches and electric sparks at the impact point. |
| `quake.png` | 광개토 뇌진격·정복자 | A ground-shattering impact seen from above: radiating cracks, flying rock shards and bursting orange-gold flames in a circular shockwave. |
| `meteor.png` | 세종 유성 | A flaming meteor falling diagonally with a long fire trail, molten rock core, orange and crimson flames, ember sparks. |
| `constellation.png` | 세종 성좌진 | Golden glowing stars connected by thin luminous lines forming a constellation, soft star dust and tiny sparkles. |
| `glyphs.png` | 세종 정음진·적중 | Glowing golden Korean Hangul consonants ㄱ ㄴ ㄷ ㄹ ㅁ ㅂ ㅅ ㅇ swirling in a circle, brush-written, with light trails (text allowed here). |
| `sundial.png` | 세종 해시계 | A golden magic circle shaped like a sundial face seen from above, engraved hour marks and a gnomon shadow line, faint light rays. |
| `plum.png` | 사임당 매화·화폭·초충 | A burst of pink plum blossom flowers and petals scattering outward, ink-wash branches, soft magenta glow. |
| `ink.png` | 사임당 발묵 | An explosive swirl of black and violet ink splashing outward like smoke, wet brush splatters and droplets. |
