# 한얼: 영웅 (HANEOL: HEROES)

한국 역사 판타지 핵앤슬래시 모바일 액션. Android 우선, 세로 9:16, Godot 4.7.2 + GDScript.

## 실행

- 에디터: Godot 4.7.2로 `project.godot` 열기 → F5. 데스크톱에서는 마우스가 터치로 에뮬레이션된다.
- 조작(P0-A): 화면 아무 곳이나 터치·드래그 = 이동, 빠르게 튕기기(플릭) = 대시(2회 충전).

## 테스트 (gdUnit4)

```
godot --headless --path . --import
godot --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode -c
```

종료 코드 0 = 전체 통과. 결과는 `reports/`에 생성된다.

## Android APK

필요: Godot 4.7.2 내보내기 템플릿, JDK 17, Android SDK(platform-tools, build-tools 35.0.1, platforms;android-35).
Godot 편집기 설정 `export/android/java_sdk_path`, `export/android/android_sdk_path`를 지정한다.

```
godot --headless --path . --export-debug "Android" build/android/haneol-heroes.apk
```

디버그 서명 APK(arm64-v8a, 세로 고정)가 `build/android/`에 생성된다. 빌드 산출물은 git에 올리지 않는다.
패키지 ID `com.haneol.heroes`는 임시값이다.

## 구조

| 경로 | 내용 |
|---|---|
| `scripts/input/touch_move_input.gd` | 터치 ID별 자유 영역 이동·플릭 판정 (순수 로직) |
| `scripts/input/touch_controller.gd` | InputEvent → 입력 로직 → 플레이어 연결 |
| `scripts/player/dash_charges.gd` | 대시 충전(2회, 순차 회복) |
| `scripts/player/player.gd` | 이순신 이동·대시(무영보) |
| `tests/` | gdUnit4 테스트 |

## 외부 자산

| 자산 | 버전 | 라이선스 | 출처 |
|---|---|---|---|
| gdUnit4 | 6.2.3 | MIT (`addons/gdUnit4/LICENSE`) | https://github.com/godot-gdunit-labs/gdUnit4 |
