# 한얼: 영웅들 (HANEOL: HEROES)

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
| 순신 (이순신) | 푸른 해류의 검 | 근접 검사 (평타는 근접만, 빠르고 고른 연타) | P0 플레이어블 |
| 광개토 (광개토대왕) | 천둥의 정복자 | 중량급 돌진형 전사 (평타는 근접만, 느리고 길고 묵직) | 플레이어블 (임시 모델) |
| 세종 (세종대왕) | 천문의 지배자 | 원거리 마법형 (평타는 글자 원거리만, 붙은 적에게도 쏨) | 플레이어블 |
| 사임당 (신사임당) | 수묵의 술사 | 자연·소환·광역 마법형 (평타는 중거리 붓 털기 약 230px: 가로 털기 → 세로 털기 → 원으로 뿌리기) | 플레이어블 |

## 조작

버튼은 적지만, 액션의 깊이는 깊다.

| 입력 | 동작 | 상태 |
|---|---|---|
| 화면 아무 곳이나 터치·드래그 | 이동 (터치 시작점 기준, 고정 조이스틱 없음) | 구현 |
| 빠른 플릭 | 대시 — 무영보 (2회 충전, 대시 중 무적) | 구현 |
| 자동 | 기본 공격 (영웅 역할대로): 순신·광개토는 근접 사거리 안의 적만 베고 (밖이면 다가가야 한다), 세종은 글자를 쏘고, 사임당은 중거리 붓 털기. 이동 중에도 유지 | 구현 |
| 제자리 탭 연타 (한 손) | 탭마다 평타 한 타: 한 연타 동작에서 이어 자른 1·2·3타 (빠름·빠름·묵직, 3타 앞 짧은 모으기, 타마다 짧은 전진·다른 궤적, 3타는 좁고 길게 / 세종은 글자 하나·둘·큰 하나), 앞 타가 닿은 뒤 다음 탭이 끊고 들어감, 연타 사이엔 마지막 자세 유지. 넷째 탭 = 해룡참 마무리 (피해 ×0.6, 마무리 뒤 쿨타임 = 원래의 절반). 너무 빠른 탭은 0.2초 기억, 1.2초 안 치면 연계 끊김. 안 눌러도 자동 평타는 그대로 | 구현 |
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
| 2단계 | 전투 손맛: 적 3종·예고 공격, 대시 회피 → 1초 강화 반격, 보스 1종(3패턴), 히트스톱·효과음 | 구현 · Codex PASS (PR #5) |
| 아트 | 3D 모델을 쿼터뷰 스프라이트로 굽기 + 수묵 후처리, 한지 바닥 (임시 캐릭터) | 구현 · Codex PASS WITH NOTES (PR #7–#9) |
| 3단계 | 런 루프: 처치 경험치 → 레벨업 때 시간이 느려지고 주변에 먹 인장 3개, 대시로 낚아채 성장(3초 지나면 가장 가까운 것). 1:00·1:50 정예 처치 → 금빛 인장 큰 변형(소용돌이·물보라·세 갈래·사방 검기). 2:30 보스 처치 시 승리 | 구현 · 검증 중 |
| 4단계 (진행) | 두 번째 영웅 광개토대왕(가칭 기술: 뇌진격·벽력돌파·낙뢰·정복자의 일격, 기절·돌격 밀치기, 성장 14 + 큰 변형 4), 영웅 고르기 화면 (결과 화면 아래 띠로 바꾸기) | 구현 · 검증 중 |

P0 제외: 영웅 4인 전체, 스토리 캠페인, 수집, 장비, 성장, 서버, 광고·결제, 멀티플레이, 정식 그래픽. (성장은 사용자 결정으로 3단계에서 런 안 성장만 추가)

### 보류 항목 (나중에)
- 새 영웅 디자인(`assets/concept/redesign/heroes`, 2026-11-21)에 맞춰 나중에 따로: 입장 그림(2026-11-24 사용자 그림으로 교체됨) + 앱 아이콘(`tools/art/make_icons.py`가 입장 그림에서 자동). 광개토 이야기 첫 장면(`assets/intro/gwanggaeto/s1.png`)도 옛 디자인. 오프닝 영상은 그 뒤
- 강화 카드 그림 12개(기술에 안 묶인 체력·기본 공격·이동·대시 강화)는 기존 그림을 얹은 임시 그림. GPT 그림을 받으면 `assets/concept/upgrade_icons/`에 넣고 `tools/art/make_upgrade_icons.py` 재실행 (프롬프트: `docs/upgrade_icon_prompts.md`)

가벼운 조정·마감 항목. 핵심 단계 진행을 막지 않는다.

- 플릭 vs 더블탭 비교 옵션 (오발동 대시는 기준 상향·급가속 조건으로 1차 조정함)
- 스킬 버튼 위치·크기, 파도격 연계 시간 재조정
- 정식 패키지 ID, Android 13+ 테마 아이콘
- 전투 이펙트 에셋(Stylized 2D VFX Lite 등) 검토. 효과음·음악은 OpenGameArt CC0로 1차 적용 (Kenney는 자동 다운로드가 막혀 있음)
- 터치 이벤트 합쳐짐·프레임 끊김 시 플릭 판정 확인 (Codex 메모)
- 단독 pck에 남는 `addons/gdUnit4/plugin.cfg` 정리 (APK에는 없음)
- GitHub Actions 자동 테스트(setup-godot), 저장소 공개 범위
- 장비 (나중에): 6부위(무기·투구·상의·하의·장갑·장화) × 5등급, 공통 능력치 + 영웅별 외형, 세트 효과. 외형은 Meshy 한 덩어리 모델 한계로 몸 통째 단계 + 무기 레이어 + 등급 빛이 현실적. 지금은 영웅당 모델 하나
- 레벨업 방식 다른 대안 (지금은 인장 낚아채기 + 정예 큰 변형): 롤식 스킬 포인트 "+", 쓰는 만큼 숙련 진화

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

### 플레이스토어 빌드 (AAB)

1. 한 번만: `%APPDATA%\Godot\export_templates\4.7.2.stable\android_source.zip`을 `android/build/`에 풀고, `android/.build_version`에 `4.7.2.stable`을 적고, `android/build/.gdignore`를 만든다 (`android/`는 용량이 커서 깃에서 제외).
2. 업로드 서명 키는 저장소 밖 `%USERPROFILE%\.haneol-keys\`(`upload.jks`, `upload-key.txt`)에만 둔다. **따로 백업한다.**
3. `powershell -ExecutionPolicy Bypass -File tools/build/export_aab_official.ps1` → `build/android/haneol-heroes.aab` (공식 4.7.2 엔진, 내보내기 설정 "Android Play (AAB)", arm64 + armeabi-v7a; `libs/release` aar를 `android_source.zip`의 공식 것으로 되돌린 뒤 내보낸다). 직접 만든 엔진으로 만들 때는 `export_aab.ps1`. versionCode는 Console에 올리기 직전에만 +1 (versionName 0.4.x 함께). 내보내기 전에 `android/build/src/main/AndroidManifest.xml`에 `android.hardware.screen.portrait` 선택사항 선언을 넣고(세로 고정이 넣는 필수 기능 때문에 Play가 기기를 거르지 않게), 끝에 `tools/build/check_aab_manifest.ps1`로 권한(VIBRATE만)과 필수 기능을 점검한다.
4. 스토어 대표 그래픽: `assets/store/feature_graphic_1024x500.png` (APK 제외).

### 커스텀 내보내기 템플릿 (엔진 다이어트)

릴리스 APK·AAB는 쓰지 않는 엔진 기능을 뺀 Godot 4.7.2 Android 릴리스 템플릿으로 만든다 (원격 전달 한도 30 MiB 안에 그림 자리를 남기려고).

- 프로필: `tools/build/engine/haneol_android.py` (SCons 옵션·끈 모듈과 이유), 빌드: `tools/build/build_templates.ps1`
- 결과물: `build/templates/` (깃 제외) — `android_release.apk`(내보내기 설정 "Android"의 `custom_template/release`), `godot-lib.template_release.aar`(AAB용, `export_aab.ps1`이 `android/build/libs/release/`에 복사)
- 준비 (한 번, 관리자 권한 불필요): Godot 소스 `git clone --depth 1 --branch 4.7.2-stable https://github.com/godotengine/godot.git %LOCALAPPDATA%\haneol-build\godot-4.7.2` (다른 곳이면 `HANEOL_GODOT_SRC`), `python -m pip install --user scons`, PowerShell에서 `sdkmanager "ndk;29.0.14206865"` (4.7.2 `platform/android/detect.py`가 요구하는 판)
- 다시 빌드: `powershell -ExecutionPolicy Bypass -File tools/build/build_templates.ps1` (arm64 + arm32, 이 노트북에서 오래 걸린다)
- 게임이 3D, 정규식, mp3, 네트워크, 복잡한 문자(아랍어·태국어 등) 같은 새 엔진 기능을 쓰게 되면 프로필에서 해당 모듈을 다시 켜고 템플릿을 새로 빌드한다.
- 기본 엔진으로 되돌리기: 내보내기 설정 "Android"의 `custom_template/release`를 비우고, AAB는 `android_source.zip`의 `libs/release` aar로 덮는다.

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

**새 영웅 추가:** `scripts/heroes/<영웅>/`에 `SkillDef`를 상속한 기술 4개(탭·대시·충전·반격)를 만들고, `data/heroes/<영웅>.tres`(능력치·기본 공격·기술 구성·성장 풀)와 `data/upgrades/<영웅>.tres`·`<영웅>_major.tres`를 적은 뒤 `scenes/main.tscn`의 Main `heroes` 목록에 넣는다. 공통 코드는 바꾸지 않는다 (광개토대왕으로 확인).
**3D → 2D 스프라이트 굽기:** `godot --path . -s res://tools/bake/bake_sprites.gd` (창 모드). `.glb` 모델을 쿼터뷰 8방향 시트(`assets/sprites/<이름>/`)와 `SpriteSheetSet`으로 굽는다. 영웅 데이터의 `sprite_sheet`에 지정하면 그 스프라이트로, 비우면 수묵풍 코드 그림으로 그린다.
**AI 3D 영웅 (Meshy):** 기준 그림(`assets/concept/<영웅>/`) → 3D 생성 → 자동 뼈대 → 동작 → 굽기 → 영웅 데이터 교체를 한 번에 한다. 유료 Meshy 플랜의 API 키를 저장소 루트 `.env`에 `MESHY_API_KEY=키`로 적은 뒤 (`.env.example` 참고, `.env`는 깃 제외):
`python tools/ai3d/meshy_pipeline.py plan tools/ai3d/heroes/yi_sun_sin.json` (예상 크레딧 확인) → `... run ... --yes`. 진행 상태는 `assets/models/meshy/<영웅>/state.json`에 남아 끊겨도 이어 한다. **무료 플랜(API 없음)**은 meshy.ai 웹에서 기준 그림으로 생성 → 뼈대(Rig) → 동작을 붙여 .glb로 받은 뒤 `... import <설정> 받은.glb [동작별.glb ...]`로 굽기·적용한다 (파일 이름에 idle/run/attack 등이 들어 있으면 동작별 파일로 인식). 무료 플랜 산출물은 CC BY 4.0이라 크레딧에 "Meshy" 표기가 필요하다. 동작 목록은 `... actions <검색어>`, 오프라인 테스트는 `python -m unittest tools/ai3d/test_meshy_pipeline.py`.
**무대:** `data/stages/<무대>.tres` (`StageTheme`: 연도·이름·바닥 색·수묵 소품 밀도), `RunConfig.stage`로 고른다. 첫 무대는 395년 만주 벌판 (거란 망령 군대).
**새 적 추가:** `data/enemies/<적>.tres` (행동이 다르면 전용 스크립트, 처치 경험치 `xp`).
**성장 선택지:** `data/upgrades/<영웅>.tres` (`UpgradePool` → `UpgradeDef` → `StatMod`: 대상 hero/attack/kit/tap/dash/charge/counter의 속성을 더하기·곱하기). 큰 변형은 `data/upgrades/<영웅>_major.tres` (기술 스크립트의 변형 값을 켠다). 런 규칙(경험치 곡선, 정예·보스 시각)은 `data/runs/default_run.tres`.

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
| 입장 배경 `assets/ui/title_bg.png`(941×1672)·이야기 마지막 장면 `assets/intro/s5_four_heroes.png`(1024×1536)·스플래시 `assets/ui/splash.png`(앞 그림에 제목을 얹음, `tools/art/korean_title_art.py`) | 2026-11-24 (같은 날 다시 그린 판으로 교체) | 사용자 제공 그림 (사용자가 GPT로 만듦, 한지 수묵풍). 원본 그대로, 무손실 가져오기 | 사용자. 입장 화면은 제목·낙관을 화면에서 글꼴로 그린다 |
| 덕온공주체 (DeogonPrincess, 게임 글꼴 하나, 궁체) | 2021-10 TTF (sha256 `35ae40e5…`) | 공공누리 제3유형: 상업 사용 가능, 출처 표시, 변경 금지 (`assets/fonts/LICENSE_DeogonPrincess.txt`) | https://hanfont.hangeul.go.kr/relaxfont/font/deokon.do (국립한글박물관·윤디자인그룹) — 원본 파일 그대로 넣음 (글자 줄이기 안 함, `tests/test_fonts.gd`가 해시 확인). 출처는 설정 → "만든 이들" 화면에 표시 (`data/credits/credits.tres`) |
| 20 Sword Sound Effects (StarNinjas, 칼 휘두름·부딪힘) | — | CC0 | https://opengameart.org/content/20-sword-sound-effects-attacks-and-clashes — 잘라 줄임 (`tools/audio/prepare_audio.py`) |
| RPG Sound Pack (artisticdude, 대시·마법·적 쓰러짐·단추, 명중 재질: 물방울·옷 스침, 큰 타격 확인음, 적 공격 예고 "스릉"·휘두름 "휙") | `rpg_sound_pack.zip` | CC0 | https://opengameart.org/content/rpg-sound-pack — 같은 방식 |
| 80 CC0 RPG SFX (rubberduck, 명중 재질: 칼·불·돌·먹(점액)·글자(보석), 적 공격: 돌 내려침·조총 철컥·활 팅, 영웅 무기: 칼 챙(blade_02·metal_02)·창 턱(wood_03)·붓 착(book_02·03)·두루마리 탁(book_04·item_wood_01)·강타 돌(stones_03)) | `80-CC0-RPG-SFX_0.zip` (2026-11-21 받음) | CC0 | https://opengameart.org/content/80-cc0-rpg-sfx — 잘라 줄임 (`tools/audio/prepare_audio.py ... mat_*`) |
| 50 CC0 Sci-Fi SFX (rubberduck, 명중 재질: 세종 번개 지지직, 적 조총 "탕": explosion_01·02를 0.85배로 낮춤) | `sci-fi-sfx.zip` (2026-11-21 받음) | CC0 | https://opengameart.org/content/50-cc0-sci-fi-sfx — shoot_02·misc_07만 잘라 씀 |
| 37 hits/punches (Independent.nu, 영웅 피격음·명중 몸통 "퍽"·정예 처치 "쿵") | `independent_nu_ljudbank-hits_and_punches.7z` (2026-11-21 받음) | CC0 | https://opengameart.org/content/37-hitspunches — hit26·hit30을 0.85배 빠르기로 낮추고 0.35초로 자름 (`tools/audio/prepare_audio.py ... hurt`). 명중 몸통 hit17·22·28·32 (0.2초), 처치 확인 hit35·hit19 (0.7배 빠르기). 영웅 창 hit12, 3타째 강타 hit35 (0.75배 빠르기, `... w_*`) |
| 전통악기 장구·꽹과리 연주 (국악 덧소리: 큰 타격 꽹과리, 정예·보스 처치 장구) | 전통악기_장구_치다_보통속도_Ver.1_MKH418_ST_192 (wrtSn=13287485), 전통악기_꽹과리_치다_연주_MKH418_ST_192 (wrtSn=13287481), 2026-11-21 받음 | 공공누리 제1유형 (출처표시, 상업·변경 가능) — 저작권자 (재)전주정보문화산업진흥원. 출처는 설정 → "만든 이들" 화면에 표시 (`data/credits/credits.tres`) | https://gongu.copyright.or.kr/gongu/wrt/wrt/view.do?wrtSn=13287485&menuNo=200020 , https://gongu.copyright.or.kr/gongu/wrt/wrt/view.do?wrtSn=13287481&menuNo=200020 — 센 한 타씩 골라 0.35·0.7초로 자름 (`tools/audio/cut_gugak.py`) |
| 국악기 합성음 북·징·편경·가야금 (기술 소리 층), 방울 (일반 보상, 2026-11-23 추가) | 저장소가 직접 합성 (녹음·외부 파일 없음), 2026-11-22 | 저장소 자산 (외부 라이선스 없음) | `tools/audio/make_gugak_synth.py` → `assets/audio/sfx/gugak_{buk,jing,pyeon,gaya,bang}_*.ogg`. 실제 녹음(CC0)을 구하면 같은 이름으로 바꿔 넣는다 |
| 노랫소리 끔용 반주 8개 (`assets/audio/music/<무대>/instrumental_stage·boss.ogg`, 설정 "노랫소리" 끔일 때 판 중에만): 원곡(Suno, 사용자 Voice)에서 목소리 없는 구간(전주·간주·후주)만 잘라 한 줄로 이은 반복 곡. 분리(demucs)는 쓰지 않음 — 원음 그대로, 음량만 맞춤. 짧은 곡은 Suno 반주 판으로 같은 이름 파일을 갈아 끼울 수 있다 | 2026-11-24 | 사용자 소유 Suno 곡 (원곡 mp3는 `build/music_src/`, 깃 제외) | 구간 계획 `tools/audio/vocal_off_plan.json`, 만드는 스크립트 `tools/audio/make_vocal_off.py` (구간 찾기 기록: `build/music_work/medley.json`, 깃 제외) |
| Asianoriental1 (무대 1 음악) | — | CC0 | https://opengameart.org/content/asianoriental1 — 모노 22kHz로 줄임 |
| Health, HitBoxes, HurtBoxes and HitScans | 5.0.4 + HH 패치 | MIT (`addons/health_hitbox_hurtbox/LICENSE`) | https://github.com/cluttered-code/godot-health-hitbox-hurtbox |
| 바닥 결 재질 (한산 판자·만주 풀밭·경복궁 판석: 밝기만 남긴 회색 결 층으로 가공해 바닥 그림에 곱함, `tools/art/make_grain.py`) | Poly Haven `weathered_brown_planks`·`grass_ground`·`monastery_stone_floor` 2K diffuse (2026-11-23 받음, 원본 `assets/concept/textures_src/`) | CC0 (https://polyhaven.com/license: "Our assets are all licensed as CC0", 상업 이용·변형 가능, 출처 표시 불필요) | https://polyhaven.com/a/weathered_brown_planks |
| 바닥 결 재질 (초충도 한지: 밝기만 남긴 회색 결 층으로 가공해 바닥 그림에 곱함, `tools/art/make_grain.py` → `assets/textures/grain/hanji_paper.png`) | ambientCG `Paper006` 2K-JPG Color (2026-11-23 받음, 원본 `assets/concept/textures_src/Paper006_2K-JPG_Color.jpg`) | CC0 (https://docs.ambientcg.com/license/ — 상업 이용·변형 가능, 출처 표시 불필요) | https://ambientcg.com/view?id=Paper006 |
| 초충도 병풍 그림 소품 (식물·열매·나비·잠자리를 종이 바탕에서 잘라 `assets/props/chochungdo/screen_*.png`로: `tools/art/cut_chochungdo.py`, 크기만 줄임) | 전 신사임당필 초충도(신수3550) 8폭, 국립중앙박물관 (사용자가 2026-11-23 박물관에서 받은 그림만 잘린 판, 판당 약 15MB라 **저장소에는 올리지 않고** 로컬 `assets/concept/chochungdo_src/`에만 둠) | 공공누리 제1유형 (출처 표시, 상업 이용·변형 가능; 페이지 표기 "공공누리 1유형 - 출처표시") | https://www.museum.go.kr/site/main/relic/search/view?relicId=2061 — 게임 안 표기 문구는 `docs/credits_draft.md` |
| 한산 갑판 가장자리 먹선·용머리 (귀갑문·방패판 원 무늬 띠·용머리를 선만 뽑아 겹침 그림으로 합성: `tools/art/make_hansan_edge.py`) | 『이충무공전서』 전라좌수영 귀선(1795), 일본 국립국회도서관 소장, Wikimedia Commons `Geobukseon2.jpg` (2026-11-23 받음, 원본 1425px 인쇄물 1.8MB는 `assets/concept/gwiseon_src/`에 커밋) | 퍼블릭 도메인 (Commons 파일 페이지: PD + "Public Domain Mark 1.0") | https://commons.wikimedia.org/wiki/File:Geobukseon2.jpg |
| 만주 벌판 가장자리 먹선 (산 물결·사슴·말 탄 사냥꾼·호랑이의 검은 선만 뽑아 지도 위에 한 겹, `tools/art/make_manchuria_edge.py`; 원본 사본 `assets/concept/stage_edge_src/`) | 무용총 수렵도 (고구려 5세기 벽화), 국립문화재연구원(현 국립문화유산연구원) 문화유산 지식e음 포털 공개 사진 — Wikimedia Commons `Muyongchong Suryeopdo.jpg` 경유 (Commons 출처: https://portal.nrich.go.kr/kor/filePopUpImage.do?relmenucd=617&relkey=165&fileTypeCd=364&popType=P&file_idx=203903) | 공공누리 제1유형 (출처표시, 상업 이용·변형 가능) — 게임 안 표기 문구는 `docs/credits_draft.md` | https://commons.wikimedia.org/wiki/File:Muyongchong_Suryeopdo.jpg |
| 경복궁 가장자리 먹선 (행각 마당 배치·궁성 담장 곡선의 연필 선만 뽑아 지도 위에 한 겹, 격자 종이는 제거, `tools/art/make_gyeongbokgung_edge.py`; 원본 사본 `assets/concept/stage_edge_src/`) | 북궐후원도형 (조선 말 도면, 서울대 규장각한국학연구원 소장), Wikimedia Commons `북궐후원도형.jpg` | 퍼블릭 도메인 (Commons 표기) | https://commons.wikimedia.org/wiki/File:북궐후원도형.jpg |
| Meshy API (AI 3D 생성 서비스, 개발 도구에서 호출) | openapi v1 | 유료 플랜 산출물 사용 조건은 Meshy 약관 | https://docs.meshy.ai/en/api |
| 순신 실시간 3D 모델 (Meshy 유료 플랜 산출물을 가공: 뼈대·스킨 메시, 1024² 텍스처, 동작 9개) | 2026-11-22 생성 (Meshy 작업 01a200c7·01a200c8, 동작 Idle·Run 2·Roll Dodge·Hit Reaction·Dead·Triple Combo Attack·Charged Upward Slash·Right-hand Sword Slash·Double Blade Spin) | 유료 플랜 산출물 — Meshy 약관 (원본 .glb·state.json은 저장소에 없음) | `assets/live3d/yi_sun_sin/` ← `tools/live3d/pack_model.gd`가 `assets/models/meshy/yi_sun_sin/*.glb`(gitignore)에서 만든다. 패치: LOD·그림자 메시·동작 트랙 제거, 텍스처 2048→1024 (Lanczos, VRAM 압축), 동작은 .res로 따로 |
| 한산 대장(왜군 지휘관) 실시간 3D 모델 (Meshy 유료 플랜 산출물을 가공: 뼈대·스킨 메시, 1024² 텍스처, 동작 5개) | 2026-11-23 가공 (Meshy 작업 01a2009c·01a2009e, 동작 Idle·Walk Fight Forward·Hit Reaction·Charged Spell Cast·Charged Slash) | 유료 플랜 산출물 — Meshy 약관 (원본 .glb·state.json은 저장소에 없음) | `assets/live3d/waegun_commander/` ← `tools/live3d/pack_model.gd waegun_commander`가 `assets/models/meshy/waegun_commander/*.glb`(gitignore)에서 만든다. 패치: 순신과 같음 + 공격 동작에 구운 시트의 칸 시각(times) 덧붙임 (`data/live3d/waegun_commander.tres`) |
| 여진 궁수 v2 구운 그림 (Meshy 웹 생성 모델 + 웹 뼈대·동작, 크레딧 27) | 2026-11-23 생성 (`jurchen_archer_v2_web_meshyrig.glb`, MeshyRig 20,961면, 동작 Idle·Walking·Archery_Shot_1·Hit_Reaction_to_Waist·Dead) | Meshy 산출물 — Meshy 약관 (원본 .glb는 저장소에 없음) | `assets/sprites/jurchen_archer/` ← `meshy_pipeline.py import … --no-bake` + `bake_sprites.gd --only=jurchen_archer`. 패치: 활이 왼손 손가락·왼 정강이 뼈에 나뉘어 묶여 꺾여서 활 전체를 LeftHand에 단단히 묶음 (`bake.rigid`, 상자 셋·캡슐 둘) |
| Meshy 웹 뼈대 동작 (0크레딧) → 기존 뼈대로 옮긴 동작 (.res): 대장 돌진·땅 찍기·외침·사망, 정예 외침·사망, 영웅 넷 승리 | 2026-11-23 받음 (웹 MeshyRig 파일: Male_Head_Down_Charge·Charged_Ground_Slam·Sword_Shout·Dead·Victory 등) | Meshy 산출물 — Meshy 약관 (원본 .glb는 저장소에 없음) | `assets/live3d/<캐릭터>/anims/web_*.res` ← `tools/live3d/retarget_clip.gd` (뼈마다 기본 자세에서 돈 만큼, 엉덩이 위치는 메시 키 비율). 굽기와 3D가 같은 클립을 쓴다 (`reuse.from`) |

HH 패치: `health/health.gd`의 피격 로그를 `verbose_debug`(기본 꺼짐)일 때만 출력하도록 변경. 원본은 매 피격마다 출력해 적 30마리 전투에서 성능 부담이 있다.
| awesome-gamedev-agent-skills (`godot` 플러그인, 개발용) | — | Apache-2.0 | https://github.com/gamedev-skills/awesome-gamedev-agent-skills |

게임 코드에 외부 코드를 가져올 때는 이 표에 출처와 라이선스를 기록한다.
