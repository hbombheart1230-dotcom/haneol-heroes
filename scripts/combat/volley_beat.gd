class_name VolleyBeat
extends RefCounted
## 일제 사격 한 번을 가리키는 열쇠와 그 열쇠의 명중 수: 같은 일제 사격의 탄은 같은 열쇠를 단다.
## 같은 열쇠의 탄이 영웅을 VolleyFeelData.max_hero_hits번 맞히면 나머지는 지나간다 (피해 12×8 즉사 방지).
## 대형(FormationBrain)은 모두 같은 물리 프레임에 쏜다 → 대형 + 프레임. 대형 밖 일제 사격(EnemyAttackData.volley)은
## 같은 박자 창(EnemyAIData.volley_interval)에 함께 쏜다 → 박자 번호.

const KEEP := 32
static var _hits: Dictionary = {}


## e가 지금 쏘는 탄의 열쇠 ("" = 일제 사격 아님).
static func key_for(e: Enemy) -> String:
	if e == null or e.attack == null:
		return ""
	if e.formation != null:
		return "f%d:%d" % [e.formation.get_instance_id(), Engine.get_physics_frames()]
	if e.attack.data.volley:
		var ai := e.attack.ai
		if ai and ai.volley_interval > 0.0:
			return "b%d" % floori(EnemyAttack.now_sec() / ai.volley_interval)
	return ""


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
