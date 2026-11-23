# 맞춤 안드로이드 엔진 + 실시간 3D 튕김 조사 (2026-11-23, 보류)

**결론 (보류):** 3D가 들어간 판은 공식 Godot 4.7.2 템플릿으로 낸다 (사용자: 용량 줄이기에 매달리지 않는다). 아래는 나중에 용량이 한계에 가까워지면 다시 시작할 때의 출발점이다. 원인은 **확정하지 못했다** (폰 logcat 없음).

## 증상

- 맞춤 3D 엔진(`tools/build/engine/haneol_android.py`에서 `disable_3d="no"`, arm64 libgodot 39.0 MB) + 3D 켬 + 2e6083c: 폰에서 오프닝 영상 직전에 말없이 꺼짐. PC(편집기)는 정상.
- 같은 내용 + **공식 엔진**: 정상 (통합 세션 "한얼 3D 시험2").
- **같은 맞춤 3D 엔진** + `hh/art/live3d=false` (3D를 그리지 않음): 정상 (진단 D1).
- → 내용은 정상이다. 맞춤 3D 엔진이 **3D 화면을 실제로 그릴 때** 죽는다. 영웅 SubViewport는 메인 장면을 불러올 때 생기고, 오프닝 영상은 그 뒤에 열리므로 "영상 직전"과 시점이 맞다.

## 원인이 아닌 것 (4.7.2 소스·APK로 확인)

- Theora: 맞춤 3D 엔진에 `VideoStreamTheora`가 있다. 2D 맞춤 엔진 판에서 영상이 계속 나왔다.
- 3D 물리·내비게이션 모듈을 끔: Dummy 서버로 대체된다 (`main.cpp` 372, `navigation_server_3d.cpp` 1053). Dummy 물리의 `space_get_direct_state`는 null이 아니라 dummy 상태를 돌려준다.
- raycast 모듈을 끔: `RendererSceneCull`이 기본 `RendererSceneOcclusionCull`을 만든다.
- meshoptimizer를 끔: 실행 중 호출은 모두 null 검사가 있거나 가져오기 때만 쓰인다.
- 텍스처: 1024 VRAM 압축은 APK에 `etc2.ctex`만 들어간다. GLES3 안드로이드는 `etc2_supported=true`라서 디코더 모듈(etcpak·bcdec·astcenc·basis)이 필요 없다.
- 렌더러: 프로젝트는 데스크톱·모바일 모두 `gl_compatibility`라서 `vulkan=no`와 상관없다. GLES3 3D 경로·장면 컬링 코드에는 모듈이나 `*_DISABLED` 옵션에 따라 달라지는 `#if`가 없다 (`XR_DISABLED`·`_3D_DISABLED`만 있다).
- 장면: 그림자·안개·SDFGI 없음. 방향광 둘 + 환경 주변광 색만 쓴다.

## 유력 원인: 컴파일 플래그

- 맞춤 엔진: `optimize=size` + `lto=full`.
- 공식 4.7.2 안드로이드 템플릿: `optimize=speed`, **LTO 없음**. `platform/android/detect.py`가 `lto=auto`를 `none`으로 바꾼다 ("LTO benefits for Android ... haven't been clearly established yet").
- 2D만 쓰던 동안에는 3D 코드가 실행되지 않아 드러나지 않았던 것으로 본다.

## 다시 시작할 때 (계획만, 빌드하지 않음)

1. 폰을 USB 디버깅으로 연결할 수 있으면 `adb logcat`의 네이티브 스택으로 바로 확정한다 (가장 싸다).
2. 아니면 arm64만 빌드한 진단 판 두 개 (각 10~17분, 따로 설치되는 패키지, 시작 단계 표시, 업로드 키):
   - E1: 지금 끈 모듈 그대로 + `optimize=speed lto=none` (공식 플래그)
   - E2: `optimize=size lto=full` + 공식 모듈 구성
   - E1만 되면 플래그 문제다 → `size` + `lto=thin`, 또는 `size` + LTO 없음을 시험한다. E2만 되면 모듈 문제다 → 3D 관련부터 반씩 나눈다.
3. 진단 판을 만들 때 주의:
   - PowerShell 5.1은 네이티브 프로그램에 빈 문자열 인자(`""`)를 넘기지 않는다. 그래서 D3 변형이 적용되지 않아 D1과 같은 파일이 나왔다. 보내기 전에 `aapt dump badging`(패키지·이름)과 엔진 `.so` 해시로 변형이 실제로 다른지 확인한다.
   - 서명: 3D 세션 판은 debug.keystore(인증서 SHA-256 `1da6d26e…`)로 서명돼 통합 세션 판(업로드 키 `524dd24e…`) 위에 덮어 설치되지 않았다. 내보내기는 `tools/build/export_aab.ps1 -Apk`로 한다.

관련: README "커스텀 내보내기 템플릿", `tools/build/build_templates.ps1`.
