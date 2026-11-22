extends GdUnitTestSuite
## 영웅별 원거리 탄: 그림·자취, 손에서 던지기 (동작 프레임에 맞춰), 던지는 사이 죽음·영웅 바뀜·적 사라짐.

const HEROES := ["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"]


func after_test() -> void:
	Feedback.instance = null


func test_hero_ranged_art_and_release_from_hand() -> void:
	var proj := preload("res://scenes/projectile.tscn")
	for id in HEROES:
		var h: HeroData = load("res://data/heroes/%s.tres" % id)
		assert_float(h.attack.release_delay).override_failure_message(id).is_not_equal(0.0)  # 음수 = 시트 맞닿는 프레임
		assert_float(h.attack.proj_trail_len).is_greater(0.0)
		assert_bool(h.attack.proj_art != null or h.attack.ranged_glyphs != "").override_failure_message(id).is_true()
	var p: Player = auto_free(Player.new())
	add_child(p)
	p.global_position = Vector2.ZERO
	var a: AutoAttack = auto_free(AutoAttack.new())
	a.player = p
	a.projectile_scene = proj
	a.data = (load("res://data/heroes/gwanggaeto.tres") as HeroData).attack.duplicate()
	a.data.engage_mult = 1.0  # 던지기만 본다 (근접 우선 대기 없이)
	a.projectile_parent = self
	add_child(a)
	var fired: Array = []
	var wound: Array = []
	a.projectile_fired.connect(func(pr: Projectile) -> void: fired.append(pr))
	a.ranged_windup.connect(func(d: Vector2) -> void: wound.append(d))
	var target := Node2D.new()
	target.add_to_group(Enemy.GROUP)
	add_child(auto_free(target))
	target.global_position = Vector2((a.data.melee_range + a.data.ranged_range) * 0.5, 0)
	a.tick(0.016, [target])
	assert_int(wound.size()).is_equal(1)
	assert_int(fired.size()).is_equal(0)  # 아직 손에 있음
	for i in 12:
		a.tick(0.016, [target])
	assert_int(fired.size()).is_equal(1)
	var pr: Projectile = fired[0]
	assert_object(pr.art).is_same(a.data.proj_art)
	assert_float(pr.global_position.x).is_equal_approx(a.data.release_offset.x, 0.5)  # 손 앞에서 나간다
	assert_float(pr.global_position.y).is_equal_approx(-a.data.release_offset.y, 0.5)
	pr.queue_free()


func test_dead_player_drops_the_shot_in_hand() -> void:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	add_child(p)
	var a: AutoAttack = auto_free(AutoAttack.new())
	a.player = p
	a.projectile_scene = preload("res://scenes/projectile.tscn")
	a.data = (load("res://data/heroes/sejong.tres") as HeroData).attack.duplicate()
	a.data.engage_mult = 1.0  # 던지기만 본다 (근접 우선 대기 없이)
	a.projectile_parent = self
	add_child(a)
	var fired: Array = []
	a.projectile_fired.connect(func(pr: Projectile) -> void: fired.append(pr))
	var target := Node2D.new()
	add_child(auto_free(target))
	target.global_position = Vector2((a.data.melee_range + a.data.ranged_range) * 0.5, 0)
	a.tick(0.016, [target])  # 던지기 시작
	h.kill()
	for i in 20:
		a.tick(0.016, [target])
	assert_int(fired.size()).is_equal(0)


func test_release_reaims_and_keeps_windup_stats() -> void:
	var p: Player = auto_free(Player.new())
	add_child(p)
	var a: AutoAttack = auto_free(AutoAttack.new())
	a.player = p
	a.projectile_scene = preload("res://scenes/projectile.tscn")
	a.data = (load("res://data/heroes/gwanggaeto.tres") as HeroData).attack.duplicate()
	a.data.engage_mult = 1.0  # 던지기만 본다 (근접 우선 대기 없이)
	a.projectile_parent = self
	add_child(a)
	var fired: Array = []
	a.projectile_fired.connect(func(pr: Projectile) -> void: fired.append(pr))
	var mid := (a.data.melee_range + a.data.ranged_range) * 0.5
	var t1 := Node2D.new()
	add_child(auto_free(t1))
	t1.global_position = Vector2(mid, 0)
	a.tick(0.016, [t1])  # 오른쪽으로 던지기 시작
	var dmg := a.data.ranged_damage
	a.data.ranged_damage = dmg + 100  # 던지는 사이 성장 (RunBuild처럼 같은 리소스를 바꿈)
	var t2 := Node2D.new()
	add_child(auto_free(t2))
	t2.global_position = Vector2(0, mid)  # 첫 적은 사라지고 아래에 새 적
	for i in 12:
		a.tick(0.016, [t2])
	assert_int(fired.size()).is_equal(1)
	var pr: Projectile = fired[0]
	assert_float(pr.direction.y).is_greater(0.9)  # 다시 겨눔
	assert_int(pr.damage).is_equal(dmg)  # 던지기 시작할 때 수치
	pr.queue_free()
	# 적이 모두 사라지면 던지지 않는다
	a._ranged_cd = 0.0
	a.tick(0.016, [t2])
	for i in 12:
		a.tick(0.016, [])
	assert_int(fired.size()).is_equal(1)


func test_data_swap_during_windup_drops_the_shot() -> void:
	var p: Player = auto_free(Player.new())
	add_child(p)
	var a: AutoAttack = auto_free(AutoAttack.new())
	a.player = p
	a.projectile_scene = preload("res://scenes/projectile.tscn")
	a.data = (load("res://data/heroes/gwanggaeto.tres") as HeroData).attack.duplicate()
	a.data.engage_mult = 1.0  # 던지기만 본다 (근접 우선 대기 없이)
	a.projectile_parent = self
	add_child(a)
	var fired: Array = []
	a.projectile_fired.connect(func(pr: Projectile) -> void: fired.append(pr))
	var t := Node2D.new()
	add_child(auto_free(t))
	t.global_position = Vector2((a.data.melee_range + a.data.ranged_range) * 0.5, 0)
	a.tick(0.016, [t])
	a.data = (load("res://data/heroes/sejong.tres") as HeroData).attack.duplicate()  # 영웅 바뀜
	for i in 12:
		a.tick(0.016, [t])
	for pr in fired:
		assert_object((pr as Projectile).art).is_null()  # 광개토 창이 세종으로 날아가지 않음
		(pr as Projectile).queue_free()


func test_release_ignores_an_enemy_that_just_died() -> void:
	var p: Player = auto_free(Player.new())
	add_child(p)
	var a: AutoAttack = auto_free(AutoAttack.new())
	a.player = p
	a.projectile_scene = preload("res://scenes/projectile.tscn")
	a.data = (load("res://data/heroes/gwanggaeto.tres") as HeroData).attack.duplicate()
	a.data.engage_mult = 1.0  # 던지기만 본다 (근접 우선 대기 없이)
	a.projectile_parent = self
	add_child(a)
	var fired: Array = []
	a.projectile_fired.connect(func(pr: Projectile) -> void: fired.append(pr))
	var e: Enemy = preload("res://scenes/enemy.tscn").instantiate()
	add_child(auto_free(e))
	e.set_physics_process(false)
	e.global_position = Vector2((a.data.melee_range + a.data.ranged_range) * 0.5, 0)
	a.tick(0.016, [e])
	e.health.kill()  # 던지는 사이 죽음 (지워지기 전 같은 프레임)
	for i in 12:
		a.tick(0.016, [e])
	assert_int(fired.size()).is_equal(0)


func test_sejong_throws_with_the_new_clip() -> void:
	var sj: HeroData = load("res://data/heroes/sejong.tres")
	assert_str(String(sj.attack.ranged_anim)).is_equal("throw")
	assert_bool(sj.sprite_sheet.has_anim("throw")).is_true()
	var i := sj.sprite_sheet.anim_names.find("throw")
	var clip := sj.sprite_sheet.frame_counts[i] / sj.sprite_sheet.fps[i]
	assert_float(sj.attack.ranged_anim_time).is_equal_approx(clip, 0.02)
	assert_float(sj.attack.release_delay).is_less(clip)  # 동작 중간에 손을 떠난다
