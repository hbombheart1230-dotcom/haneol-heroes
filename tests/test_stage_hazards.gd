extends GdUnitTestSuite
## 무대 장치 (StageHazards): 박자(HazardClock), 줄 고르기·판정(LanePlan), 한산 포격선(LaneStrike), 무대 데이터.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const CANNON := preload("res://data/stages/hazards/hansan_cannon.tres")
const DT := 1.0 / 60.0

var enemies: Array = []


func before_test() -> void:
	enemies = []


func after_test() -> void:
	for n in get_children():
		if n is StageHazards:
			n.free()


func _clock(first: float = 6.0, period: float = 12.0, warn: float = 1.2, boss_mult: float = 1.6) -> HazardClock:
	var d := StageHazardData.new()
	d.first_delay = first
	d.period = period
	d.warn_time = warn
	d.boss_period_mult = boss_mult
	return HazardClock.new(d)


## running·boss 조건으로 seconds초 돌려 일어난 일과 시각들 (시각은 0.05초 단위 정수: 6초 = 120).
func _run(c: HazardClock, seconds: float, running: bool = true, boss: bool = false) -> Array:
	var out := []
	var t := 0.0
	while t < seconds - 0.0001:
		t += DT
		var ev := c.step(DT, running, boss)
		if ev != HazardClock.Event.NONE:
			out.append([ev, roundi(t * 20.0)])  # 0.05초 단위 (실수 비교 대신)
	return out


func test_clock_first_warn_then_every_period_and_strike_after_warn() -> void:
	var ev := _run(_clock(), 31.0)
	assert_array(ev).is_equal([[HazardClock.Event.WARN, 120], [HazardClock.Event.STRIKE, 144],
		[HazardClock.Event.WARN, 360], [HazardClock.Event.STRIKE, 384], [HazardClock.Event.WARN, 600]])


func test_clock_waits_while_not_running_but_finishes_a_started_warning() -> void:
	var c := _clock(1.0)
	assert_array(_run(c, 5.0, false)).is_empty()  # 숨 고르기·고르기 중: 기다림이 줄지 않는다
	assert_array(_run(c, 1.0)).is_equal([[HazardClock.Event.WARN, 20]])
	assert_array(_run(c, 1.3, false)).is_equal([[HazardClock.Event.STRIKE, 24]])  # 시작한 예고는 끝까지


func test_clock_boss_stretches_period_and_zero_rests() -> void:
	var c := _clock(12.0)
	assert_array(_run(c, 19.0, true, true)).is_empty()
	assert_array(_run(c, 0.3, true, true)).has_size(1)  # 12 × 1.6 = 19.2초
	var rest := _clock(1.0, 12.0, 1.2, 0.0)
	assert_array(_run(rest, 30.0, true, true)).is_empty()


func test_beat_times_split_the_warning_evenly() -> void:
	var b := LanePlan.beat_times(1.2, 3)
	assert_int(b.size()).is_equal(3)
	assert_float(b[0]).is_equal_approx(0.0, 0.001)
	assert_float(b[1]).is_equal_approx(0.4, 0.001)
	assert_float(b[2]).is_equal_approx(0.8, 0.001)


func test_pick_row_prefers_the_crowded_visible_row_and_avoids_repeat() -> void:
	var rows := PackedVector3Array([Vector3(-400, -500, 500), Vector3(0, -500, 500), Vector3(400, -500, 500),
		Vector3(3000, -500, 500)])
	var view := Rect2(-360, -640, 720, 1280)
	var crowd := PackedVector2Array([Vector2(0, 410), Vector2(100, 390), Vector2(-50, -10)])
	assert_int(LanePlan.pick_row(rows, view, 120.0, Vector2.ZERO, crowd, 70.0)).is_equal(2)
	assert_int(LanePlan.pick_row(rows, view, 120.0, Vector2.ZERO, crowd, 70.0, 2)).is_equal(1)
	# 적이 없으면 영웅에게 가까운 줄, 화면 밖 줄(3000)은 후보가 아니다.
	assert_int(LanePlan.pick_row(rows, view, 120.0, Vector2(0, 350), PackedVector2Array(), 70.0)).is_equal(2)
	# 화면 안 후보가 없으면 영웅에게 가장 가까운 줄.
	assert_int(LanePlan.pick_row(rows, Rect2(-360, 2400, 720, 1280), 120.0, Vector2(0, 3000), crowd, 70.0)).is_equal(3)


func test_in_lane_counts_the_body_edge_and_lane_ends() -> void:
	var row := Vector3(100, -500, 500)
	assert_bool(LanePlan.in_lane(row, 70.0, Vector2(0, 185), 20.0)).is_true()
	assert_bool(LanePlan.in_lane(row, 70.0, Vector2(0, 195), 20.0)).is_false()
	assert_bool(LanePlan.in_lane(row, 70.0, Vector2(515, 100), 20.0)).is_true()
	assert_bool(LanePlan.in_lane(row, 70.0, Vector2(530, 100), 20.0)).is_false()


func test_each_stage_has_its_own_hazard() -> void:  # 한산 포격선 · 경복궁 엄폐 · 만주 들불 · 초충도 풀숲
	var hansan: StageTheme = load("res://data/stages/hansan_1592.tres")
	assert_int(hansan.hazards.size()).is_equal(1)
	var lane := hansan.hazards[0] as LaneStrikeData
	assert_object(lane).is_not_null()
	assert_float(lane.period).is_equal(12.0)
	assert_int(lane.beats).is_equal(3)
	assert_int(lane.enemy_damage).is_equal(60)
	assert_int(lane.hero_damage).is_equal(10)
	assert_int(lane.rows.size()).is_equal(5)
	var gb: StageTheme = load("res://data/stages/gyeongbokgung_1433.tres")
	assert_int(gb.hazards.size()).is_equal(1)
	assert_object(gb.hazards[0] as CoverData).is_not_null()
	var mc: StageTheme = load("res://data/stages/manchuria_395.tres")
	assert_int(mc.hazards.size()).is_equal(1)
	assert_object(mc.hazards[0] as FireData).is_not_null()
	var cc: StageTheme = load("res://data/stages/chochungdo.tres")
	assert_int(cc.hazards.size()).is_equal(1)
	assert_object(cc.hazards[0] as GrassData).is_not_null()


func _host() -> StageHazards:
	var hz := StageHazards.new()
	add_child(hz)
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	h.max = 100
	h.current = 100
	p.add_child(h)
	add_child(p)
	p.hero = YI
	p.set_physics_process(false)
	hz.player = p
	return hz


func _enemy(pos: Vector2, hp: int = 999) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = pos
	e.health.max = hp
	e.health.current = hp
	enemies.append(e)
	return e


func _lane(hz: StageHazards) -> LaneStrike:
	hz.setup([CANNON] as Array[StageHazardData])
	assert_int(hz.hazard_count()).is_equal(1)
	var lane := hz.get_child(0) as LaneStrike
	lane.set_physics_process(false)
	return lane


func test_strike_hits_enemies_on_the_line_hard_and_the_hero_lightly() -> void:
	var hz := _host()
	var lane := _lane(hz)
	lane.row = 2
	var y := CANNON.rows[2].x
	var on := _enemy(Vector2(0, y + 30))
	var off := _enemy(Vector2(0, y + 200))
	hz.player.global_position = Vector2(300, y - 40)
	lane.strike()
	assert_int(on.health.current).is_equal(999 - 60)
	assert_int(off.health.current).is_equal(999)
	assert_int(lane.last_enemy_hits).is_equal(1)
	assert_bool(lane.last_hero_hit).is_true()
	assert_int(hz.player.health.current).is_equal(90)
	assert_float(on.knockback.y).is_greater(0.0)  # 줄 아래에 있었으니 아래로 밀린다


func test_invulnerable_or_off_line_hero_is_not_hurt() -> void:
	var hz := _host()
	var lane := _lane(hz)
	lane.row = 1
	var y := CANNON.rows[1].x
	hz.player.global_position = Vector2(0, y)
	hz.player.grant_invulnerability(1.0)  # 대시·회피 무적과 같은 길
	lane.strike()
	assert_bool(lane.last_hero_hit).is_false()
	assert_int(hz.player.health.current).is_equal(100)
	var hz2 := _host()
	var lane2 := _lane(hz2)
	lane2.row = 1
	hz2.player.global_position = Vector2(0, y + 130)
	lane2.strike()
	assert_bool(lane2.last_hero_hit).is_false()


func test_running_follows_the_main_check_and_wave_phase() -> void:
	var hz := _host()
	assert_bool(hz.running()).is_true()
	hz.running_check = func() -> bool: return false
	assert_bool(hz.running()).is_false()
	hz.running_check = Callable()
	var sp: EnemySpawner = auto_free(EnemySpawner.new())
	sp.waves = WaveRunner.new(WaveSetData.new())
	hz.spawner = sp
	sp.waves.phase = WaveRunner.Phase.GAP
	assert_bool(hz.running()).is_false()  # 숨 고르기
	sp.waves.phase = WaveRunner.Phase.BOSS_WAIT
	assert_bool(hz.running()).is_false()  # 우두머리 등장
	sp.waves.phase = WaveRunner.Phase.RUN
	assert_bool(hz.running()).is_true()
	assert_bool(hz.boss()).is_false()
	sp.waves.phase = WaveRunner.Phase.BOSS
	assert_bool(hz.running()).is_true()
	assert_bool(hz.boss()).is_true()


func test_lane_warns_with_beats_then_strikes() -> void:
	var hz := _host()
	var lane := _lane(hz)
	var y := CANNON.rows[2].x
	hz.player.global_position = Vector2(0, y + 260)
	var on := _enemy(Vector2(100, y))
	lane.clock.wait = 0.01
	lane._physics_process(DT)
	assert_bool(lane.clock.warning()).is_true()
	assert_int(lane.row).is_not_equal(-1)
	lane.row = 2  # 시험 창 크기와 무관하게 이 줄로
	assert_int(lane._beat_i).is_equal(1)  # 예고 시작 틀에 첫 북
	for i in roundi(1.3 / DT):
		lane._physics_process(DT)
	assert_int(lane._beat_i).is_equal(3)  # 북 세 번
	assert_bool(lane.clock.warning()).is_false()
	assert_int(lane.strikes).is_equal(1)
	assert_int(on.health.current).is_equal(999 - 60)
