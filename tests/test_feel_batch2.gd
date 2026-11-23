extends GdUnitTestSuite
## 타격감 2단계 (docs/research/game_feel_benchmark.md A2·C1·S1·S2): 조준 보정, 거리 유지 고리, 영웅별 겹 명중음, 확인음.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SOLDIER := preload("res://data/enemies/jurchen_soldier.tres")
const BANK := preload("res://data/audio/sfx_bank.tres")
const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]
const DT := 1.0 / 60.0


func after_test() -> void:
	Feedback.instance = null
	AttackTokens.clear()


func _node(pos: Vector2) -> Node2D:
	var n: Node2D = auto_free(Node2D.new())
	add_child(n)
	n.global_position = pos
	return n


func test_assist_snaps_inside_cone() -> void:
	var a := _node(Vector2(100, 30))
	var dir := Targeting.assist_dir([a], Vector2.ZERO, Vector2.RIGHT, 80.0, 600.0, false)
	assert_vector(dir).is_equal_approx(Vector2(100, 30).normalized(), Vector2(0.001, 0.001))
	# 부채꼴 밖, 되돌리기 없음 → 그대로
	var b := _node(Vector2(-100, 0))
	assert_vector(Targeting.assist_dir([b], Vector2.ZERO, Vector2.RIGHT, 80.0, 600.0, false)).is_equal(Vector2.RIGHT)
	# 부채꼴 밖, 되돌리기 → 가장 가까운 적 쪽 (도망치며 써도 적에게)
	assert_vector(Targeting.assist_dir([b], Vector2.ZERO, Vector2.RIGHT, 80.0, 600.0, true)).is_equal_approx(Vector2.LEFT, Vector2(0.001, 0.001))
	# 0도면 끔, 사거리 밖이면 무시
	assert_vector(Targeting.assist_dir([a], Vector2.ZERO, Vector2.RIGHT, 0.0, 600.0, true)).is_equal(Vector2.RIGHT)
	assert_vector(Targeting.assist_dir([a], Vector2.ZERO, Vector2.RIGHT, 80.0, 50.0, true)).is_equal(Vector2.RIGHT)


func test_assist_prefers_smallest_angle() -> void:
	var near_wide := _node(Vector2(60, 40))
	var far_straight := _node(Vector2(300, 5))
	var dir := Targeting.assist_dir([near_wide, far_straight], Vector2.ZERO, Vector2.RIGHT, 80.0, 600.0, true)
	assert_vector(dir).is_equal_approx(Vector2(300, 5).normalized(), Vector2(0.001, 0.001))


func test_directional_skills_have_aim_assist() -> void:
	var yi: HeroData = load("res://data/heroes/yi_sun_sin.tres")
	var sj: HeroData = load("res://data/heroes/sejong.tres")
	var found := 0
	for k in [yi.kit.tap, yi.kit.dash, yi.kit.charge, yi.kit.counter, sj.kit.tap, sj.kit.dash, sj.kit.charge, sj.kit.counter]:
		if k is ConstellationSkill:
			assert_float(k.aim_assist_deg).is_greater(0.0)
			found += 1
		elif k is HaeilSkill:  # 사용자 (b416fc1 폰 의견): 모으는 동안 잡은 방향으로 곧게, 보정 없음 (test_charge_aim)
			assert_bool(k.charge_aim).is_true()
			assert_float(k.aim_assist_deg).is_equal(0.0)
			found += 1
		else:
			assert_float(k.aim_assist_deg).is_equal(0.0)  # 다른 기술은 그대로
	assert_int(found).is_equal(2)


func test_stand_off_stops_and_backs_off() -> void:
	var to := Vector2.RIGHT
	assert_vector(EnemyBrain.stand_off(to, to, 200.0, 40.0, 24.0)).is_equal(to)  # 멀면 그대로
	assert_float(EnemyBrain.stand_off(to, to, 40.0, 40.0, 24.0).x).is_equal_approx(0.0, 0.001)  # 고리에서 멈춤
	assert_float(EnemyBrain.stand_off(to, to, 52.0, 40.0, 24.0).x).is_between(0.0, 1.0)  # 천천히
	assert_float(EnemyBrain.stand_off(to, to, 20.0, 40.0, 24.0).x).is_less(0.0)  # 너무 가까우면 물러남
	var side := EnemyBrain.stand_off(Vector2(1, 1).normalized(), to, 40.0, 40.0, 24.0)
	assert_float(side.y).is_greater(0.5)  # 옆걸음은 남아 둘레로 퍼진다
	assert_vector(EnemyBrain.stand_off(to, to, 20.0, 40.0, 0.0)).is_equal(to)  # band 0 = 끔


## 영웅에게 붙은 적은 영웅 그림 위로 파고들지 않지만, 접촉 피해 거리(감지 30 + 몸)는 안쪽이다.
func test_enemy_stops_near_player_but_inside_contact() -> void:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	add_child(p)
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.target = p
	var ai := Enemy.ai_data()
	var stop := e.body_radius + p.body_radius + ai.stand_off_margin
	assert_float(stop).is_less(30.0 + e.body_radius)  # 접촉 감지와 겹친다
	e.global_position = Vector2(stop - 6.0, 0)
	assert_float(e.compute_velocity([]).x).is_greater(0.0)  # 안쪽이면 바깥으로
	e.global_position = Vector2(300, 0)
	assert_float(e.compute_velocity([]).x).is_less(0.0)  # 멀면 다가온다


func test_every_hero_has_two_hit_layers_in_bank() -> void:
	var seen := {}
	for id in HEROES:
		var h: HeroData = load("res://data/heroes/%s.tres" % id)
		assert_int(h.hit_sfx.size()).is_equal(2)
		for k in h.hit_sfx:
			assert_bool(BANK.has(k)).is_true()
			assert_int(BANK.prio(k)).is_equal(BANK.prio(&"hit"))
			seen[k] = true
	assert_int(seen.size()).is_equal(8)  # 영웅마다 다른 재질
	assert_bool(BANK.has(&"confirm_big")).is_true()
	assert_bool(BANK.has(&"confirm_kill")).is_true()
	assert_int(BANK.prio(&"confirm_kill")).is_greater(BANK.prio(&"hit"))


func test_pick_avoids_immediate_repeat() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var prev: AudioStream = null
	for i in 40:
		var s := BANK.pick(&"hit", rng)
		assert_object(s).is_not_same(prev)
		prev = s


## 큰 타격은 몸통 + 영웅 재질 둘 + 확인음 + 국악 꽹과리 (공유마당 장구·꽹과리, tools/audio/cut_gugak.py).
func test_big_hit_layers_body_material_and_confirm() -> void:
	var f: Feedback = auto_free(Feedback.new())
	f.bank = BANK
	f.player = auto_free(Player.new())
	f.player.hero = load("res://data/heroes/gwanggaeto.tres")
	add_child(f)
	f._play_hit(f.feel.big_hit_damage)
	for k in [&"hit", &"mat_fire", &"mat_blunt", &"confirm_big"]:
		assert_bool(f._voices.kinds.has(k)).is_true()
	assert_bool(f._voices.kinds.has(&"gugak_big")).is_true()
	f._last_played.clear()
	f._voices = SfxVoices.new(f.sfx_voices)
	f._play_hit(5)
	assert_bool(f._voices.kinds.has(&"confirm_big")).is_false()
