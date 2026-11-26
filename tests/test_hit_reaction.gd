extends GdUnitTestSuite
## 맞는 반응 (docs/research/game_feel_benchmark.md R1·R2·B1·A1): 구운 맞는 동작, 잡몹 경직, 그림 움찔, 흰 번쩍임, 가장자리 판정.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SOLDIER := preload("res://data/enemies/jurchen_soldier.tres")
const ELITE := preload("res://data/enemies/jurchen_elite_captain.tres")
const DT := 1.0 / 60.0


func after_test() -> void:
	Feedback.instance = null
	GameTime.reset()
	EnemyAttack.active_windups = 0


func _enemy(data: EnemyData = SOLDIER, pos: Vector2 = Vector2(60, 0)) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = data
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = pos
	return e


func _target(pos: Vector2 = Vector2.ZERO) -> Node2D:
	var t: Node2D = auto_free(Node2D.new())
	add_child(t)
	t.global_position = pos
	return t


func _react(tier: HitReaction.Tier) -> HitReaction:
	return HitReaction.new(load("res://data/feel/combat_feel.tres").reaction_data(), tier)


func test_trash_hit_plays_anim_and_staggers() -> void:
	var r := _react(HitReaction.Tier.TRASH)
	assert_bool(r.on_hit(5, 30, Vector2.RIGHT)).is_true()
	assert_bool(r.shows_hit_anim()).is_true()
	assert_bool(r.is_staggered()).is_true()
	r.tick(r.data.stagger_time + 0.01)
	assert_bool(r.is_staggered()).is_false()
	r.tick(r.data.hit_anim_time)
	assert_bool(r.shows_hit_anim()).is_false()
	assert_bool(r.on_hit(0, 30, Vector2.RIGHT)).is_false()  # 0 피해는 반응 없음


func test_elite_flinches_only_on_big_hits_and_boss_never() -> void:
	var r := _react(HitReaction.Tier.ELITE)
	assert_bool(r.on_hit(10, 600, Vector2.RIGHT)).is_false()  # 1/16 = 37.5 미만
	assert_bool(r.is_staggered()).is_false()  # 정예는 경직 없음
	assert_bool(r.on_hit(40, 600, Vector2.RIGHT)).is_true()
	var b := _react(HitReaction.Tier.BOSS)
	assert_bool(b.on_hit(500, 600, Vector2.RIGHT)).is_false()
	assert_bool(b.is_staggered()).is_false()
	assert_int(HitReaction.tier_of(SOLDIER, false)).is_equal(HitReaction.Tier.TRASH)
	assert_int(HitReaction.tier_of(SOLDIER, true)).is_equal(HitReaction.Tier.ELITE)
	assert_int(HitReaction.tier_of(ELITE, false)).is_equal(HitReaction.Tier.ELITE)


func test_flinch_squashes_leans_and_settles() -> void:
	var r := _react(HitReaction.Tier.TRASH)
	r.on_hit(5, 30, Vector2.RIGHT)
	assert_vector(r.squash_mult()).is_equal_approx(r.data.squash, Vector2(0.001, 0.001))
	assert_float(r.lean_offset().x).is_equal_approx(r.data.lean_px, 0.001)  # 맞은 방향(오른쪽)으로 젖힘
	assert_float(r.tilt()).is_greater(0.0)
	r.tick(maxf(r.data.squash_time, r.data.lean_time) + 0.01)
	assert_vector(r.squash_mult()).is_equal(Vector2.ONE)
	assert_vector(r.lean_offset()).is_equal(Vector2.ZERO)
	assert_float(r.tilt()).is_equal(0.0)
	var heavy := _react(HitReaction.Tier.ELITE)
	heavy.on_hit(1, 600, Vector2.LEFT)
	assert_float(absf(heavy.lean_offset().x)).is_less(r.data.lean_px)  # 정예는 작게
	assert_float(heavy.tilt()).is_less(0.0)


func test_shake_starts_big_and_fades_over_freeze() -> void:
	assert_float(HitReaction.shake_px(4.0, 0.05, 0.05)).is_equal_approx(4.0, 0.001)
	assert_float(HitReaction.shake_px(4.0, 0.025, 0.05)).is_equal_approx(2.0, 0.001)
	assert_float(HitReaction.shake_px(4.0, 0.0, 0.05)).is_equal(0.0)


func test_flash_amount_peaks_white_then_fades() -> void:
	var r := _react(HitReaction.Tier.TRASH)
	r.data = r.data.duplicate() as HitReactionData
	r.data.hit_flash_style = 0  # 흰 번쩍임 방식 (기본은 4 한지 실루엣: test_flash_styles)
	r.data.flash_blinks = 1  # 한 번 번쩍 방식 (예전)
	assert_float(r.flash_amount(0.08, 0.08, 0.03)).is_equal(r.data.flash_white)
	assert_float(r.flash_amount(0.025, 0.08, 0.03)).is_equal_approx(r.data.flash_white_tail * 0.5, 0.001)
	assert_float(r.flash_amount(0.0, 0.08, 0.03)).is_equal(0.0)


## 두 번 번쩍 (GDQuest juicy-attack): 0.15초를 켜짐 · 꺼짐 · 켜짐 세 칸으로.
func test_flash_blinks_twice() -> void:
	var r := _react(HitReaction.Tier.TRASH)
	r.data = r.data.duplicate() as HitReactionData
	r.data.hit_flash_style = 0  # 흰 번쩍임 방식
	assert_int(r.data.flash_blinks).is_equal(2)
	assert_float(r.flash_amount(0.15, 0.15, 0.05)).is_equal(r.data.flash_white)  # 첫 칸
	assert_float(r.flash_amount(0.075, 0.15, 0.05)).is_equal(0.0)  # 가운데 꺼짐
	assert_float(r.flash_amount(0.02, 0.15, 0.05)).is_equal(r.data.flash_white)  # 둘째 번쩍


## R1: 맞으면 구운 hit 동작 첫 프레임에서 멈춘 채 떨고, 멈춤 뒤 나머지 프레임이 이어진다 (예전: 첫 프레임만 스침).
func test_enemy_shows_baked_hit_anim_through_freeze() -> void:
	var e := _enemy()
	e.target = _target()
	e.health.damage(3)
	assert_str(String(e.sprite.animation).get_slice("_", 0)).is_equal("hit")
	assert_int(e.sprite.frame).is_equal(0)
	e._physics_process(DT)
	assert_float(e.sprite.speed_scale).is_equal(0.0)  # 멈춤 중 첫 프레임 고정
	assert_float(absf(e.sprite.position.x - e.data.sprite_offset.x * e.size_mult - e.reaction.lean_offset().x)).is_greater(0.5)  # 떨림
	for i in 6:
		e._physics_process(DT)
	assert_bool(e.is_frozen()).is_false()
	assert_str(String(e.sprite.animation).get_slice("_", 0)).is_equal("hit")  # 번쩍임이 끝나도 동작은 이어짐
	assert_float(e.sprite.speed_scale).is_equal(1.0)
	for i in int(e.reaction.data.hit_anim_time / DT) + 2:
		e._physics_process(DT)
	assert_str(String(e.sprite.animation).get_slice("_", 0)).is_not_equal("hit")


## B1: 잡몹은 경직 동안 쫓아오지 않아 넉백이 그대로 보인다.
func test_trash_stagger_lets_knockback_show() -> void:
	var e := _enemy(SOLDIER, Vector2(60, 0))
	e.target = _target(Vector2.ZERO)
	e.health.damage(3)
	e.apply_knockback(Vector2(100, 0))
	while e.is_frozen():
		e._physics_process(DT)
	e._physics_process(DT)
	assert_bool(e.reaction.is_staggered()).is_true()
	assert_float(e.velocity.x).is_greater(0.0)  # 넉백(바깥)만, 플레이어 쪽(왼쪽)으로 걷지 않음
	for i in int(e.reaction.stagger_time() / DT) + 2:  # 적별 경직 (잡몹 0.3초)
		e._physics_process(DT)
	assert_bool(e.reaction.is_staggered()).is_false()
	e.knockback = Vector2.ZERO
	e._physics_process(DT)
	assert_float(e.velocity.x).is_less(0.0)  # 다시 쫓아옴


## R2: 흰 번쩍임은 셰이더(적마다 재질 복제의 uniform)로 섞는다. 곱하기 밝기(2.6배)는 쓰지 않는다.
func test_white_flash_goes_through_shader() -> void:
	var e := _enemy()
	e.target = _target()
	e.health.damage(3)
	e._physics_process(DT)
	assert_object(e.sprite.material).is_not_null()
	assert_float(float(_param(e, &"flash"))).is_greater(0.5)
	assert_float(e.sprite.modulate.r).is_less_equal(1.0)
	for i in 12:
		e._physics_process(DT)
	assert_float(float(_param(e, &"flash"))).is_equal(0.0)


func test_shader_declares_flash_uniform() -> void:
	var code: String = load("res://shaders/enemy_rim.gdshader").code
	assert_str(code).contains("uniform float flash")
	assert_str(code).not_contains("instance uniform")  # 폰(Adreno 650)이 instance uniform vec4를 엉뚱하게 읽었다


## A1: 기술 판정에 적 몸 반경을 더한다 (그림 가장자리에 걸친 적도 맞음).
func test_skill_hits_on_enemy_edge() -> void:
	var e := _enemy(SOLDIER, Vector2(100 + e_radius(), 0))
	var ctx := SkillContext.new()
	ctx.enemy_source = func() -> Array: return [e]
	assert_int(ctx.enemies_in_radius(Vector2.ZERO, 100.0).size()).is_equal(1)
	assert_int(ctx.enemies_in_radius(Vector2.ZERO, 98.0).size()).is_equal(0)
	e.global_position = Vector2(50, 45 + e_radius() - 1.0)
	assert_int(ctx.enemies_near_segment(Vector2.ZERO, Vector2(200, 0), 45.0).size()).is_equal(1)
	e.global_position = Vector2(50, 45 + e_radius() + 2.0)
	assert_int(ctx.enemies_near_segment(Vector2.ZERO, Vector2(200, 0), 45.0).size()).is_equal(0)


func e_radius() -> float:
	return SOLDIER.body_radius * Feedback.feel_data().skill_edge_scale


func test_shove_staggers_trash_only() -> void:
	var t := _enemy(SOLDIER)
	t.shove(Vector2(100, 0))
	assert_bool(t.reaction.is_staggered()).is_true()
	assert_float(t.knockback.x).is_greater(0.0)
	var el := _enemy(ELITE)
	el.shove(Vector2(100, 0))
	assert_bool(el.reaction.is_staggered()).is_false()


## 경직 중에도 공격 예고는 흘러간다 (계속 맞아도 동시 예고 자리를 영원히 붙잡지 않음, Codex fa4d78c).
func test_stagger_does_not_hold_windup_slot() -> void:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	add_child(p)
	var e := _enemy(SOLDIER, Vector2(40, 0))
	e.target = p
	var was_busy := false
	var freed := false
	for i in 400:
		e.shove(Vector2(1, 0))  # 매 프레임 경직 갱신
		e._physics_process(DT)
		if e.attack.is_busy():
			was_busy = true
		elif was_busy:
			freed = true
			break
	assert_bool(was_busy).is_true()
	assert_bool(freed).is_true()
	assert_int(EnemyAttack.active_windups).is_equal(0)


## 돌진 중 잡몹이 맞으면 돌진이 멈춘다. 정예는 그대로 밀고 온다.
func test_trash_hit_stops_charge_but_elite_keeps_going() -> void:
	var t := _enemy(SOLDIER)
	t.target = _target()
	t._charge_to(Vector2(400, 0))
	assert_bool(t.is_charging()).is_true()
	t.health.damage(3)
	assert_bool(t.is_charging()).is_false()
	var el := _enemy(ELITE)
	el.target = _target()
	el._charge_to(Vector2(400, 0))
	el.health.damage(3)
	assert_bool(el.is_charging()).is_true()
	el.stun(1.0)
	assert_bool(el.is_charging()).is_false()


## 기본 4 (한지 실루엣 + 먹 테두리, 사용자 선택): 실제 적 셰이더에 맞은 첫 칸만 꽉 차고, 색·테두리가 한지·먹.
func test_default_hanji_silhouette_on_enemy() -> void:
	var e := _enemy()
	e.target = _target()
	e.health.damage(3)
	e._physics_process(DT)
	var rd := Feedback.feel_data().reaction_data()
	assert_int(rd.hit_flash_style).is_equal(4)
	assert_float(float(_param(e, &"flash"))).is_equal(1.0)
	assert_bool(Color(_param(e, &"flash_color")).is_equal_approx(rd.hanji_silhouette)).is_true()
	assert_bool(Color(_param(e, &"flash_rim")).is_equal_approx(rd.ink_rim)).is_true()
	for i in 12:
		e._physics_process(DT)
	assert_float(float(_param(e, &"flash"))).is_equal(0.0)


func _param(e: Enemy, key: StringName) -> Variant:
	return (e.sprite.material as ShaderMaterial).get_shader_parameter(key)


## 번쩍임은 적마다 다른 재질에 넣는다 (한 적이 번쩍여도 다른 적은 그대로).
func test_flash_is_per_enemy_material() -> void:
	var a := _enemy()
	var b := _enemy()
	a.target = _target()
	a.health.damage(3)
	a._physics_process(DT)
	b._physics_process(DT)
	assert_bool(a.sprite.material != b.sprite.material).is_true()
	assert_float(float(_param(a, &"flash"))).is_equal(1.0)
	assert_float(float(_param(b, &"flash"))).is_equal(0.0)
	for sh in ["res://shaders/enemy_rim.gdshader", "res://shaders/enemy_live.gdshader"]:
		assert_str((load(sh) as Shader).code).not_contains("instance uniform")
