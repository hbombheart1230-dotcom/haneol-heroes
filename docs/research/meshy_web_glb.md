# Meshy 웹 GLB → 굽기·3D 가공 (뼈대·동작 0크레딧)

Meshy 웹에서는 뼈대·동작이 무료다 (모델 생성만 크레딧). API를 거치지 않아 `state.json`·task id가 없고, 뼈대·동작이 든 `.glb`만 받는다.
원본 `.glb`는 커밋하지 않는다 (`assets/models/meshy/<이름>/`는 gitignore).

## 웹 뼈대 (MeshyRig)
- 뼈대 노드 `SmartRigArmature/Skeleton3D` (API: `Armature/Skeleton3D`). 뼈 이름은 API와 같다 (`Hips`, `Spine02`, `LeftArm`, `RightHand` …).
- 손가락 뼈가 있어 72관절 (API 24관절). 한쪽 손가락은 이름 없는 `Bone_0xx`로 나오기도 한다.
- 무기는 몸과 한 덩어리로 용접되고 양손 손가락 뼈에 나뉘어 묶인다.

## 1. 웹 GLB로 굽기 (잡몹·영웅 시트)
1. 설정(`tools/ai3d/<enemies|heroes>/<이름>.json`)의 동작마다 `"web": "<파일 안 동작 이름>"`을 적는다 (없으면 `match` 후보로 찾는다).
   구간·맞닿는 칸·칸 시각(`start`·`end`·`strike`·`times`·`yaw`)과 `bake`의 수묵·압축·무기 묶기는 API 경로와 같은 키를 쓴다.
2. `python tools/ai3d/meshy_pipeline.py import <설정.json> <받은.glb> --no-bake`
   → `.glb`를 `assets/models/meshy/<이름>/`로 복사하고 `tools/bake/jobs/<이름>.json`을 쓴다.
3. 구간 고르기: `godot --path . -s res://tools/bake/clip_sheet.gd -- --job=<이름> --anim=<키> --out=<png> --samples=20 --size=200`
4. 이동 동작 fps: `godot --headless --path . -s res://tools/bake/stride.gd -- --job=<이름> --speed=<px/s> --scale=<sprite_scale>`
5. 굽기: `godot --path . -s res://tools/bake/bake_sprites.gd -- --only=<이름>`

## 2. 웹 동작을 기존 API 뼈대 캐릭터에 (빠진 동작 채우기)
굽기 작업의 동작에 `"from": "res://assets/models/meshy/<웹 파일>.glb"`, `"src": "<동작 이름>"`을 주면 된다.
`ClipRetarget`(tools/bake/clip_retarget.gd)이 뼈 트랙의 뼈대 경로를 바꾸고, 뿌리 뼈 위치를 쉬는 자세 높이 비로 맞춘다.

확인 (2026-11-23, 한산 대장 = API 뼈대에 여진 궁수 웹 파일의 동작):
- `Dead`: 비틀거리다 앞으로 쓰러진다. 사망·쓰러짐으로 쓸 수 있다.
- `Running`: 다리·망토가 자연스럽게 움직인다.
- 경로만 바꾸고 높이를 맞추지 않으면 엉덩이 높이가 달라 주저앉는다 (높이 비 0.8 → 1.0 정도).
- 손가락 뼈 트랙은 API 뼈대에 없는 뼈라 무시된다.
- 회전은 그대로 옮긴다. 두 Meshy 뼈대의 쉬는 자세 축이 같아서 맞는다. 다른 회사 뼈대(Mixamo 등)는 별도 리타깃이 필요하다.

→ 한산 대장의 사망·돌진·땅 찍기, 왜군 병사의 창 걷기 같은 빠진 동작은 웹에서 그 동작을 아무 Meshy 캐릭터에 붙여 받은 `.glb`로 채울 수 있다.
실시간 3D(`tools/live3d/pack_model.gd`)는 아직 이 경로 바꾸기를 하지 않는다. 동작 `.res`를 뽑을 때 같은 처리를 넣어야 한다.

## 3. 여진 궁수 웹 모델 (2026-11-23) — 아직 게임에 넣지 않음
- 파일: 메인 체크아웃 `build/meshy_agent/jurchen_archer/dl/jurchen_archer_web_meshyrig.glb`. 동작: Idle, Walking, Running, Archery_Shot, Dead, Hit_Reaction_to_Waist.
- 고른 구간 (설정 초안): run = Walking 8칸 8.5fps (발 속도 측정), attack = Archery_Shot 2.3~4.5초 (당김 2.3~3.9, 놓음 4.15),
  hit = 0.15/0.35/0.6초, down = Dead (쓰러지는 순간이 1.8~2.3초라 그쪽으로).
- 문제: 모델은 오른손에 활을 들었는데 Archery_Shot은 왼손 활·오른손 당김이다. 당기는 손에 활이 매달려 쏘기가 빈손 같다.
- 좌우 뒤집기로 시험했다 (굽기에서 뼈마다 쉬는 자세 기준 움직임을 X 거울에 비춰 반대쪽 뼈에 입힘). 몸은 맞게 뒤집혀 오른손이 앞으로 뻗었다.
  하지만 활·시위·화살이 한 메시로 용접돼 양손 손가락 뼈(`Bone_0xx`·`RightHandThumb/Ring/Pinky`)에 나뉘어 묶여 있어 돛처럼 늘어났다.
  활을 오른손 하나에 묶어도(rigid) 마찬가지였다. 좌우 뒤집기로는 해결되지 않는다 → 왼손 활 모델이 필요하다 (뒤집기 코드는 넣지 않음).
- 미리보기: `build/preview/archer_web_compare.png` (지금 ↔ 새 것, 게임 크기), `archer_shot_mirror_d2_bg.png` (뒤집기 시험).
