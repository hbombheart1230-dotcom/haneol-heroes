# 아트 방향 기록 (2026-11-19)

정본이 아닌 작업 기록이다. 아트 방향은 아직 확정하지 않았다.

## 지금까지 해 본 것

| 방식 | 브랜치 / PR | 상태 |
|---|---|---|
| 수묵풍 코드 그림 (외부 이미지 없음) | `art/ink` (PR #6 닫힘, 커밋 `0d0a408`) | 처음에는 "별로"라는 평가를 받고 3D로 넘어갔다. 2026-11-19에 다시 검토하려고 되돌려 보는 중 |
| 3D 모델 → 쿼터뷰 8방향 2D 스프라이트 굽기 (하데스식) | `art/sprite-bake` (PR #7, Codex PASS WITH NOTES `62214bf`) | CC0 KayKit 임시 캐릭터로 파이프라인 검증. PC 벤치 적 22마리 기준 약 550fps, APK 29 MiB |
| 이순신 기술 아이콘·로딩 화면·기준 그림 + Meshy 자동화 도구 | `art/hero-assets` (PR #8, Codex PASS WITH NOTES `bb4a572`) | 실제 Meshy 생성은 아직 하지 않음 |

## 3D 스프라이트 파이프라인 (다시 쓸 때)

- 굽기: `godot --path . -s res://tools/bake/bake_sprites.gd -- --only=<이름>` (창 모드, GPU 필요).
  작업은 스크립트의 `JOBS`와 `tools/bake/jobs/*.json`에 정의한다.
- 결과: `assets/sprites/<이름>/<동작>.png`와 `SpriteSheetSet` `.tres`.
  `HeroData` / `EnemyData`의 `sprite_sheet`에 지정하면 스프라이트로, 비우면 수묵풍 코드 그림으로 그린다.
- 사용자가 GPT로 만든 이순신 기준 그림(정면 A포즈, 정면/측면/후면)은 `assets/concept/yi_sun_sin/`에 있다 (APK 제외).
- Meshy 연동 (`tools/ai3d/meshy_pipeline.py`):
  - 유료 플랜: API 키(`MESHY_API_KEY`)를 등록하고 `plan` → `run --yes`를 실행하면 생성 → 뼈대 → 동작 → 굽기 → 적용까지 한 번에 한다. 영웅 1명당 약 53크레딧.
  - 무료 플랜: API가 없다. 웹에서 만든 GLB를 받아 `import`로 굽기·적용한다.
    - 월 100크레딧, 다운로드 10회.
    - 결과물은 CC BY 4.0이라 "Meshy" 크레딧 표기가 필요하다.

## 조사 결과 (다시 조사하지 않도록)

- 무료로 쓸 수 있는, 뼈대가 들어간 한국 위인 3D 모델은 찾지 못했다.
- 광화문 이순신·세종 동상은 저작물이라 스캔·복제하지 않는다.
- 국가유산청이 공개한 무료 3D 자산(약 545종, Fab/Unity, 출처 표시)은 배경·소품 후보다.
- 이 PC의 GPU(MX450 2GB)로는 이미지 → 3D 로컬 생성이 어렵다.
- APK는 원격 전달 한도 때문에 30 MiB 이하로 유지한다.
  스프라이트는 손실 WebP로 가져오고, 모델·도구·기준 그림은 내보내기에서 뺀다.

## 다음 결정 (사용자)

- 수묵풍을 다듬을지, 3D 굽기(Meshy 무료/유료, 외주)로 갈지, 둘을 섞을지 (예: 수묵 배경·이펙트 + 3D 캐릭터).
