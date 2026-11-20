class_name SkillHitStop
extends RefCounted
## 기술 명중 멈춤 공통 규칙 (D3). 기술마다 따로 정하던 멈춤을 하나로:
## 길이 = base + 피해 × per_damage (최대 cap), 한 번에 여러 적을 맞히면 짧게 (스매시 인원 배율식),
## 멈춤 사이 최소 간격(실제 시간). 한 프레임의 명중을 모아 프레임 끝에 한 번만 멈춘다. 수치는 CombatFeelData.

static var _max_damage: int = 0
static var _count: int = 0
static var _scheduled: bool = false
static var _last_ms: int = -1000000


## 순수 계산: 이번 프레임 가장 큰 피해와 맞은 수 → 멈춤 길이(초).
static func duration(max_damage: int, count: int, f: CombatFeelData) -> float:
	if max_damage <= 0 or count <= 0:
		return 0.0
	var t := minf(f.skill_stop_base + max_damage * f.skill_stop_per_damage, f.skill_stop_cap)
	t *= pow(f.skill_stop_multi, count - 1)
	return maxf(t, f.skill_stop_min)


## 명중 하나 알리기 (SkillContext.hit). 프레임 끝에 모아서 멈춘다.
static func request(tree: SceneTree, damage: int) -> void:
	if tree == null:
		return
	_max_damage = maxi(_max_damage, damage)
	_count += 1
	if not _scheduled:
		_scheduled = true
		_flush.bind(tree).call_deferred()


static func _flush(tree: SceneTree) -> void:
	var f := Feedback.feel_data()
	var now := Time.get_ticks_msec()
	if now - _last_ms >= int(f.skill_stop_min_gap * 1000.0) and is_instance_valid(tree):
		var t := duration(_max_damage, _count, f)
		if t > 0.0:
			GameTime.stop(tree, t, f.skill_stop_scale)
			_last_ms = now
	reset_pending()


static func reset_pending() -> void:
	_max_damage = 0
	_count = 0
	_scheduled = false


## 테스트용: 간격 기록까지 지운다.
static func reset() -> void:
	reset_pending()
	_last_ms = -1000000
