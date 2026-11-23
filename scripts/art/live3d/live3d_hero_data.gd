class_name Live3DHeroData
extends Resource
## 실시간 3D 영웅 그림 설정 (시험, docs/research/live3d_spike.md). 굽지 않고 게임 안에서 3D 모델을 그린다.
## 굽기 작업(tools/bake/jobs/<이름>.json)에서 만든다: tools/live3d/make_live3d_data.gd.
## 동작 길이는 영웅의 구운 시트(sprite_sheet)와 같게 맞춰 피해 시점이 그대로다.

## 모델 장면 (Meshy .glb, gitignore — PC에만 있음).
@export var model_path: String = ""
## 동작 목록: {key, file ("" = 모델), src, start, end, loop}. 구간이 없으면 전체.
@export var clips: Array[Dictionary] = []
## 카메라 (굽기와 같은 각도): 직교 크기(m), 위치, 바라보는 점. 화면 크기(px)는 구운 칸과 같다.
@export var ortho_size: float = 2.0
@export var frame: int = 256
@export var cam_pos: Vector3 = Vector3(0, 6.0, 7.0)
@export var cam_target: Vector3 = Vector3(0, 0.9, 0)
## 조명 (굽기 작업의 "light"와 같은 키).
@export var light: Dictionary = {}
## 수묵 후처리 값 (굽기 작업의 "ink").
@export var ink: Dictionary = {}
## 무기 손뼈 고정 (굽기 작업의 "rigid", 없으면 빈 사전).
@export var rigid: Dictionary = {}
## 동작 섞기(초): 몸 전체 / 윗몸 겹치기.
@export var blend_time: float = 0.1
@export var upper_blend_time: float = 0.08
## 바라보는 방향으로 도는 빠르기 (rad/s). 8방향 칸 없이 부드럽게.
@export var turn_speed: float = 20.0
## 달리며 공격: 이 뼈들만 공격 동작을 따르고 다리는 달리기 그대로 (빈 배열이면 끔).
@export var upper_bones: PackedStringArray = PackedStringArray()
## 뿌리 뼈 (수평 위치를 쉬는 자세로 고정: 굽기의 lock_root).
@export var root_bone: String = "Hips"
## 뼈대 노드 경로 (동작 트랙 앞부분).
@export var skeleton_path: String = "Armature/Skeleton3D"


func clip(key: String) -> Dictionary:
	for c in clips:
		if String(c.get("key", "")) == key:
			return c
	return {}


## 굽기 작업 사전 → 설정 (영웅 고유 값은 그대로 옮긴다).
static func from_job(job: Dictionary) -> Live3DHeroData:
	var d := Live3DHeroData.new()
	d.model_path = String(job.get("model", ""))
	d.ortho_size = float(job.get("ortho_size", 2.0))
	d.frame = int(job.get("frame", 256))
	d.light = job.get("light", {})
	d.ink = job.get("ink", {}) if job.get("style", "") == "ink" else {}
	d.rigid = job.get("rigid", {})
	for a in job.get("anims", []):
		var c := {"key": String(a["key"]), "src": String(a.get("src", "")), "file": String(a.get("from", "")),
			"loop": bool(a.get("loop", false))}
		if a.has("start"):
			c["start"] = float(a["start"])
		if a.has("end"):
			c["end"] = float(a["end"])
		d.clips.append(c)
	return d
