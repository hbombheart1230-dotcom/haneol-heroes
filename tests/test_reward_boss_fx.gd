extends GdUnitTestSuite
## 보상 연출 (떨어질 때 빛기둥·먹을 때 터짐), 보스 등장 연출 (이름 띠·분위기), 네임드 이름표.


func _up(id: StringName) -> UpgradeDef:
	var u := UpgradeDef.new()
	u.id = id
	u.title = "해룡 강화"
	u.description = "해룡이 더 멀리\n둘째 줄"
	return u


func test_reward_fx_pickup_and_land_expire() -> void:
	var fx: RewardFx = auto_free(RewardFx.new())
	add_child(fx)
	fx.pickup(Vector2.ZERO, Color.GOLD, "해룡 강화", "해룡이 더 멀리")
	fx.land(Vector2(50, 0), Color.GOLD)
	assert_int(fx.count()).is_equal(2)
	fx.step(fx.land_time + 0.01)
	assert_int(fx.count()).is_equal(1)  # 착지는 끝나고 글자는 아직
	fx.step(fx.text_time)
	assert_int(fx.count()).is_equal(0)


func test_picking_a_card_bursts_with_its_title() -> void:
	var fx: RewardFx = auto_free(RewardFx.new())
	add_child(fx)
	var sc: SealChoice = auto_free(SealChoice.new())
	sc.reward_fx = fx
	add_child(sc)
	var ups: Array[UpgradeDef] = [_up(&"a"), _up(&"b"), _up(&"c")]
	sc.open(ups, Vector2.ZERO, false, {})
	assert_int(fx.count()).is_equal(0)
	sc.pick(1)
	assert_int(fx.count()).is_equal(1)
	assert_bool(get_tree().paused).is_false()

func test_potion_drop_and_drink_show_reward_fx() -> void:
	var fx: RewardFx = auto_free(RewardFx.new())
	add_child(fx)
	var f: BreakableField = auto_free(BreakableField.new())
	f.reward_fx = fx
	add_child(f)
	var d := BreakableData.new()
	d.count = 1
	d.drop_chance = 1.0
	f.setup(d, Rect2(-300, -300, 600, 600), 3)
	f.break_at(0)
	assert_int(fx.count()).is_equal(1)
	f._drink(0)
	assert_int(fx.count()).is_equal(2)


func test_boss_banner_blinks_red_then_returns_to_normal() -> void:
	var b: BossBanner = auto_free(BossBanner.new())
	add_child(b)
	var data := EnemyData.new()
	data.display_name = "거란 망령 부족장"
	data.is_boss = true
	var boss: Enemy = auto_free(preload("res://scenes/enemy.tscn").instantiate())
	boss.data = data
	add_child(boss)
	b.show_boss(boss)
	assert_bool(b.banner_visible()).is_true()
	var peak := b.pulse_time / (2.0 * b.pulses)  # 첫 깜박임 꼭대기
	b.step(peak)
	assert_float(b.mood).is_equal_approx(1.0, 0.01)
	b.step(peak)  # 첫 깜박임 끝: 다시 원래 색
	assert_float(b.mood).is_equal_approx(0.0, 0.01)
	b.step(b.pulse_time)  # 깜박임이 끝나면 보스가 살아 있어도 원래대로
	b.step(b.mood_fade)
	assert_float(b.mood).is_equal(0.0)
	assert_bool(b.banner_visible()).is_false()

func test_only_named_enemies_show_name() -> void:
	var e: Enemy = auto_free(Enemy.new())
	e.data = EnemyData.new()
	e.data.display_name = "거란 망령 졸병"
	assert_bool(EnemyNameTag.shows_name(e)).is_false()
	e.data.is_elite = true
	assert_bool(EnemyNameTag.shows_name(e)).is_true()
	e.data.is_elite = false
	e.data.is_boss = true
	assert_bool(EnemyNameTag.shows_name(e)).is_true()


func test_main_scene_wires_reward_and_boss_fx() -> void:
	var main: Node = auto_free(load("res://scenes/main.tscn").instantiate())
	var seal := main.get_node("SealChoice") as SealChoice
	var br := main.get_node("Breakables") as BreakableField
	var banner := main.get_node("HUD/BossBanner") as BossBanner
	assert_object(seal.reward_fx).is_not_null()
	assert_object(br.reward_fx).is_same(seal.reward_fx)
	assert_object(banner.spawner).is_same(main.get_node("EnemySpawner"))


func test_boss_banner_pauses_with_game() -> void:
	var b: BossBanner = auto_free(BossBanner.new())
	add_child(b)
	assert_int(b.process_mode).is_equal(Node.PROCESS_MODE_PAUSABLE)
