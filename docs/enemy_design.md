# 적 디자인 — 군대·병종 구분 (2026-11-21)

1차 시험 의견: "일본군인지 만주군인지 그게 그놈", "궁수 등 종류끼리 안 보인다".
지금 사람 적은 같은 3D 바탕을 색만 바꿔 쓴다 → **디자인부터** 다시 잡는다.
순서: 이 문서 확정 → GPT로 군대별 라인업 그림 → 사용자 승인 → (비용 확인 후) Meshy 3D → 굽기(tools/bake).
초충도(곤충·들쥐·개구리)는 이미 모양이 달라 이번 범위에서 뺀다.

## 원칙

- **군대는 머리·등으로 가른다** (위에서 내려다보는 시점이라 머리 모양과 등 장식이 가장 잘 보인다).
- **병종은 몸집·무기로 가른다**: 같은 군대 안에서 실루엣만 보고 졸병/원거리/중장/정예/보스를 알 수 있어야 한다.
- **망령 처리는 공통**: 빛나는 눈, 너덜너덜한 옷자락 끝, 발밑 옅은 도깨비불. 도깨비불 색만 군대마다 다르다.
- 한 군대 = 한 색 계열 + 한 금속색. 다른 군대와 겹치지 않게.

## 군대

| 군대 (무대) | 머리 | 등·몸 | 색 | 망령 불 |
|---|---|---|---|---|
| 왜군 (한산도 1592) | 졸병은 납작한 삿갓 진가사, 무사·대장은 앞에 초승달 장식 투구 | 등에 꽂은 좁은 세로 깃발(사시모노), 검은 옻칠 판갑 | 검정 + 진홍, 금속은 구리 | 붉은 보라 |
| 거란 (만주 395) | 정수리를 밀고 옆머리를 땋은 머리(곤발) 또는 귀덮개 달린 털모자 | 가죽 찰갑, 늑대 가죽 어깨걸이, 둥근 가죽 방패 | 황토·갈색, 금속은 청동 | 호박색 |
| 여진 (경복궁 1433) | 뾰족한 털모자, 뒤로 길게 땋은 머리 | 털 테두리 두른 긴 옷, 곰 가죽, 도끼 | 짙은 녹회색 + 흰 털, 금속은 무쇠 | 얼음 푸른색 |

## 병종 (세 군대 공통 틀)

| 병종 | 몸집 | 무기·특징 | 서 있는 모양 |
|---|---|---|---|
| 졸병 (chaser) | 보통, 마른 편 | 창 또는 짧은 칼 하나 | 앞으로 숙이고 달려드는 자세 |
| 원거리 (궁수·철포병) | 작고 가늘다 | 활(거란·여진: 큰 각궁·긴 활) / 화승총(왜군), 등에 화살통·화약통 | 꼿꼿이 서서 무기를 든 팔이 크게 보임 |
| 중장 (heavy) | 1.3배, 어깨가 넓다 | 큰 방패 + 철퇴 / 큰 도끼 / 긴 칼(노다치) | 낮고 넓게 버팀 |
| 정예 (elite) | 1.2배 | 망토와 군대 깃발, 장식 투구 | 칼을 들어 지휘하는 자세 |
| 보스 | 1.6배 이상 | 군대를 대표하는 큰 무기, 말 탄 모습도 가능 | 위압 |

## GPT 프롬프트 (군대마다 한 장: 다섯 명 라인업)

공통 앞부분:
```
Character lineup sheet for a top-down mobile action game, five ghost soldiers of the same army standing side by side at the same scale, full body, three-quarter front view slightly from above, plain white background, painterly Korean ink-and-color style, from left to right: foot soldier, ranged soldier, heavy soldier, elite officer, boss (largest). All are undead ghosts with glowing eyes, tattered cloth edges and a faint ghost-fire glow at their feet. Each type must have a clearly different silhouette and weapon. Historically grounded, no fantasy armor,
```

왜군:
```
Japanese ashigaru and samurai army of 1592: foot soldier in a flat conical jingasa hat with a yari spear, gunner with a matchlock teppo and powder flask, heavy samurai with a long nodachi sword and wide shoulder armor, elite samurai captain with a crescent maedate kabuto helmet and a tall sashimono back banner, boss naval commander in ornate black and crimson lacquered armor with a war fan. Colors black lacquer and crimson with copper metal, ghost fire red-purple. No rising sun flag.
```

거란:
```
Khitan (Biryeo) steppe nomad army of 395 AD: foot soldier with shaved crown and side braids holding a curved saber, horse-archer style archer with a large composite bow and quiver, heavy warrior with a round leather shield and spiked mace and a wolf pelt over the shoulders, elite officer with a fur hat with ear flaps and a horsetail standard, boss tribal chieftain with a wolf-head pelt and a huge curved glaive. Colors ochre and brown leather with bronze metal, ghost fire amber.
```

여진:
```
Jurchen forest hunter army of 1433: foot soldier in a pointed fur cap with a long back braid holding a hand axe, archer with a long wooden bow and a fur quiver, heavy warrior wearing a bear skin and carrying a two-handed great axe, elite warrior with a fur-trimmed long coat and a feathered standard, boss chieftain with a bear-skull headdress and a huge iron club. Colors dark grey-green with white fur and iron metal, ghost fire icy blue.
```
