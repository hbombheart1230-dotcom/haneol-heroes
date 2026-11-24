# 게임 안 출처·저작권 표시 점검 (초안, 화면 구현은 다음 일)

> - 기준: README "외부 자산" 표 (2026-11-24, `art/enemy-rebake` 37d9a7f).
> - 무대 그림 출처의 옛 초안은 `docs/credits_draft.md`이고, 이 문서가 그 내용을 포함한다.
> - 지금 게임 안 표시는 설정 화면 아래 두 줄(`UiStyle.CREDITS`)뿐이다. 글꼴과 국악 소리만 들어 있다.

## 1. 표시 의무가 있는 것 (내보내는 게임에 들어감)

| 자산 | 라이선스 | 지금 표시 | 넣을 문구 초안 |
|---|---|---|---|
| 덕온공주체 (국립한글박물관·윤디자인그룹) | 공공누리 제3유형 (출처 표시, 변경 금지) | 있음 | 글꼴: 국립한글박물관 덕온공주체 (공공누리 제3유형) |
| 장구·꽹과리 연주 소리 ((재)전주정보문화산업진흥원, 공유마당) | 공공누리 제1유형 | 있음 | 국악 소리: (재)전주정보문화산업진흥원, 공유마당 (공공누리 제1유형) |
| 초충도 병풍 그림 소품 (국립중앙박물관 소장 전 신사임당필 초충도, 신수3550) | 공공누리 제1유형 | **없음** | 초충도 그림: 국립중앙박물관 소장 전 신사임당필 초충도 (공공누리 제1유형) |
| 만주 벌판 가장자리 먹선 (무용총 수렵도, 국립문화재연구원(현 국립문화유산연구원) 공개 사진) | 공공누리 제1유형 | **없음** | 만주 벌판 무늬: 국립문화유산연구원 무용총 수렵도 (공공누리 제1유형) |
| Godot Engine (게임 엔진, 4.7.2) | MIT (+ 엔진 안 제3자 라이브러리 고지) | **없음** | This game uses Godot Engine, available under the following license: Copyright (c) 2014-present Godot Engine contributors. Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur. (MIT 본문 전체) — 엔진의 `Engine.get_license_text()`·`get_copyright_info()`로 화면에 띄울 수 있다 |
| Health, HitBoxes, HurtBoxes and HitScans (cluttered-code) | MIT (`addons/health_hitbox_hurtbox/LICENSE`) | **없음** | Health, HitBoxes, HurtBoxes and HitScans — Copyright (c) cluttered-code, MIT License (LICENSE 본문 전체) |

- **MIT:** 저작권 문구와 허가 문구를 배포물에 넣어야 한다. 그래서 화면(예: 설정 → "만든 이들"·"라이선스")에 본문을 보여 주는 쪽이 안전하다.
- **공공누리 제1유형·제3유형:** 출처 표시가 조건이다. 제3유형인 글꼴은 파일을 바꾸면 안 되고, 지금 원본 그대로 쓴다(`tests/test_fonts.gd`가 해시 확인).

## 2. 표시 의무 없음 (감사 표기는 고를 수 있음)

| 자산 | 라이선스 | 고를 수 있는 감사 표기 |
|---|---|---|
| 효과음: StarNinjas, artisticdude, rubberduck, Independent.nu (OpenGameArt) | CC0 | 효과음: OpenGameArt의 StarNinjas, artisticdude, rubberduck, Independent.nu (CC0) |
| Asianoriental1 (무대 음악) | CC0 | |
| 바닥 결 재질: Poly Haven, ambientCG | CC0 | 바닥 질감: Poly Haven, ambientCG (CC0) |
| KayKit 캐릭터 (임시) | CC0 | 사용 중이면 Kay Lousberg (KayKit) |
| 귀선도 (『이충무공전서』, 일본 국립국회도서관 소장) | 퍼블릭 도메인 | 한산 무늬: 『이충무공전서』 귀선도 |
| 북궐후원도형 (서울대 규장각한국학연구원 소장) | 퍼블릭 도메인 | 경복궁 무늬: 규장각한국학연구원 소장 북궐후원도형 |
| 국악기 합성음, 임시 효과음 | 저장소 자산 | |

## 3. 표시와 별개로 확인한 것

- **Suno 노래 (사용자 소유, 무대곡·반주):** 상업 배포 권리는 만들 때의 Suno 요금제 약관을 따른다. **사용자 확인 2026-11-24: 유료 요금제로 만든 곡.**
- **Meshy 산출물 (순신·한산 대장 3D, 여진 궁수, 동작):** 유료 요금제 산출물 사용 조건은 Meshy 약관을 따른다. **사용자 확인 2026-11-24: 무료 크레딧분 없음.**
- **입장 그림·이야기 그림 (사용자가 GPT로 만듦):** 사용자 소유로 표시한다. 따로 고지할 의무는 없다.
- **gdUnit4 (MIT):** 시험 전용이고 내보내기에서 빠지므로(`exclude_filter`) 표시할 필요가 없다.

## 4. 화면 구현 메모 (다음 일)

- 설정 화면 아래 두 줄로는 모자란다. 공공누리 넷과 MIT 둘이 필요하다.
- 설정에 "만든 이들" 단추를 하나 두고, 누르면 두루마리 화면에 1절(필수)과 2절(감사)을 보여 준다.
- MIT 본문 두 개는 그 화면 끝에 넣는다.
