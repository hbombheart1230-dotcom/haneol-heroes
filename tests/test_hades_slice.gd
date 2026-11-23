extends GdUnitTestSuite
## 하데스 슬라이스 (docs/research/hades_slice.md): 바닥 대비, 물결 모드 (최대 8·예고 뒤 등장·2마리 이하에서 이어서),
## 예고 규칙 통일, 물결 끝 숨 고르기, 보스 3단계. 물결·바닥·보스 단계는 무대 데이터로만 켜진다.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const HANSAN := preload("res://data/stages/hansan_1592.tres")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const COMMANDER := preload("res://data/enemies/waegun_commander.tres")
const DT := 1.0 / 60.0


func after_test() -> void:
	EnemyAttack.active_windups = 0


func _wave_set(waves: Array, first: int = 2) -> WaveSetData:
	var s := WaveSetData.new()
	for n in waves:
		var w := WaveData.new()
		for i in int(n):
			w.enemies.append(SOLDIER)
		w.first_count = first
		s.waves.append(w)
	s.gap_time = 0.5
	s.boss_delay = 0.5
	s.spawn_stagger = 0.0
	return s


func test_runner_releases_first_then_rest_when_two_left() -> void:
	var r := WaveRunner.new(_wave_set([5], 2), 0.0)
	r.tick(DT, 0, false)
	assert_bool(r.is_fighting()).is_true()
	assert_int(r.next_spawn(0, 8).size()).is_equal(1)
	assert_int(r.next_spawn(1, 8).size()).is_equal(1)
	assert_int(r.next_spawn(2, 8).size()).is_equal(0)  # 처음 둘만
	r.tick(DT, 3, false)
	assert_int(r.next_spawn(3, 8).size()).is_equal(0)  # 셋 남았으면 기다림
	r.tick(DT, 2, false)
	assert_int(r.next_spawn(2, 8).size()).is_equal(1)  # 둘 이하 → 이어서
	assert_int(r.next_spawn(3, 8).size()).is_equal(1)
	assert_int(r.next_spawn(4, 4).size()).is_equal(0)  # 화면 최대


func test_runner_clear_gap_hold_and_boss() -> void:
	var r := WaveRunner.new(_wave_set([1, 1], 1), 0.0)
	r.tick(DT, 0, false)
	r.next_spawn(0, 8)
	assert_int(r.tick(DT, 1, false)).is_equal(WaveRunner.Event.NONE)
	assert_int(r.tick(DT, 0, false)).is_equal(WaveRunner.Event.CLEARED)
	assert_int(r.phase).is_equal(WaveRunner.Phase.GAP)
	for i in 120:  # 강화 고르는 동안은 다음 물결을 기다린다
		r.tick(DT, 0, true)
	assert_int(r.index).is_equal(0)
	for i in 40:
		r.tick(DT, 0, false)
	assert_int(r.index).is_equal(1)
	r.next_spawn(0, 8)
	assert_int(r.tick(DT, 0, false)).is_equal(WaveRunner.Event.CLEARED)  # 마지막 물결
	var got_boss := false
	for i in 40:
		if r.tick(DT, 0, false) == WaveRunner.Event.BOSS:
			got_boss = true
	assert_bool(got_boss).is_true()


## 스포너 물결 모드: 화면 안에 먹 번짐 예고 → warn_time 뒤 등장 (그 전엔 적 없음), 예고도 최대 수에 센다.
func test_spawner_warns_then_spawns_on_screen() -> void:
	var target := Node2D.new()
	add_child(auto_free(target))
	var sp: EnemySpawner = auto_free(EnemySpawner.new())
	sp.enemy_scene = ENEMY_SCENE
	sp.target = target
	sp.max_alive = 8
	add_child(sp)
	sp.set_physics_process(false)
	var s := _wave_set([3], 3)
	sp.set_waves(s)
	assert_bool(sp.horde_enabled).is_false()
	for i in ceili(0.6 / DT):  # 첫 숨 고르기 0.5초 + 한 프레임
		sp.tick(DT)
	assert_int(sp.alive_count()).is_equal(0)
	assert_int(sp._warnings).is_equal(3)
	for c in sp.get_children():
		if c is SpawnWarning:
			var d := (c as Node2D).global_position.distance_to(target.global_position)
			assert_float(d).is_between(s.spawn_min - 1.0, s.spawn_max + 1.0)
			(c as SpawnWarning)._physics_process(s.warn_time + 0.01)
	assert_int(sp.alive_count()).is_equal(3)
	assert_bool(sp.can_offer()).is_false()  # 싸움 중엔 강화를 쌓아 둔다
	assert_float(sp.xp_mult()).is_equal(s.xp_mult)


func test_slice_look_is_hansan_only_and_waves_everywhere() -> void:
	assert_object(HANSAN.waves).is_not_null()
	assert_int(HANSAN.waves.waves.size()).is_equal(4)  # 물결 넷 + 보스 = 5웨이브
	assert_int(HANSAN.waves.max_alive).is_equal(14)
	assert_object(HANSAN.look).is_not_null()
	assert_float(HANSAN.camera_zoom).is_greater(1.0)
	for id in ["manchuria_395", "gyeongbokgung_1433", "chochungdo"]:  # 물결 방식은 네 무대 모두 (test_stage_waves)
		var st: StageTheme = load("res://data/stages/%s.tres" % id)
		assert_object(st.waves).override_failure_message(id).is_not_null()
		assert_float(st.floor_value).is_equal(1.0)


## 바닥 색 보정 (floor_grade.gdshader와 같은 식, 빛 웅덩이 빼고): 하데스처럼 어둡지만 명암 폭이 넓고 색이 있다.
## 측정 근거: 하데스 화면 밝기 편차 0.16~0.19, 한얼 예전 바닥 0.10 (tools/shots/measure_look.py).
func test_hansan_floor_is_dark_but_contrasty_and_coloured() -> void:
	var l: StageLook = HANSAN.look
	var img := (load(HANSAN.background_path) as Texture2D).get_image()
	img.resize(64, 64)
	var ys := PackedFloat32Array()
	var sat := 0.0
	for y in 64:
		for x in 64:
			var g := _grade(img.get_pixel(x, y), l)
			ys.append(_luma(g))
			sat += g.s
	var mean := 0.0
	for v in ys:
		mean += v
	mean /= ys.size()
	var var_sum := 0.0
	for v in ys:
		var_sum += (v - mean) * (v - mean)
	assert_float(mean).is_less_equal(0.3)
	assert_float(sqrt(var_sum / ys.size())).is_greater_equal(0.1)
	assert_float(sat / 4096.0).is_greater_equal(0.4)


static func _luma(c: Color) -> float:
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722


## shaders/floor_grade.gdshader fragment()를 그대로 옮긴 것.
static func _grade(c: Color, l: StageLook) -> Color:
	var y := _luma(c)
	var v := Vector3(c.r, c.g, c.b)
	v = (Vector3(y, y, y).lerp(v, l.saturation)) * l.value_mult
	v = ((v - Vector3.ONE * l.pivot) * l.contrast + Vector3.ONE * l.pivot).max(Vector3.ZERO)
	var y2 := v.x * 0.2126 + v.y * 0.7152 + v.z * 0.0722
	var t := clampf((y2 - l.tint_split * 0.4) / (l.tint_split * 1.4), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var tc := l.shadow_tint.lerp(l.light_tint, t)
	var tv := Vector3(tc.r, tc.g, tc.b) * (y2 / maxf(_luma(tc), 0.02))
	v = v.lerp(tv, l.tint_mix)
	return Color(v.x, v.y, v.z)


## 공통 예고 규칙: 모든 적 공격 예고 ≥ min_windup, 마지막 strike_flash_time초 번쩍, 예고음 하나.
func test_unified_telegraph_rule() -> void:
	var ai := Enemy.ai_data()
	var dir := DirAccess.open("res://data/enemies")
	for f in dir.get_files():
		if not f.ends_with(".tres") or f == "enemy_ai.tres":
			continue
		var d := load("res://data/enemies/" + f) as EnemyData
		if d == null:
			continue
		var atks: Array = [d.attack] + d.patterns
		for ph: BossPhaseData in d.phases:
			atks.append_array(ph.patterns)
		for a in atks:
			if a:
				assert_float((a as EnemyAttackData).windup).override_failure_message(f).is_greater_equal(ai.min_windup)
	for k in ai.attack_sfx.keys():
		assert_str(String(ai.attack_sfx[k][0])).is_equal("e_windup")
	var atk := EnemyAttack.new(SOLDIER.attack)
	atk.state = EnemyAttack.State.WINDUP
	atk._timer = 0.3
	assert_bool(atk.is_flashing(ai.strike_flash_time)).is_false()
	atk._timer = 0.1
	assert_bool(atk.is_flashing(ai.strike_flash_time)).is_true()


## 한 방 피해 = 순신 체력의 10~30% 안 (하데스 6~28%).
func test_waegun_hits_are_10_to_30_percent() -> void:
	var hp := float((load("res://data/heroes/yi_sun_sin.tres") as HeroData).max_hp)
	for f in ["waegun_soldier", "waegun_gunner", "waegun_heavy", "waegun_elite", "waegun_commander"]:
		var d: EnemyData = load("res://data/enemies/%s.tres" % f)
		var atks: Array = [d.attack] + d.patterns
		for a in atks:
			if a:
				assert_float((a as EnemyAttackData).damage / hp).override_failure_message(f).is_between(0.1, 0.3)


func test_boss_phase_thresholds() -> void:
	var ph: Array[BossPhaseData] = COMMANDER.phases
	assert_int(ph.size()).is_equal(2)
	assert_int(BossPhases.due(ph, 0, 0.9)).is_equal(0)
	assert_int(BossPhases.due(ph, 0, 0.6)).is_equal(1)
	assert_int(BossPhases.due(ph, 1, 0.6)).is_equal(1)
	assert_int(BossPhases.due(ph, 0, 0.2)).is_equal(2)  # 한 번에 두 단계
	var scaled := BossPhases.scaled_patterns(ph[1].patterns, ph[1].cooldown_mult)
	assert_float((scaled[0] as EnemyAttackData).cooldown).is_less((ph[1].patterns[0] as EnemyAttackData).cooldown)


## 보스가 66% 아래로: 공격이 셋으로 늘고, 잠깐 무적, 부하 넷이 예고 뒤 온다.
func test_boss_enters_phase_two_and_summons() -> void:
	var target := Node2D.new()
	add_child(auto_free(target))
	var sp: EnemySpawner = auto_free(EnemySpawner.new())
	sp.enemy_scene = ENEMY_SCENE
	sp.target = target
	add_child(sp)
	sp.set_physics_process(false)
	var boss := sp.spawn_at(COMMANDER, Vector2(200, 0))
	boss.set_physics_process(false)
	assert_int(boss.attack.patterns.size()).is_equal(COMMANDER.patterns.size())
	boss.health.damage(roundi(boss.health.max * 0.4))
	assert_int(boss.phase_index).is_equal(1)
	assert_int(boss.attack.patterns.size()).is_equal(COMMANDER.phases[0].patterns.size())  # 단계마다 공격 목록이 바뀐다 (군기 꽂기·먼 돌진 포함)
	assert_float(boss.phase_invuln).is_greater(0.0)
	assert_int(sp._warnings).is_equal(COMMANDER.phases[0].summon.size())  # 연출 없이(spawn_at) 부르면 바로 소환
	var hp := boss.health.current
	boss._update_damage_mult()
	boss.health.damage(50)
	assert_int(boss.health.current).is_equal(hp)  # 단계가 바뀐 순간 무적


## 물결 등장 자리는 장애물 속을 피한다 (Codex e423e86), 그리고 elite_last가 아닌 물결도 첫 무리가 나온다.
func test_spawn_point_avoids_obstacles_and_plain_wave_has_budget() -> void:
	var sp: EnemySpawner = auto_free(EnemySpawner.new())
	add_child(sp)
	sp.set_physics_process(false)
	var obs := Obstacles.new()
	add_child(auto_free(obs))
	obs.build(PackedVector3Array([Vector3(300, 0, 200)]))  # 오른쪽을 큰 바위가 막는다
	sp.blocked_check = obs.blocks
	for i in 40:
		var p := sp.near_point(Vector2.ZERO, 260.0, 420.0)
		assert_bool(obs.blocks(p, sp.spawn_clearance)).is_false()
	var r := WaveRunner.new(_wave_set([3], 2), 0.0)  # elite_last = false
	r.tick(DT, 0, false)
	assert_bool(r.is_fighting()).is_true()
	assert_int(r.next_spawn(0, 8).size()).is_equal(1)


## 보스 부하 소환 자리도 장애물 속이면 옮긴다 (Codex 3ceebe3).
func test_safe_point_moves_out_of_obstacles() -> void:
	var sp: EnemySpawner = auto_free(EnemySpawner.new())
	add_child(sp)
	sp.set_physics_process(false)
	var obs := Obstacles.new()
	add_child(auto_free(obs))
	obs.build(PackedVector3Array([Vector3(150, 0, 60)]))
	sp.blocked_check = obs.blocks
	assert_vector(sp.safe_point(Vector2(-150, 0), Vector2.ZERO, 150.0, 230.0)).is_equal(Vector2(-150, 0))  # 빈 자리는 그대로
	var p := sp.safe_point(Vector2(150, 0), Vector2.ZERO, 150.0, 230.0)
	assert_bool(obs.blocks(p, sp.spawn_clearance)).is_false()
