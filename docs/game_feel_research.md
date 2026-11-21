# 타격감·무게감·움직임 조사와 제안 (1단계: 조사만)

> 상태: **제안서**. 아직 아무 수치도 바꾸지 않았다. 사용자가 고르면 같은 브랜치에서 구현한다.
> 기준 커밋: `main` 0e3e826. 숫자는 지금 코드와 `.tres`에서 직접 읽었다.

## 한 줄 요약

지금 게임은 **"맞히는 순간"이 약하다.** 자동 공격(가장 자주 보는 타격)에는 멈칫(히트스톱)도, 먹물 튐도 없고,
적은 죽으면 그 자리에서 바로 사라진다. 이동은 가속 없이 즉시 붙었다 떨어져서 가볍다.
그래서 **추천 순서는 ① 처치 날림(가) → ② 자동 공격 개별 멈칫·튐 → ③ 먹물·군대별 죽음(나) → ④ 이동 무게감 → ⑤ 대시 잔상 → ⑥ 예고 가독성(LoL) → ⑦ 강한 흔들림·글자(다)** 이다.

---

## 1. 지금 우리 게임의 수치 (측정)

| 항목 | 지금 값 | 위치 |
|---|---|---|
| 이동 속도 | 300~340 px/s (영웅별) | `data/heroes/*.tres` `move_speed` |
| 이동 가속·감속 | **없음** (손가락 따라 즉시 최고속/즉시 정지) | `player.gd` `compute_velocity` |
| 이동 입력 | 12px 무시, 90px에서 최고속 | `touch_move_input.gd` |
| 대시 | 200~260px / 0.12~0.14초 (≈1,700~2,100 px/s), 충전 2~4, 회복 0.9~1.1초 | 영웅 `.tres` |
| 대시 끝 미끄러짐 | 대시 속도의 40%에서 0.1초 동안 0으로 | `player.gd` `dash_glide_*` |
| 대시 무적 | 대시 전체 구간 (0.12초) | `is_invulnerable()` |
| 플릭 판정 | 정지 상태 70px·700px/s, 이동 중 140px·1,600px/s·1.8배 급가속 | `touch_move_input.gd` |
| 자동 근접 | 0.55~0.8초 간격, 90~140px, 120~180°, 피해 8~22, 넉백 100~220 | `basic_attack_data` |
| 자동 원거리 | 0.8초 간격, 700px/s, **넉백 없음** | `projectile.gd` |
| 히트스톱 | **기술에만** 0.06~0.1초, 게임 전체를 0.05배로 | `skill_context.gd` `hit_stop` |
| 자동 공격 히트스톱 | **없음** | `auto_attack.gd` |
| 적 넉백 | 충격량 × 종류 배율(잡병 1.0, 중장 0.3, 정예 0.15, 보스 0.1), 초당 8 감쇠 | `enemy.gd`, 적 `.tres` |
| 적 피격 색 | 0.1초 하얗게 (밝기 1.8배) + "hit" 동작 | `enemy.gd` |
| 먹물 튐(spark) | 기술 적중·부서지는 물건에만 0.22초 | `fx_layer.gd` |
| 데미지 숫자 | 34pt(40 이상은 48pt 붉은 인장색), 0.6초 동안 50px 위로 | `fx_layer.gd` |
| 화면 흔들림 | trauma² × 18px, 초당 2.5 감쇠. 피격 0.4, 반격 0.7, 기술 0.1~0.25, **적 처치 0.05** | `feedback.gd` |
| 적 죽음 | "die" 소리 + 흔들림 0.05, **그 자리에서 바로 사라짐** | `enemy.gd` `_on_died` |
| 효과음 | hit 0.10초, slash 0.12초, die 0.14초. 같은 소리 0.04초 안 겹침, 높낮이 ±6% | `sfx_synth.gd`, `feedback.gd` |
| 카메라 | 위치 부드럽게 따라가기 8 | `scenes/main.tscn` |
| 렌더러 | `gl_compatibility` (안드로이드) | `project.godot` |

**지금의 장점:** 대시가 빠르고(0.12초) 전 구간 무적이라 Hades처럼 시원하다. 연속 대시·대시 끊고 다시 대시가 된다.
적 예고 공격(원·직사각형)과 "예고 원을 대시로 빠져나가면 회피 → 반격"은 이미 좋은 뼈대다.

**지금의 약점:**
1. 가장 자주 보는 자동 공격이 "소리 + 숫자 + 살짝 밀림"뿐이다. 멈칫·튐이 없다.
2. 적이 죽을 때 몸이 날아가거나 쓰러지는 순간이 없다 → "베었다"는 확신이 약하다.
3. 히트스톱이 게임 전체를 멈춘다. 자동 공격에 그대로 쓰면 0.55초마다 내 이동도 끊긴다 → 다른 방식이 필요하다.
4. 이동에 가속·감속이 없어 캐릭터가 종이처럼 가볍다. 광개토(무거운 장수)와 사임당(가벼운 화가)의 차이도 속도 숫자뿐이다.
5. 원거리 공격은 맞혀도 적이 밀리지 않는다.

---

## 2. 레퍼런스 게임에서 가져올 것

| 게임 | 핵심 강점 | 우리에게 맞는 부분 |
|---|---|---|
| **Hades** | 모든 타격에 뚜렷한 반응, 제약 없는 대시, 적의 의도가 또렷한 동작 | 짧고 빠른 대시 + 넉넉한 무적, 적 피격 반응, 처치 시 날아감 |
| **League of Legends** | "명확성(Clarity)": 보고 바로 이해하고 반응할 수 있게. 공격 준비 동작(윈드업)과 취소 규칙이 분명 | 예고 영역의 일관된 색·채워지는 모양, 위험은 늘 같은 말로 |
| **Dead Cells** | 격투 게임에서 가져온 멈춤·느려짐·입자. 무기마다 넉백 크기가 크게 다름 | 무기(영웅)별 넉백·멈칫 차이, 처치 시 조금 더 긴 멈칫 |
| **Death's Door** | "빠른 아케이드 흐름의 젤다". 스태미나 없이 구르기·공격이 매끄럽게 이어짐 | 대시 → 공격 연결이 끊기지 않게, 4방 맞으면 죽는 긴장 |
| **Hollow Knight** | 때릴 때 **나도** 살짝 밀림(반동) → 칼이 실제로 닿은 느낌 | 근접 적중 시 플레이어 반동 아주 살짝 |
| **Archero** | 한 손 세로 화면. "멈추면 쏜다" 하나의 규칙으로 판단을 만듦 | 한 손 조작의 단순함 유지. (우리는 이동 중 자동 공격이라 이미 더 자유로움) |
| **Smash Bros (사쿠라이)** | 히트스톱의 교과서: 멈출 때 **맞은 쪽을 더 흔들고**, 판정 상자는 안 움직이게 | 적만 멈추고 흔드는 "개별 멈칫" |

### 2.1 히트스톱(멈칫)
- **사쿠라이(Smash):** 멈춤이 없으면 전투가 "붕 뜨고 부정확하게" 느껴진다. 멈추는 동안 맞은 캐릭터를 더 많이 흔들고, 판정은 움직이지 않게 한다. 땅에서는 좌우, 공중에서는 위아래로 흔든다.
- **Dead Cells:** 개발자 본인이 "모든 피드백은 격투 게임(스트리트 파이터 4, 블레이블루)에서 왔다, 멈춤·느려짐·입자를 많이 쓴다"고 말했다. 블로그 추정치로는 근접 적중마다 2~3프레임(≈33~50ms), 처치 일격은 더 길다 (개발자 공식 수치는 아님).
- **일반적 기준(여러 가이드):** 약한 타격 2~4프레임, 강한 타격 4~8프레임, 보스 마무리는 그 이상 + 느린 화면.
- **우리에게:** 게임 전체를 멈추는 지금 방식은 기술·처치용으로 남기고, 자동 공격은 **맞은 적만** 멈추고 흔든다 (내 이동은 계속).

### 2.2 넉백·처치 날림
- **Dead Cells:** 무기마다 넉백 크기가 크게 다르다는 분석 (단검 약하게, 양손검 강하게 — 블로그 수치라 미확인).
- **Hades:** 처치된 적은 맞은 방향으로 튕겨 나가며 사라진다. 큰 일격일수록 멀리.
- **Vlambeer "The Art of Screenshake":** 같은 슈팅 게임에 적 넉백 → 플레이어 반동 → 히트 멈춤 → 시체 남기기를 하나씩 더하면서 손맛이 쌓이는 걸 보여 준 강연. "시체·흔적을 남겨라"가 핵심 교훈 중 하나.

### 2.3 화면 흔들림
- **Squirrel Eiserloh (GDC 2016):** "trauma" 모델 — 사건마다 trauma를 더하고 시간에 따라 줄이며, 흔들림 = trauma² (또는 ³). 우리는 이미 이 방식이다.
- **추가로 쓸 만한 것:** 무작위 흔들림 대신 **맞은 방향으로 한 번 툭 밀리는 흔들림**(방향 킥)이 작은 화면에서 덜 어지럽고 더 묵직하다. 사쿠라이도 상황별로 흔들림 방향을 바꾼다.
- **모바일 주의:** 작은 세로 화면에서 자주 흔들면 피로하고 멀미가 난다 → 자동 공격에는 흔들림을 거의 안 쓰고, 처치·피격·기술에만.

### 2.4 공격 준비·확정·회복 (윈드업/커밋/리커버리), 동작 취소
- **LoL:** 기본 공격은 "준비 동작 → 발사 → 회복"으로 나뉜다. 준비 중 취소하면 공격이 안 나가고, 발사 후 회복 중 취소하면 피해는 들어가고 바로 움직일 수 있다 (동작 취소, 카이팅의 기본).
- **Hades:** 공격 중에도 대시로 언제든 끊을 수 있다 → 답답함이 없다.
- **우리에게:** 자동 공격은 준비 동작이 없고(바로 판정), 대시는 언제든 된다. **이 부분은 이미 LoL 회복 취소 + Hades 대시 취소 수준이라 바꿀 필요가 적다.** 대신 *적*의 준비 동작을 더 읽기 좋게 만드는 쪽이 이득이다(2.6).

### 2.5 이동 가속, 대시 무적
- **Hades:** 출발·정지가 아주 빠르다(거의 즉시). 대시는 짧고 빠르며 가운데 구간에 무적이 있다. Hades 1의 무적은 "넉넉하다"는 평이 많고, Hades 2는 더 신중한 대시로 바꿨다가 "1편 대시를 돌려 달라"는 반응이 많았다 → **시원한 대시는 지켜야 할 장점.**
- **LoL:** 이동은 클릭 즉시 최고속, 가속이 없다. 대신 무게감은 *공격 동작*과 *돌진기의 궤적*으로 표현한다.
- **우리에게:** 완전 즉시 이동은 반응은 좋지만 가볍다. **아주 짧은 가속(0.04~0.08초)**만 넣어도 "발을 디딘다"는 느낌이 생기고, 영웅별로 다르게 하면 성격이 산다. 대시 무적(전 구간)은 그대로 둔다.

### 2.6 예고와 가독성 (LoL)
- **Riot "Clarity in League":** 명확성 = 무슨 일이 일어나는지 이해하고 반응할 수 있는 능력. 화면과 소리가 기술·공격을 빠르게 구분하게 도와야 하고, 설명을 안 읽어도 해 보면 알 수 있어야 한다.
- **실제 LoL 규칙:** 위험 영역은 같은 모양 언어(바깥선 + 안쪽이 차오름), 적·아군 색이 일정, 큰 기술일수록 예고가 길고 크다.
- **우리에게:** 이미 `windup_ratio()`(예고 진행률)가 있다. 예고 원을 **바깥 테두리 + 안쪽이 먹으로 차오르는** 한 가지 언어로 통일하고, 다 차는 순간 "탁" 소리와 번쩍 → 회피 타이밍이 한눈에 보인다.

---

## 3. 제안 (순위순)

각 제안: **무엇을 / 숫자 / 비용(작업·모바일 성능)**. 숫자는 전부 Resource(데이터)로 뺀다.

### ① 가 — 처치 날림 + 먹 자국 ★ 추천
- **무엇을:** 죽은 적이 바로 사라지지 않고, 마지막 일격 방향으로 포물선을 그리며 날아가 빙글 돌고, 떨어진 자리에 먹 자국을 잠깐 남긴다. 세게 맞을수록 멀리. 보스·정예 마무리는 화면이 잠깐 느려진다.
- **숫자(초안):**
  - 날아가는 시간 0.35~0.5초, 거리 = 80px + 마지막 피해 × 3 (최대 320px), 높이(가짜 Z) 40~90px, 회전 1~2바퀴
  - 착지 먹 자국: 0.8초에 걸쳐 옅어짐
  - 정예·보스 처치: 게임 속도 0.25배로 0.35초(실시간) + trauma 0.6
  - 동시에 날아가는 시체 **최대 12개** (넘으면 가장 오래된 것부터 바로 사라짐)
  - 처치 흔들림 0.05 → 0.12, 처치 멈칫(전체) 0.03초
- **비용:** 작업 중간 (시체 노드 하나 + 데이터 `KillFeelData` + 테스트). 성능 낮음 — 스프라이트 한 장 Tween, 상한 12개. 적 스프라이트를 그대로 재사용하므로 새 그림이 필요 없다.

### ② 자동 공격 "개별 멈칫" + 튐 + 원거리 넉백 ★ 추천 (가장 싸고 효과 큼)
- **무엇을:** 자동 근접이 맞으면 **맞은 적만** 아주 잠깐 멈추고 좌우로 떨린다 (사쿠라이 방식, 내 이동은 안 끊김). 맞은 자리에 먹물 튐. 원거리 탄에도 약한 넉백. 근접 적중 시 플레이어가 3~6px 살짝 반동(Hollow Knight).
- **숫자(초안):**
  - 적 개별 멈칫 0.05초(약), 피해 20 이상 0.08초, 떨림 ±4px
  - 하얀 번쩍임 0.1 → 0.08초 + 첫 0.03초는 완전 흰색(더 또렷)
  - 근접 적중마다 먹물 튐 1개 (지금은 기술만)
  - 원거리 넉백 60 (근접의 약 절반)
  - 플레이어 반동 4px, 0.06초
  - 영웅별: 광개토는 멈칫 1.4배·넉백 크게, 사임당은 0.8배 (기존 `BasicAttackData`에 필드 추가)
- **비용:** 작업 작음. 성능 거의 없음 (타이머 하나). 전체 멈춤이 아니라서 조작감 손해가 없다.

### ③ 나 — 먹물 방울·잔해 + 군대별 죽음 모양 ★ 추천
- **무엇을:** 타격마다 먹물 방울이 맞은 방향 반대쪽으로 흩어지고, 죽을 때 군대마다 다르게 사라진다.
  - 망령 군대 → 푸른 연기로 흩어짐
  - 초충도 생물 → 종이가 찢어지며 먹이 번짐
  - (보스 → 금빛 먹 + 인장 낙관)
- **숫자(초안):** 타격당 방울 3~5개, 처치 시 8~12개, 화면 전체 방울 **최대 60개**, 수명 0.3~0.5초. 죽음 모양은 `EnemyData`에 `death_style` 하나 추가.
- **비용:** 작업 중간 (FxLayer에 그리기 종류 2~3개 + 데이터). 성능: `_draw` 방식이라 개수 상한만 지키면 `gl_compatibility`에서도 가볍다. GPU 입자보다 지금 FxLayer 확장이 안전하다.
- **가와 함께:** 날아간 시체가 착지할 때 군대별 죽음 모양이 터지면 자연스럽게 이어진다 → **가 + 나 조합 추천 유지.**

### ④ 이동 무게감 (가속·감속, 영웅별)
- **무엇을:** 출발할 때 아주 짧게 가속, 멈출 때 짧게 감속. 영웅마다 다르게.
- **숫자(초안):** 최고속까지 — 사임당 0.04초, 세종·순신 0.06초, 광개토 0.09초. 정지 — 0.05~0.08초. 대시·대시 끝 미끄러짐·연속 대시는 그대로.
- **위험:** 실기기에서 "굼떠졌다"고 느낄 수 있다 → 설정에 0으로 끌 수 있게 하거나, 먼저 아주 작게(0.04초 공통) 시험.
- **비용:** 작업 작음 (`HeroData`에 2개 필드, `compute_velocity`에 `move_toward`). 성능 없음.

### ⑤ 대시 잔상과 먼지
- **무엇을:** 대시 동안 먹빛 잔상 2~3장이 뒤에 남고, 출발점에 먹 먼지 한 번. 광개토 돌진은 땅이 갈라지는 획.
- **숫자(초안):** 잔상 0.03초 간격 최대 3장, 각 0.15초에 걸쳐 사라짐. 대시 시작 trauma 0 유지(흔들림 없음), 소리만.
- **비용:** 작업 작음. 성능 낮음 (스프라이트 3장).

### ⑥ 적 예고 가독성 (LoL 방식)
- **무엇을:** 예고 영역을 "바깥 먹선 + 안쪽이 차오름" 한 가지 언어로 통일. 다 차는 순간 짧은 소리 + 번쩍. 보스 큰 기술은 예고가 더 길고 테두리가 붉은 인장색.
- **숫자(초안):** 차오름 = `windup_ratio()` 그대로, 마지막 0.1초 테두리 두께 2배, 발동 소리 0.06초.
- **비용:** 작업 작음~중간 (그리기만 바꿈, 판정 그대로). 성능 없음. 무대 4곳 배경 위에서 다 잘 보이는지 실기기 확인 필요.

### ⑦ 다 — 더 센 히트스톱·흔들림·숫자 + 붓글씨 연타 글자
- **무엇을:** 히트스톱·흔들림·숫자를 전반적으로 키우고, 연속 타격 수를 붓글씨("十連", "百斬" 같은)로 띄움.
- **숫자(초안):** 기술 히트스톱 0.06~0.1 → 0.08~0.14초, 숫자 크기 34/48 → 38/60 + 처음 0.08초 크게 튀어나옴, 연타 5·10·20·50에서 글자.
- **순위가 낮은 이유:** 작은 세로 화면에서 흔들림·멈춤을 키우면 피로와 조작 끊김이 먼저 온다. 숫자·글자가 늘면 화면이 지저분해져 예고(⑥)를 가린다. ①②가 들어간 뒤 부족한 만큼만 올리는 게 안전하다.
- **비용:** 작업 작음(숫자만) ~ 중간(연타 글자). 성능 낮음.

### 덤 — 소리 (음악은 본 세션 담당이라 효과음만)
- 타격음을 "둔탁한 저음 + 짧은 베는 소리" 두 겹으로, 처치음은 따로 더 크게. 연속 타격 때 높낮이를 조금씩 올리기(최대 +12%).
- 작업 작음. ①② 구현 때 같이 하면 좋다.

---

## 4. 순위 정리

| 순위 | 제안 | 효과 | 작업 | 모바일 성능 | 조작감 위험 |
|---|---|---|---|---|---|
| 1 | ① 가: 처치 날림 + 먹 자국 | 매우 큼 | 중 | 낮음 (상한 12) | 없음 |
| 2 | ② 자동 공격 개별 멈칫·튐·원거리 넉백 | 큼 | 작음 | 거의 없음 | 없음 |
| 3 | ③ 나: 먹물 방울 + 군대별 죽음 | 큼 | 중 | 낮음 (상한 60) | 없음 |
| 4 | ④ 이동 가속·감속 (영웅별) | 중 | 작음 | 없음 | **있음** (굼뜸) |
| 5 | ⑤ 대시 잔상·먼지 | 중 | 작음 | 낮음 | 없음 |
| 6 | ⑥ 예고 가독성 (LoL) | 중 (어려운 판일수록 큼) | 작음~중 | 없음 | 없음 |
| 7 | ⑦ 다: 더 센 멈칫·흔들림·글자 | 중 | 작음~중 | 낮음 | 있음 (피로) |

**"Hades + LoL의 장점"으로 묶으면:**
- Hades에서: ①처치 날림, ②타격 반응, ⑤시원한 대시 (지금 대시는 유지)
- LoL에서: ⑥예고 언어 통일, (이미 있는) 동작 취소의 자유
- 추천 1차 묶음: **① + ② + ③** (가 + 나 + 자동 공격 멈칫). 한 번의 APK로 함께 확인.
- 2차: ④·⑤·⑥은 1차 APK 손맛을 보고 결정. ⑦은 마지막에 부족한 만큼만.

## 5. 사용자가 정할 것

1. **1차 묶음:** ①+②+③ 추천대로 갈지, 일부만(예: ①+②) 먼저 볼지.
2. **이동 가속(④):** 넣을지, 넣는다면 영웅별로 다르게 할지 / 아주 작게 공통으로 시험할지.
3. **처치 슬로모션:** 정예·보스 마무리에만(추천) / 일반 적 여러 마리 동시 처치에도.
4. **흔들림:** 지금처럼 무작위 흔들림 / 맞은 방향으로 툭 밀리는 흔들림(추천).

## 출처

- Masahiro Sakurai, 히트스톱 해설 — [GoNintendo: 8 hit stop techniques](https://www.gonintendo.com/contents/13581-sakurai-s-latest-game-dev-video-features-8-hit-stop-techniques), [Source Gaming: Famitsu 칼럼 번역](https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/), [Nintendo Wire](https://nintendowire.com/news/2022/12/12/this-week-in-sakurai-12-5-12-11-fine-tuning-hit-stop-and-cheating-the-system/)
- Dead Cells — [Game Developer: 50개 무기를 다르게 느끼게](https://www.gamedeveloper.com/design/designing-each-of-the-50-weapons-in-i-dead-cells-i-to-feel-distinctive), [Game Developer: Sébastien Bénard 디자인 해설](https://gamedeveloper.com/design/sebastien-benard-breaks-down-the-fine-details-of-i-dead-cells-i-design), [80.lv: 공정하게 느끼게 하는 숨은 장치](https://80.lv/articles/dead-cells-hidden-tricks-that-make-the-game-feel-fair)
- Hades — [Medium: How Hades Creates a Responsive Underworld](https://medium.com/@Nat.Rowley/how-hades-creates-a-responsive-underworld-915715a7c2a), [PC Gamer: Hades 팁 (대시 무적·아테나)](https://www.pcgamer.com/hades-guide-tips-and-tricks), [Gameland: Hades 2 대시 비교](https://gameland.gg/hades-2-melinoes-dash-is-great-youre-just-using-it-wrong/), [PC Gamer: Hades 2 변화](https://pcgamer.com/games/action/if-youre-struggling-with-hades-2s-small-changes-dont-worrytheyll-click)
- League of Legends — [Riot: Clarity in League](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/), [Riot: Ask Riot — 명확성](https://na.leagueoflegends.com/en-us/news/dev/ask-riot-let-s-talk-clarity/), [Dignitas: 동작 취소 원리](https://dignitas.gg/articles/how-animation-cancels-work-in-league-of-legends), [Riot Nexus: Riven 애니메이션](https://nexus.leagueoflegends.com/en-us/2017/07/animating-order-and-chaos/)
- Death's Door — [Byteside: Acid Nerve 인터뷰](https://byteside.com/2021/08/deaths-door-developer-acid-nerve-on-how-it-made-its-sword-wielding-crow-game), [Game Informer Afterwords](https://www.gameinformer.com/afterwords/2021/09/22/afterwords-deaths-door)
- Hollow Knight — [WPI 게임 메카닉 위키: Recoil](https://dgmiwiki.wpi.edu/mechanic/recoil), [Hollow Knight Wiki: Combat](https://hollowknight.wiki/w/Combat_%28Hollow_Knight%29)
- Archero — [Deconstructor of Fun](https://www.deconstructoroffun.com/blog/2019/8/9/why-archero-banked-25m-but-leaves-25m-hanging-hlx9n), [Game Developer: Finding the Fun — Archero](https://gamedeveloper.com/design/finding-the-fun-archero-part-1---gameplay)
- 일반 — [Vlambeer "The Art of Screenshake" 정리](https://infovore.org/?p=5275), [재현 데브로그](https://dkliao.itch.io/the-art-of-screenshake-recreation/devlog/451576/quick-breakdown-of-all-the-effects), [GDC Vault: Juicing Your Cameras With Math (Eiserloh)](https://gdcvault.com/play/1023146/Math-for-Game-Programmers-Juicing), [Godot 포럼: trauma 흔들림·실시간 히트스톱](https://forum.godotengine.org/t/game-feel-effects-that-stack-without-fighting-your-code-trauma-shake-real-time-hit-stop-and-apply-the-difference/146379)

> 주의: Dead Cells 프레임 수, Hades 무적 프레임 같은 세부 숫자는 개발사 공식 수치가 아니라 커뮤니티·블로그 추정이다. 제안 숫자는 이를 참고한 **초안**이고, 실기기 APK로 조정한다.

---

## 구현 기록 (사용자 선택: ①②③④ + 정예·보스만 슬로모션 + 방향 흔들림, 이어서 기술 이펙트)

- **수치 위치:** 공통 `data/feel/combat_feel.tres` (CombatFeelData + InkBurstData), 영웅별 `data/heroes/*.tres`(가속·반동·원거리 넉백), 적별 `data/enemies/*.tres`(`launch_scale`, `death_style`), 기술 이펙트 `data/vfx/<영웅>_{cast,hit,impact}.tres`.
- **히트스톱 버그 수정:** `SceneTreeTimer(ignore_time_scale)`가 느린 시간에서 5~20배 일찍 끝나, 기존 기술 히트스톱이 거의 보이지 않았다. `GameTime.stop`이 실제 시간(ms)으로 매 프레임 확인하도록 바꿨다. 겹치면 더 긴 멈춤이 이기고, 인장 느린 시간 위에서도 이어진다.
- **영웅 달리기:** 달리는 중 자동 공격 동작이 달리기를 끊지 않음, 8방향 경계 떨림 방지(10°), 다리 속도 = 실제 속도, 달리기 시트 8→12프레임(같은 0.57초 주기).
- **기술 이펙트 (2단계):** 순신 물보라·물방울, 광개토 꺾인 번개 줄기·불똥, 세종 별·한글 자모, 사임당 먹 덩어리·매화 꽃잎. 발동(cast)·적중(hit)·내리꽂힘(impact) 세 순간에 터진다.
  - **외부 텍스처를 쓰지 않은 이유:** CC0 팩(Kenney 등)을 검토했으나, 필요한 모양(점·별·꽃잎·불똥·먹 덩어리)은 엔진 기본 `Image`·`FastNoiseLite`로 64px 텍스처를 코드에서 만들 수 있었다. APK 용량 0, 내려받기·라이선스 기록 불필요. 수묵풍은 `shaders/ink_vfx.gdshader`(가장자리 잡음 갉기 + 먹 테두리)로 입힌다. 그래서 README "외부 자산"에 추가할 항목이 없다.
  - **모바일 상한:** 기술 입자 160개, 먹물 방울 60개, 날아가는 시체 12개. 모두 노드 하나의 `_draw`로 그리고 배열을 새로 만들지 않는다.

---

## 적이 잘 보이게 (사용자: "몹들 칙칙해서 잘 안 보임")

- **문제:** 왜군·여진 망령이 회색으로 구워져 서로 비슷하고, 무대 지도(모래·돌바닥·갑판)에 묻혔다.
- **한 것:** `shaders/enemy_rim.gdshader` — 몸 둘레 망령 빛 테두리 + 밝기·대비 올리기 + 군대 색. 수치는 `EnemyData`의 "잘 보이게" 묶음, 군대 값은 `tools/ai3d/make_enemy_data.py`의 `ARMY_LOOK`(다시 만들어도 유지).
  - 왜군 = 차가운 쪽빛, 여진 = 서리 청록, 거란·비려(1무대) = 먹 테두리(모래 위에서 가장 또렷), 초충도 = 먹 윤곽선(원래 그림 색 유지). 정예·보스는 테두리를 더 크게.
  - 텍스처 한 장에서 8점만 읽고, 시트의 지금 칸 밖은 읽지 않는다. 적 종류마다 재질 하나를 공유한다.
- **전후 비교 (위 = 전, 아래 = 후; 1무대·경복궁·한산도·초충도):** `docs/images/enemy_readability_before_after.png` — `tools/shots/stage_shot.gd`로 찍음.

## 적 행동 (사용자 승인: 공통 → 군대별 → 무리 이벤트 → 정예 변종)

| 참고 | 가져온 것 |
|---|---|
| **Doom 2016** (공격권) | 동시에 덤비는 적 수를 공격권으로 제한하고, 권이 없는 적은 둘레를 돌며 압박한다. 난도가 오르면 권 수를 늘린다. |
| **Hades** (예고·회복, 정예) | 공격 전 또렷한 예고, 공격 뒤 빈틈. 정예는 표시(테두리 색·이름)와 특별한 성질(철갑 등). |
| **Vampire Survivors / Halls of Torment** (무리) | 일정 시간마다 포위 고리가 좁혀 오기, 한쪽에서 쓸고 지나가는 벽, 한 방향에서 몰려오는 떼. |
| **Diablo** (무리 우두머리) | 정예 변종(철갑·질풍·분열)이 무리의 우선 표적이 되게. |

- **공통:** 공격권 3개(`data/enemies/enemy_ai.tres` `max_melee_tokens`), 권 없는 근접 적은 240px 고리에서 옆걸음. 공격 직후 경직은 처벌 시간(피해 ×1.3, 머리 위 흰 소용돌이). 치기 직전 몸이 번쩍인다.
- **군대별 (`data/enemies/behaviour/*.tres`):**
  - 비려 기마 궁수: 조준 중에도 뒤로 물러나며 쏜다(파르티아식).
  - 여진 졸병·장사: 직선 돌진 예고 → 빗나가면 멀리 미끄러지고 오래 빈틈.
  - 왜군 철포: 같은 박자(2.6초)에만 조준을 시작해 함께 쏜다. 왜군 무사: 앞 120° 피해 ×0.3(뒤·옆을 노려야 함).
  - 초충도: 방아깨비는 포물선으로 뛰고, 사마귀는 흐릿하게 숨어 있다가 가까이 오면 덮치고, 개구리 장군은 혀로 끌어당긴다.
- **무리 이벤트:** 25초에 처음, 이후 30초마다 포위 → 휩쓸기 → 떼 순서.
- **정예 변종:** 철갑(받는 피해 ×0.55), 질풍(속도 ×1.5), 분열(죽으면 작은 적 3마리).

출처: [Game Developer: The AI of DOOM (2016)](https://www.gamedeveloper.com/design/cyber-demons-the-ai-of-doom-2016-), [GDC Vault: Bringing Hell to Life — AI and Full Body Animation in DOOM](https://gdcvault.com/play/1024186/Bringing-Hell-to-Life-AI), [Hades 위키: 적·정예](https://hades.wiki.fextralife.com/Enemies), [PC Gamer: Hades 팁(철갑)](https://www.pcgamer.com/hades-guide-tips-and-tricks), [TheGamer: Vampire Survivors 꽃 포위](https://www.thegamer.com/vampire-survivors-flower-venus-flytrap-circle-annoying/), [Epic: Vampire Survivors와 장르](https://store.epicgames.com/news/vampire-survivors-built-genre-autoshooter-bullet-heaven).

## 기술 이펙트 2차 (사용자: "너무 선이고 비루해, 강화해도 안 화려해짐, 적어도 아이콘만큼은")

- **그려진 이펙트:** `VfxDecals` + `shaders/ink_decal.gdshader` — 그림이 커지며 돌고, 수명 후반에 먹 번지듯 사라진다. 아래에 더하기 빛 층.
- **그림:** 지금은 기술 아이콘에서 효과 부분만 뽑은 것 (`tools/vfx/icon_to_vfx.py` → `assets/vfx/*.png`: 물결·지진 불길·번개·유성·별자리·해시계·매화·먹). 사람 얼굴이 든 아이콘은 쓰지 않음. 더 좋은 그림은 `docs/skill_vfx_prompts.md`의 GPT 프롬프트로 만들어 같은 이름으로 넣으면 끝 (코드 수정 없음).
- **강화하면 화려해짐:** 성장으로 기술을 고칠 때마다 `SkillDef.vfx_level` +1, 큰 변형 +3 (`UpgradeDef.vfx_level_gain`). 단계마다 크기 +12%, 입자 +25%, 빛 +12%, 2단계부터 그림 한 겹 더, 4단계부터 금빛 고리 (최대 6단계, 모두 `SkillVfxData`).
- **기술마다 다른 그림:** `data/vfx/skill/<영웅>_<기술>.tres` (16개).
- **모바일 상한:** 그림 24장, 입자 160개, 한 노드 `_draw`.
- **전후 비교:** `docs/images/skill_vfx_before_after.png` (위 = 이전, 아래 = 지금 강화 0단계/최대 단계; 순신·광개토·세종·사임당). `tools/shots/vfx_shot.gd`로 찍음.

## 기술 이펙트 3차: 사용자 GPT 그림 + 영웅별 회피

- **GPT 그림 적용** (`tools/vfx/gpt_to_vfx.py`): 투명 PNG의 가장자리 빨강·노랑 물듦은 안쪽 색으로 바꾸고 옅은 안개는 지움, 흰 바탕 묶음 그림은 흰색을 빼서 알파를 만듦. 256px.
  - 고른 판: 유성 v2, 물보라 v1, 물결 v1, 지진 v1, 번개 v2(v1은 안개 상자), 별자리 v2(v1은 어두운 원판). 정음 자모·해시계·매화·먹은 묶음 그림에서 잘라냄.
  - 그림이 주인공이 되도록 기술 이펙트의 작은 입자는 수 ½, 크기 0.6배로 줄임.
  - 결과: `docs/images/skill_vfx_gpt.png` (위 = 강화 0단계, 아래 = 최대 단계).
- **영웅별 회피** (`HeroData.dash_style` → `data/heroes/dash/*.tres`, `DashStyleRunner`): 생김새 + 작은 도착 효과 하나씩 (균형 유지).
  - 순신: 물보라로 출발, 물방울 자취, 물결 고리로 도착 → 둘레 적을 살짝 밀침.
  - 광개토: 몸이 거의 사라지는 번개 순간이동, 불똥 자취, 벼락으로 도착 → 둘레 적 0.3초 기절.
  - 세종: 정음 자모 고리로 출발, 글자 자취, 해시계로 도착 → 둘레 적 1.2초 느리게.
  - 사임당: 먹으로 흩어져 이동, 먹 자취, 매화로 도착 → 출발 자리에 먹 웅덩이 (그 둘레 적 1.5초 느리게).
  - 결과: `docs/images/dash_styles.png` (위 = 출발, 아래 = 도착).

## 4차: 직선 기술 띠, 유성 낙하, 영웅별 원거리 탄, 회피는 자취만 (실기기 피드백)

- **회피:** 둥근 그림(해시계·물결 고리 등)을 없앰 → 지나간 길에 가는 띠(물길·번개 줄기·먹 자국, 세종은 금빛 붓 획) + 작은 도착 입자만. 기술과 헷갈리지 않게.
- **직선 기술:** 파도격·벽력돌파·발묵은 경로를 따라 띠 그림이 앞으로 펼쳐진다 (`SkillVfxData.strip`, `VfxDecals.strip`). 끝에 찍던 둥근 그림은 없앰. 해일검기는 물결 그림 탄.
- **정음진:** 글자 고리 밑에 정음 자모 그림이 함께 돈다. **초충:** 나비·방아깨비가 문 자리에 꽃잎.
- **유성:** 하늘에서 떨어지는 유성 그림 → 폭발 그림 + 오래 남는 불꽃.
- **원거리 탄:** 영웅마다 그림·크기·자취 (`BasicAttackData` 탄 그림 묶음): 순신 물칼, 광개토 번개 창, 세종 큰 금빛 자모, 사임당 먹 붓. 던지는 동작 0.12초 뒤 손 앞(앞 30~36px, 위 40~52px)에서 나간다.
- **그림:** `wave_strip / lightning_strip / explosion / proj_water / proj_spear / proj_ink`는 사용자 GPT 그림 (`tools/vfx/gpt_to_vfx.py`로 가장자리 정리, 가로 그림은 비율 유지). `ink_strip`은 먹 붓 획 그림(proj_ink 원본)을 길게 씀. 임시 그림 도구 `tools/vfx/make_placeholders.py`는 이미 있는 그림을 덮어쓰지 않는다.
- 결과: `docs/images/lines_projectiles_dash.png` (영웅마다 위 = 직선 기술 띠 / 세종은 떨어지는 유성, 가운데 = 원거리 탄·해일검기, 아래 = 회피 자취; 맨 오른쪽 = 유성 폭발 강화 0단계/최대).
- **코드 도형 없애기 (사용자 규칙: "기본 동그라미·선이 보이면 안 됨"):** 기술이 부르던 범위 고리·검기 선·타격 튐, 장판(먹 웅덩이 등), 충전 표시, 근접 베기 호를 전부 무채색 붓 그림에 기술 색을 곱해 그린다 (`tools/vfx/make_neutral.py` → `assets/vfx/brush_{ring,stroke,splat,pool,crescent}.png`, `CombatFeelData` 붓 그림 묶음). 정음진은 그림 고리만, 회피는 동그라미 자취 없이 띠만, 초충 나비·방아깨비는 꽃잎·풀잎 그림. 결과: `docs/images/brush_instead_of_shapes.png`. 적 예고 영역·기절/느려짐 표시·처치 연출은 기술이 아니라 그대로 둠.
- **세종 원거리 동작:** 던질 때 "고개가 좀비 같다" ('Charged Spell Cast') → 사용자 승인으로 Meshy 'Mage Soell Cast 4'(action 133, 한 팔로 앞으로 던짐, 고개 바로) 추가, 3크레딧 사용 (1,936 → 1,933). `throw` 동작으로 다시 구움 (8프레임·18fps), 글자는 던지는 프레임(0.17초)에 손에서 나간다 (`ranged_anim = throw`, `release_delay = 0.17`).

## 5차: 궁극기 모으기 발밑 표시 영웅별로 (사용자: "기 모으는 거 바닥 표시 영웅에 맞게")

- `HeroData.charge_marker` → `data/heroes/charge/*.tres` (`ChargeMarkerData`, `ChargeMarker`): 그림 두 겹이 반대로 돌며 충전만큼 커지고 진해짐, 모으는 동안 작은 입자, 다 찬 순간 이펙트 + 번쩍. 영웅 그림 아래(바닥)에 깔림.
  - 순신: 물결 고리 + 물보라, 물방울 / 광개토: 지진 불길 + 번개, 불똥 / 세종: 해시계 + 정음 자모, 별 / 사임당: 먹 소용돌이 + 매화, 꽃잎
- 결과: `docs/images/charge_markers.png` (위 = 충전 30%, 아래 = 다 찬 순간).

## 6차: 기술·회피 그림 겹치지 않게 (사용자 GPT 그림 추가)

- 새 그림 (`tools/vfx/gpt_to_vfx.py`, 고른 판): 해룡 `sea_dragon`(3판 중 용 머리가 가장 또렷), 화 반격 `fire_counter`(가운데가 빈 판), 해일검기 탄 `tidal_blade`(가로 판, 좌우 뒤집음), 정복자 왕관 `royal_shock`, 풀벌레 `critter_swarm`(벌레가 많은 판), 화폭 `scroll_unfold`(가로로 펼친 판), 회피 자취 `dash_spray / dash_spark / dash_ink`(먹·번개는 앞이 오른쪽이 되게 뒤집음), 세종 회피 `dash_glyph`(정음 자모 그림 오른쪽 위 금빛 붓 쓸기, 글자 없음).
- 배정: 순신 해룡참→해룡, 파도격→물결 띠, 해일검기→해일 칼날 탄(둥근 시전 그림 없앰), 반격→화 반격, 회피→물보라 자취 / 광개토 뇌진격→지진, 벽력돌파→번개 띠, 낙뢰→번개, 정복자→왕관, 회피→불똥 자취 / 세종 그대로 + 회피→금빛 붓 쓸기 / 사임당 풀벌레→풀벌레 떼, 발묵→먹 띠, 화폭→두루마리, 매화→매화, 회피→먹 자취. 회피 자취는 가늘게(40px).
- 테스트: 영웅 안에서 기술끼리 같은 그림을 쓰지 않고, 회피 자취는 기술 그림을 다시 쓰지 않는다 (`test_no_two_skills_or_dodge_share_an_image`).
- 결과: `docs/images/unique_skill_art.png` (위 = 해룡참·반격·정복자·화폭·풀벌레 강화 0/최대, 아래 = 영웅별 띠·탄·회피 자취).
