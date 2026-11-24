# 영웅 디자인 — 중국풍 벗기 (2026-11-21)

1차 시험 의견: "영웅들 중국 티를 벗어야 한다".
순서: 이 기준 → GPT 네 영웅 한 줄 그림(비교용) → 영웅별 설정화(앞·옆·뒤) → 승인 → 카드·이야기 그림 교체 → (비용 확인 후) Meshy 3D → 굽기.

## 중국풍으로 보이게 하는 것 (빼기)
- 옷 전체를 덮은 용 무늬, 번쩍이는 금장식, 화려한 관·머리 장식
- 넓은 소매에 앞섶을 깊게 엇갈린 한푸 모양, 붉은 비단에 금실 위주의 색

## 한국 쪽 단서 (넣기)
| 영웅 | 머리 | 옷·갑옷 | 들고 있는 것 | 색 |
|---|---|---|---|---|
| 순신 (조선 1592) | 전립 (붉은 술 + 공작 깃) | 징 박힌 두정갑, 무릎 아래까지 | 조선 환도 | 짙은 붉은빛 + 놋쇠 징, 남색 안감 |
| 광개토 (고구려 5세기) | 새 깃 두 개 꽂은 조우관 (절풍) | 고구려 쇠 찰갑 (고분 벽화 개마무사), 붉은 망토 | 긴 창 | 쇠 회색 + 붉은 망토 |
| 세종 (조선 1433) | 검은 익선관 | 붉은 곤룡포, 가슴에 둥근 용 흉배 하나만, 옥대 | 한글 두루마리 | 붉은색 + 금 흉배 하나 |
| 사임당 (조선 16세기) | 쪽진 머리 + 은비녀 하나 | 짧은 저고리 + 긴 치마 (또는 당의) | 붓 + 초충도 한 폭 | 옥색·상아색, 차분하게 |

## 프롬프트

공통 앞부분 (모든 그림 맨 앞):
```
painterly Korean ink-and-color style, historically accurate KOREAN (not Chinese, not Japanese) costume, muted natural colors, no dragon patterns all over the clothes, no heavy gold ornaments, no Chinese hanfu, no Chinese crown,
```

1) 네 영웅 한 줄 (비교용, 먼저):
```
Character lineup of four Korean historical heroes standing side by side at the same scale, full body, front view, plain white background: Admiral Yi Sun-sin in a red dujeonggap studded armor coat and jeollip hat with a red tassel and peacock feather holding a Joseon sword; King Gwanggaeto of Goguryeo in iron lamellar armor like the Goguryeo tomb murals with a jouguan cap with two bird feathers, red cloak and a spear; King Sejong in a red gonryongpo robe with one round golden dragon badge on the chest, black ikseongwan cap, jade belt, holding a Hangul scroll; Shin Saimdang in a simple jade and ivory hanbok with short jeogori and long chima, low jjokjin bun with one silver binyeo pin, holding a brush.
```

2) 영웅별 설정화 (3D용: 앞·옆·뒤, 팔을 조금 벌린 A자세):
```
Character turnaround sheet for 3D modeling, the same character shown three times side by side: front view, side view, back view, neutral A-pose with arms slightly away from the body, full body, plain white background, even flat lighting, no cast shadows, clean silhouette, [영웅 설명]
```
[영웅 설명]은 아래 카드 그림 프롬프트의 문장을 그대로 넣는다.

3) 카드 그림 (영웅 고르기·이야기용): 전신, 정면에서 살짝 돌아선 자세, 흰 바탕
- 순신: `Admiral Yi Sun-sin of Joseon (1592), wearing a Joseon general's dujeonggap studded armor coat in deep red with brass rivets, jeollip military hat with a red tassel and peacock feather, holding a long Joseon sword, calm resolute face with a thin moustache, sea wind in his coat`
- 광개토: `King Gwanggaeto of Goguryeo (5th century), wearing Goguryeo iron lamellar armor (chalgap) like the Goguryeo tomb murals, jouguan feather-crested cap with two bird feathers, red cloak, holding a spear, strong bearded warrior king, northern steppe wind`
- 세종: `King Sejong of Joseon (1433), wearing a red gonryongpo royal robe with a single round golden dragon badge on the chest only, black ikseongwan winged royal cap, jade belt, holding a scroll of Hangul letters, wise gentle face with a short beard, glowing Hangul characters floating softly around him`
- 사임당: `Shin Saimdang of Joseon (16th century), a scholar-painter woman wearing a simple Joseon hanbok with a short jeogori jacket and long chima skirt in soft jade and ivory, hair in a low jjokjin bun with one silver binyeo pin, no elaborate hair ornaments, holding a brush and a small painting of insects and flowers, graceful calm face`
