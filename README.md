# 한얼: 영웅 (HANEOL: HEROES)

> 역사가 전설이 된다.

한국 역사 속 위인들을 초월적인 판타지 영웅으로 재해석한 **핵앤슬래시 액션 RPG**.
수십 마리의 적을 대시와 상황 반응형 스킬로 쓸어버리는 능동적인 모바일 액션을 지향한다.

| 항목 | 내용 |
|---|---|
| 약칭 | HH |
| 장르 | 한국 역사 판타지 핵앤슬래시 액션 RPG |
| 플랫폼 | Android 우선 |
| 화면 | 세로 9:16 |
| 시점 | 2.5D 쿼터뷰 |
| 엔진 | Godot 4.7.2 + GDScript |
| 현재 단계 | P0-A 조작 프로토타입 |

세계관과 영웅 설정: [docs/scenario.md](docs/scenario.md)

## 영웅

| 영웅 | 칭호 | 역할 | 상태 |
|---|---|---|---|
| 이순신 | 푸른 해류의 검 | 근접·원거리 복합형 검사 | P0 플레이어블 |
| 광개토대왕 | 천둥의 정복자 | 중량급 돌진형 전사 | 기획 |
| 세종대왕 | 천문의 지배자 | 원거리 마법형 | 기획 |
| 신사임당 | 수묵의 술사 | 자연·소환·광역 마법형 | 기획 |

## 조작

버튼은 적지만, 액션의 깊이는 깊다.

| 입력 | 동작 | 상태 |
|---|---|---|
| 화면 아무 곳이나 터치·드래그 | 이동 (터치 시작점 기준, 고정 조이스틱 없음) | 구현 |
| 빠른 플릭 | 대시 — 무영보 (2회 충전, 대시 중 무적) | 구현 |
| 자동 | 기본 공격: 근접 부채꼴 베기 + 원거리 검기 (이동 중에도 유지) | 구현 |
| 제자리 짧게 탭 (한 손) | 해룡참: 주변 광역·넉백 | 구현 |
| 대시 중·직후 손 떼기 (튕기며 떼면 대시+파도격) | 파도격: 대시 방향 관통 3연격 | 구현 |
| 제자리 꾹 누르기 → 이동 → 떼기 (한 손) | 해일검기: 충전 관통 물결, 이동하며 충전 | 구현 |
| 스킬 버튼 (선택, 오른쪽 위 토글로 켜기·끄기, 기본 끔) | 짧게 = 해룡참, 대시 중·직후 = 파도격, 길게 = 해일검기 | 구현 |
| 적 예고 공격을 대시로 피한 뒤 1초 안에 탭 / 대시 후 떼기 / 버튼 | 강화 반격: 넓은 범위 큰 피해·넉백·히트스톱 (최우선) | 구현 |

데스크톱에서는 마우스가 터치로 에뮬레이션된다.

## 개발 단계

| 단계 | 내용 | 상태 |
|---|---|---|
| P0-A | 조작 프로토타입: 터치 이동, 플릭 대시, 2회 충전, 터치 ID별 입력, Android APK | 구현 · Codex PASS WITH NOTES · 실기기 확인 |
| P0-B | 기본 전투: 적 30마리, 추적 AI, 자동 공격, 체력·피해, 게임오버·재시작 | 구현 · Codex PASS WITH NOTES · 실기기 확인 |
| P0-C | 상황별 스킬: 해룡참, 파도격, 해일검기, 스킬 입력 상태 머신, 이펙트 | 구현 · 검증 중 |
| P0-D | 실기기 검증: 조작·스킬·60초 생존·성능·플레이 평가 | 예정 |

P0 제외: 영웅 4인 전체, 스토리 캠페인, 수집, 장비, 성장, 서버, 광고·결제, 멀티플레이, 정식 그래픽.

### 보류 항목 (나중에)

가벼운 조정·마감 항목. 핵심 단계 진행을 막지 않는다.

- 플릭 vs 더블탭 비교 옵션 (오발동 대시는 기준 상향·급가속 조건으로 1차 조정함)
- 스킬 버튼 위치·크기, 파도격 연계 시간 재조정
- 정식 패키지 ID, Android 13+ 테마 아이콘
- 전투 이펙트 에셋(Stylized 2D VFX Lite 등) 검토, 정식 효과음(Kenney CC0 등 — 자동 다운로드 차단돼 수동 확보 필요)
- 터치 이벤트 합쳐짐·프레임 끊김 시 플릭 판정 확인 (Codex 메모)
- 단독 pck에 남는 `addons/gdUnit4/plugin.cfg` 정리 (APK에는 없음)
- GitHub Actions 자동 테스트(setup-godot), 저장소 공개 범위

## 시작하기

### 요구 사항

- Godot 4.7.2 (표준판)
- APK 빌드 시: Godot 4.7.2 내보내기 템플릿, JDK 17, Android SDK (platform-tools, build-tools 35.0.1, platforms;android-35)
  - Godot 편집기 설정 `export/android/java_sdk_path`, `export/android/android_sdk_path` 지정

### 실행

Godot 4.7.2로 `project.godot`을 열고 F5.

### 테스트 (gdUnit4)

```
godot --headless --path . --import
godot --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode -c
```

종료 코드 0이면 전체 통과. 결과는 `reports/`에 생성된다.

### Android APK

```
godot --headless --path . --export-debug "Android" build/android/haneol-heroes.apk
```

디버그 서명 APK(arm64-v8a, minSdk 24, targetSdk 36, 세로 고정)가 생성된다.
APK는 git에 올리지 않는다. 패키지 ID `com.haneol.heroes`는 임시값이다.

## 구조

| 경로 | 내용 |
|---|---|
| `data/heroes/*.tres` | 영웅 데이터 (능력치, 대시, 기본 공격, 단일 버튼 기술 구성) |
| `data/enemies/*.tres` | 적 데이터: 잡병(chaser), 궁수(archer, 거리 유지·화살), 중장병(heavy, 느림·단단함·큰 내려찍기), 보스(boss_general: 40초 등장, 부채꼴·돌진·충격파 순환, 처치 시 승리) |
| `scripts/data/` | 데이터 클래스: `HeroData`, `BasicAttackData`, `EnemyData` |
| `scripts/skills/` | 공통 기술 시스템: 입력 상태(`SkillInput`), 상황 판단(`SkillCaster`), 기술 기반(`SkillDef`, `SkillRun`, `SkillContext`, `SkillKit`) |
| `scripts/heroes/<영웅>/` | 영웅 전용 기술 (이순신: 해룡참, 파도격, 해일검기) |
| `scripts/input/` | 터치 ID별 이동·플릭 판정, 스킬 버튼 라우팅 |
| `scripts/player/` | 플레이어 이동·대시·피격, 대시 충전, 임시 그래픽(`PlayerView`) |
| `scripts/combat/` | 적, 생성기(최대 30), 자동 공격, 투사체, 대상 선택 |
| `scripts/game/` | 60초 생존·처치·결과, 성능 기록, 씬 연결·재시작 |
| `scripts/ui/` | HUD, 스킬 버튼 표시 |
| `scripts/fx/` | 임시 전투 이펙트 |
| `tests/` | gdUnit4 테스트 |
| `docs/scenario.md` | 세계관·영웅 기준 문서 |

**새 영웅 추가:** `scripts/heroes/<영웅>/`에 `SkillDef`를 상속한 기술 3개를 만들고, `data/heroes/<영웅>.tres`에 능력치·기본 공격·기술 구성을 적는다. 공통 코드는 바꾸지 않는다.
**3D → 2D 스프라이트 굽기:** `godot --path . -s res://tools/bake/bake_sprites.gd` (창 모드). `.glb` 모델을 쿼터뷰 8방향 시트(`assets/sprites/<이름>/`)와 `SpriteSheetSet`으로 굽는다. 영웅 데이터의 `sprite_sheet`에 지정하면 그 스프라이트로, 비우면 수묵풍 코드 그림으로 그린다.
**AI 3D 영웅 (Meshy):** 기준 그림(`assets/concept/<영웅>/`) → 3D 생성 → 자동 뼈대 → 동작 → 굽기 → 영웅 데이터 교체를 한 번에 한다. 유료 Meshy 플랜의 API 키를 `setx MESHY_API_KEY "키"`로 등록한 뒤:
`python tools/ai3d/meshy_pipeline.py plan tools/ai3d/heroes/yi_sun_sin.json` (예상 크레딧 확인) → `... run ... --yes`. 진행 상태는 `assets/models/meshy/<영웅>/state.json`에 남아 끊겨도 이어 한다. 동작 목록은 `... actions <검색어>`, 오프라인 테스트는 `python -m unittest tools/ai3d/test_meshy_pipeline.py`.
**새 적 추가:** `data/enemies/<적>.tres` (행동이 다르면 전용 스크립트).

## 개발·검증 방식

| 역할 | 담당 |
|---|---|
| 메인 개발·통합 | Claude |
| 독립 코드 검증·테스트 | Codex |
| 설계·기술 판정 | GPT |
| 제품 책임·최종 승인 | 사용자 |

1. 새 기능은 저장소 → 플러그인·스킬 → Asset Library·오픈소스 순으로 재사용 가능성을 먼저 조사하고, 부족한 부분만 최소 구현한다.
2. Claude가 구현·테스트 후 커밋한다.
3. Codex가 해당 커밋 SHA를 별도 클론에서 독립 검증한다 (코드 검토, 테스트 실행, 결함 재현).
4. 결함은 Claude가 수정하고 새 SHA로 재검증한다.
5. Codex PASS 전에는 완료로 표시하지 않는다.

Claude 개발 스킬: 프로젝트 범위 플러그인 `godot@awesome-gamedev-agent-skills` (`.claude/settings.json`).

## 외부 자산

| 자산 | 버전 | 라이선스 | 출처 |
|---|---|---|---|
| gdUnit4 | 6.2.3 | MIT (`addons/gdUnit4/LICENSE`) | https://github.com/godot-gdunit-labs/gdUnit4 |
| (임시 효과음) | — | 자체 합성 (`scripts/fx/sfx_synth.gd`) | 엔진 AudioStreamWAV. 정식 효과음은 아트·사운드 단계에서 교체 |
| KayKit Character Pack: Adventurers (Knight·Barbarian, 임시 캐릭터) | 1.0 | CC0 (`assets/models/kaykit/LICENSE.txt`) | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 (Kay Lousberg) |
| KayKit Character Pack: Skeletons (Minion·Rogue·Warrior, 임시 적) | 1.0 | CC0 (`assets/models/kaykit_skeletons/LICENSE.txt`) | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0 (Kay Lousberg) |
| Health, HitBoxes, HurtBoxes and HitScans | 5.0.4 + HH 패치 | MIT (`addons/health_hitbox_hurtbox/LICENSE`) | https://github.com/cluttered-code/godot-health-hitbox-hurtbox |
| Meshy API (AI 3D 생성 서비스, 개발 도구에서 호출) | openapi v1 | 유료 플랜 산출물 사용 조건은 Meshy 약관 | https://docs.meshy.ai/en/api |

HH 패치: `health/health.gd`의 피격 로그를 `verbose_debug`(기본 꺼짐)일 때만 출력하도록 변경. 원본은 매 피격마다 출력해 적 30마리 전투에서 성능 부담이 있다.
| awesome-gamedev-agent-skills (`godot` 플러그인, 개발용) | — | Apache-2.0 | https://github.com/gamedev-skills/awesome-gamedev-agent-skills |

게임 코드에 외부 코드를 가져올 때는 이 표에 출처와 라이선스를 기록한다.
