extends GdUnitTestSuite
## 대시 마지막 물리 프레임 (외부 감사, 통합 세션 확인 84b0930): compute_velocity가 남은 시간만큼 마지막 걸음을 돌려주면서
## 대시를 끝내 버려, 그 프레임의 돌진 타격·밀쳐내기·도착 전 틱이 빠지고 접촉 피해가 한 프레임 일찍 들어왔다.
## 마지막 걸음도 대시: 그 선분 안의 적은 맞고, 그 프레임 접촉 피해는 없다.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const DT := 1.0 / 60.0


## 접촉 센서 없이 닿은 피해를 정해 주는 영웅 (물리 겹침 대신).
class TouchPlayer extends Player:
	var touch: int = 0

	func _touching_damage() -> int:
		return touch


func after_test() -> void:
	BossSim.reset_globals()


func _player() -> TouchPlayer:
	var p: TouchPlayer = auto_free(TouchPlayer.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = YI
	add_child(p)
	p.set_physics_process(false)
	return p


func _enemy(at: Vector2) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = at
	return e


## 마지막 프레임 전까지 돌린다. 반환: 그때 남은 대시 시간 (한 틱보다 짧다).
func _to_last_frame(p: Player) -> float:
	var guard := 0
	while p._dash_time_left > DT and guard < 60:
		p._physics_process(DT)
		guard += 1
	return p._dash_time_left


## 마지막 걸음에만 걸치는 적도 돌진 타격을 맞는다 (그리고 맞힌 대가: 충전 하나 더·끝 경직).
func test_enemy_in_the_last_step_is_struck() -> void:
	var p := _player()
	var lead := _enemy(Vector2(150, 0))  # 돌진 방향 판정용 (적 쪽 = 돌진 타격)
	await get_tree().physics_frame
	assert_bool(p.request_dash(Vector2.RIGHT)).is_true()
	assert_bool(p.dash_strikes).is_true()
	lead.global_position = Vector2(0, 2000)  # 판정만 하고 길에서 치운다
	var left := _to_last_frame(p)
	assert_float(left).is_greater(0.0)
	var step := YI.dash_distance / YI.dash_duration * left  # 마지막 걸음 길이
	var e := _enemy(Vector2(0, -2000))
	var reach := YI.dash_dir.strike_radius + e.body_radius * e.size_mult
	e.global_position = p.global_position + Vector2.RIGHT * (reach + step * 0.5)  # 지금 자리에선 밖, 마지막 걸음 끝에선 안
	var hp := e.health.current
	var charges := p.dash.charges
	p._physics_process(DT)
	assert_bool(p.is_dashing()).is_false()
	assert_int(e.health.current).is_less(hp)
	assert_bool(p.dash_struck.has(e.get_instance_id())).is_true()
	assert_int(p.dash.charges).is_less(charges)  # 마지막 프레임에 처음 맞혀도 대가는 붙는다 (충전 하나 더)


## 마지막 프레임까지 대시 무적: 닿아 있어도 그 프레임엔 접촉 피해 없음, 다음 프레임부터 받는다.
func test_no_contact_damage_on_the_last_dash_frame() -> void:
	var p := _player()
	await get_tree().physics_frame
	p.request_dash(Vector2.RIGHT)
	_to_last_frame(p)
	p.touch = 10
	var hp := p.health.current
	p._physics_process(DT)
	assert_bool(p.is_dashing()).is_false()
	assert_int(p.health.current).is_equal(hp)
	p._physics_process(DT)
	assert_int(p.health.current).is_less(hp)
