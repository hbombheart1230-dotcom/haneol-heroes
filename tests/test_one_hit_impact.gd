extends GdUnitTestSuite
## 한 타 충격 (사용자: "평타와 연타 스킬 1번의 타격감이 너무 없는데"): 닿는 자리 섬광 층, 타별 넉백(1·2타 약 35px),
## 퍽 소리 음높이·진동, 해룡참 휘감기 끝 한 번 멈춤. 밀림이 커져도 연타가 헛치지 않는지 실제 노드로 확인.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const YI := preload("res://data/heroes/yi_sun_sin.tres")
const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")
const DT := 1.0 / 60.0

var player: Player
var atk: AutoAttack
var caster: SkillCaster
var enemies: Array = []


func before_test() -> void:
	EnemyAttack.active_windups = 0
	enemies = []
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	player.hero = YI
	add_child(player)
	player.set_physics_process(false)
	atk = auto_free(AutoAttack.new())
	atk.name = "AutoAttack"
	atk.player = player
	atk.data = YI.attack
	atk.projectile_scene = PROJECTILE_SCENE
	atk.projectile_parent = self
	player.add_child(atk)
	atk.set_physics_process(false)
	caster = auto_free(SkillCaster.new())
	caster.player = player
	caster.kit = YI.kit
	caster.projectile_scene = PROJECTILE_SCENE
	caster.world = self
	caster.enemy_source = func() -> Array: return enemies
	add_child(caster)
	caster.set_physics_process(false)


func after_test() -> void:
	EnemyAttack.active_windups = 0
	GameTime.reset()
	SkillHitStop.reset()


## 1·2타는 거의 안 밀림 (약 15px, 움찔 위주 — 3타에 크게 날리면 넷째 탭 기술이 허공을 쳐서), 3타는 넘어짐 (약 35px).
func test_step_knockback_distances() -> void:
	var d := YI.attack
	var damping := 8.0
	var d1 := d.melee_knockback * ComboSteps.at(d.step_knockback_mults, 1, 1.0) / damping
	var d3 := d.melee_knockback * d.heavy_knockback_mult * ComboSteps.at(d.step_knockback_mults, 3, 1.0) / damping
	assert_float(d1).is_between(12.0, 18.0)
	assert_float(d3).is_equal_approx(140.0 * 2.0 / damping, 0.01)  # 예전 3타와 같음


## 밀림이 커져도 연타가 헛치지 않는다: 1·2타가 맞은 뒤 이어지는 2·3타가 (전진으로 따라가) 닿는다.
func test_tapping_one_soldier_keeps_connecting() -> void:
	var r: Array = await _tap_soldier(YI.attack)
	print("[reach] new knockback: follow-up hits %d, connected %d" % r)
	assert_int(r[0]).is_greater_equal(3)
	assert_float(float(r[1]) / r[0]).is_greater_equal(0.9)  # 밀려도 다음 타가 닿는다 (전진이 밀림을 따라간다)


func test_reach_baseline_old_knockback() -> void:
	var old := YI.attack.duplicate() as BasicAttackData
	old.step_knockback_mults = PackedFloat32Array([1.0, 1.0, 1.0])
	old.step_in_px = PackedFloat32Array([10.0, 14.0, 26.0])
	old.step_in_max = 30.0
	old.step_range_mults = PackedFloat32Array([1.0, 1.0, 1.2])
	var r: Array = await _tap_soldier(old)
	print("[reach] old knockback: follow-up hits %d, connected %d" % r)
	assert_int(r[0]).is_greater_equal(3)
	assert_float(float(r[1]) / r[0]).is_greater_equal(0.75)  # 기준선: 예전 값도 이어지는 타가 닿는다


## 병사 하나 (안 죽게, 공격 안 함)에게 0.35초마다 1 → 2 → 3타를 차례로 (마무리 기술 없이, 밀림·전진만 본다).
## [앞 타가 맞은 뒤 이어진 2·3타 수, 그중 닿은 수]
func _tap_soldier(d: BasicAttackData) -> Array:
	Engine.time_scale = 1.0
	await get_tree().physics_frame  # 물리 프레임 안에서 고정 DT로 (move_and_slide가 밖에서는 실제 프레임 delta를 쓴다)
	seed(11)
	atk.data = d
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = SOLDIER
	e.target = player
	e.ai_seed = 1
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = Vector2(75, 0)
	e.health.max = 100000
	e.health.current = 100000
	enemies.append(e)
	var res := [0, 0]
	var prev := false
	var t := 0.0
	var tap_t := 0.0
	var step := 0
	while t < 12.0:
		t += DT
		tap_t -= DT
		player._physics_process(DT)
		e.attack._cooldown = 99.0  # 밀림·전진만 보려고 병사는 치지 않게
		if tap_t <= 0.0 and atk.can_manual(0.2):
			tap_t = 0.35
			step = step % 3 + 1
			player.facing = (e.global_position - player.global_position).normalized()
			var before := e.health.current
			atk.manual_strike(step, false, enemies)
			for k in 20:  # 칼이 닿을 때까지 (melee_delay + 3타 모으기 0.08초)
				t += DT
				player._physics_process(DT)
				atk.tick(DT, enemies)
				e._physics_process(DT)
			var hit := e.health.current < before
			if prev and step >= 2:
				res[0] += 1
				res[1] += int(hit)
			prev = hit and step < 3
		atk.tick(DT, enemies)
		e._physics_process(DT)
	return res


## 충격 층: 상한 수만큼 돌려 쓰고, 시간이 지나면 사라진다.
func test_impact_layer_pools_and_expires() -> void:
	var d := HitImpactData.new()
	d.max_active = 4
	var l: HitImpactLayer = auto_free(HitImpactLayer.new(d))
	add_child(l)
	for i in 10:
		l.add(Vector2.ZERO, Vector2.RIGHT, 1 + i % 3, Color.CYAN)
	assert_int(l.active_count()).is_equal(4)
	l._process(d.duration + 0.01)
	assert_int(l.active_count()).is_equal(0)


## 타마다 커지고 (1 → 3), 소리 음높이는 올라간다.
func test_impact_grows_and_pitch_rises_by_step() -> void:
	var d: HitImpactData = load("res://data/feel/hit_impact.tres")
	for arr in [d.core_radius, d.streak_length, d.pitch]:
		assert_float(HitImpactData.at_f(arr, 1, 0.0)).is_less(HitImpactData.at_f(arr, 3, 0.0))
	assert_int(HitImpactData.at_i(d.haptic_ms, 3, 0)).is_greater(HitImpactData.at_i(d.haptic_ms, 1, 0))
	assert_int(HitImpactData.at_i(d.streak_count, 1, 0)).is_greater_equal(4)


## 해룡참 휘감기: 적마다 멈추지 않고 (SkillHitStop 미룸), 끝날 때 한 번.
func test_haeryong_sweep_defers_stop_to_the_end() -> void:
	for i in 3:
		var e: Enemy = ENEMY_SCENE.instantiate()
		e.data = SOLDIER
		add_child(auto_free(e))
		e.set_physics_process(false)
		e.global_position = Vector2.from_angle(TAU * i / 3.0) * 80.0
		e.health.max = 1000
		e.health.current = 1000
		enemies.append(e)
	SkillHitStop.reset()
	var run := caster.cast(SkillCaster.Slot.TAP)
	assert_object(run).is_instanceof(SweepRun)
	assert_int(SkillHitStop._count).is_equal(0)  # 시작 방향의 적도 멈춤을 미룬다
	var t := 0.0
	while not run.finished and t < 1.0:
		t += DT
		caster.tick(DT, t)
		assert_int(SkillHitStop._count).is_equal(0)
	assert_bool(run.finished).is_true()
	assert_int(run.hits).is_equal(3)
	assert_bool(GameTime.is_stopped()).is_true()  # 마지막 한 번
