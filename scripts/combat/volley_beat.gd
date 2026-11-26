class_name VolleyBeat
extends RefCounted
## 일제 사격 한 번을 가리키는 열쇠와 그 열쇠의 명중 수: 같은 일제 사격의 탄은 같은 열쇠를 단다.
## 같은 열쇠의 탄이 영웅을 VolleyFeelData.max_hero_hits번 맞히면 나머지는 지나간다 (피해 12×8 즉사 방지).
## 대형(FormationBrain)의 일제 사격만 센다. 판이 시작할 때(EnemySpawner)와 시뮬마다(BossSim.reset_globals) 비운다.

const KEEP := 32
const META := &"volley_serial"
static var _hits: Dictionary = {}


## e가 지금 쏘는 탄의 열쇠 ("" = 일제 사격 아님). 대형 구성원만: 대형 + 그 대형의 일제 사격 번호
## (FormationBrain.fired마다 하나씩 는다 — 물리 프레임 하나에 틱이 여러 번 도는 시뮬에서도 일제 사격마다 따로).
## 대형 밖 철포병(우두머리가 부른 대장·정예 포함)은 상한 없이 예전 그대로.
static func key_for(e: Enemy) -> String:
	if e == null or e.formation == null:
		return ""
	var f := e.formation
	if not f.has_meta(META):
		f.set_meta(META, 0)
		var wf: WeakRef = weakref(f)  # 대형(RefCounted)을 붙잡지 않게
		f.fired.connect(func(_m: Array) -> void: _next(wf.get_ref()))
	return "f%d:%d" % [f.get_instance_id(), int(f.get_meta(META))]


static func _next(f: Object) -> void:
	if f:
		f.set_meta(META, int(f.get_meta(META, 0)) + 1)


## 이 열쇠의 탄이 아직 영웅을 맞힐 수 있는지 ("" = 늘).
static func can_hit(key: String, cap: int = -1) -> bool:
	if key == "":
		return true
	var c := cap if cap >= 0 else VolleyFeelData.default().max_hero_hits
	return int(_hits.get(key, 0)) < c


static func note_hit(key: String) -> void:
	if key == "":
		return
	_hits[key] = int(_hits.get(key, 0)) + 1
	while _hits.size() > KEEP:  # 오래된 것부터 버린다 (넣은 차례)
		_hits.erase(_hits.keys()[0])


static func hits(key: String) -> int:
	return int(_hits.get(key, 0))


static func reset() -> void:
	_hits.clear()
