class_name SkillHitStop
extends RefCounted
## 기술 명중 멈춤 공통 규칙 (D3). 기술마다 따로 정하던 멈춤을 하나로:
## 길이 = base + 피해 × per_damage (최대 cap), 한 번에 여러 적을 맞히면 짧게 (스매시 인원 배율식),
## 멈춤 사이 최소 간격(실제 시간). 한 프레임의 명중을 모아 프레임 끝에 한 번만 멈춘다. 수치는 CombatFeelData.

static var _max_damage: int = 0
static var _count: int = 0
static var _scheduled: bool = false
static var _last_ms: int = -1000000
## 이번 프레임 명중 멈춤을 이 길이로 고정 (넷째 탭 마무리의 칼이 박히는 멈춤, BladeBiteData.finisher_stop):
## 길이·건 시각(ms)·풀릴 때 소리. FORCE_WINDOW_MS 안의 명중에만 쓴다 (빗나간 마무리가 다음 기술에 남지 않게).
static var _forced: float = 0.0
static var _forced_ms: int = -1000000
const FORCE_WINDOW_MS := 50
static var _forced_sfx: StringName = &""
static var _forced_pitch: float = 1.0


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


## 이번 프레임의 명중 멈춤을 seconds로 (간격 규칙 무시: 마무리는 늘 멈춘다), 풀릴 때 sfx.
static func force_next(seconds: float, sfx: StringName = &"", pitch: float = 1.0) -> void:
	_forced = seconds
	_forced_ms = GameTime.now_ms()
	_forced_sfx = sfx
	_forced_pitch = pitch


static func _flush(tree: SceneTree) -> void:
	var f := Feedback.feel_data()
	var now := GameTime.now_ms()
	if _forced > 0.0 and now - _forced_ms <= FORCE_WINDOW_MS and is_instance_valid(tree):
		GameTime.stop(tree, _forced, f.skill_stop_scale)
		_last_ms = now
		if _forced_sfx != &"" and Feedback.instance:
			var kind := _forced_sfx
			var pitch := _forced_pitch
			tree.create_timer(_forced, true, false, true).timeout.connect(func() -> void:
				if Feedback.instance:
					Feedback.instance.play(kind, 0.03, pitch))
		_forced = 0.0
		reset_pending()
		return
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
	_forced = 0.0
	_last_ms = -1000000
