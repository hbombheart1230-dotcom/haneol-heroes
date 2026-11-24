extends GdUnitTestSuite
## 영웅 승리 동작 (HeroVictory): 우두머리 처치 연출 뒤 → 승리 동작(1.5초 안쪽, 판 시각) → 결과(done).
## 그동안 조작 잠금. 동작·그림이 없으면(시뮬·시험) 바로 done.

const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]

var now_ms := 0


func before_test() -> void:
	now_ms = 5000
	GameTime.clock = func() -> int: return now_ms


func after_test() -> void:
	GameTime.clock = Callable()


func _player(hero: HeroData, with_view: bool) -> Player:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = hero
	add_child(p)
	p.set_physics_process(false)
	if with_view:
		var v := PlayerView.new()
		v.name = "PlayerView"
		v.player = p
		p.add_child(v)
		v.set_physics_process(false)
	return p


func _host() -> Node:
	var host: Node = auto_free(Node.new())
	add_child(host)
	var input := Node.new()
	input.name = "TouchController"
	host.add_child(input)
	return host


func test_every_hero_has_a_short_victory() -> void:
	for id in HEROES:
		var hero: HeroData = load("res://data/heroes/%s.tres" % id)
		assert_bool(hero.sprite_sheet.has_anim(HeroVictory.ANIM)).override_failure_message(id).is_true()
		assert_float(hero.victory_time).is_greater(0.0).is_less_equal(HeroVictory.MAX_TIME)


func test_victory_plays_then_finishes_on_game_clock() -> void:
	var p := _player(load("res://data/heroes/yi_sun_sin.tres"), true)
	var host := _host()
	var won := [false]
	var v := HeroVictory.play(host, p, func() -> void: won[0] = true)
	assert_object(v).is_not_null()
	assert_bool(won[0]).is_false()
	var view := p.get_node("PlayerView") as PlayerView
	assert_str(view.current_anim()).is_equal(HeroVictory.ANIM)
	var input := host.get_node("TouchController")
	assert_bool(input.is_processing_unhandled_input()).is_false()  # 조작 잠금
	assert_bool(input.is_physics_processing()).is_false()
	assert_float(p.skill_invuln_left()).is_greater(0.0)
	v._process(0.0)
	assert_bool(won[0]).is_false()
	now_ms += int(p.hero.victory_time * 1000.0) + 1
	v._process(0.0)
	assert_bool(won[0]).is_true()


func test_no_view_or_no_time_finishes_at_once() -> void:
	var won := [0]
	var count := func() -> void: won[0] += 1
	assert_object(HeroVictory.play(_host(), _player(load("res://data/heroes/yi_sun_sin.tres"), false), count)).is_null()
	var hero: HeroData = (load("res://data/heroes/sejong.tres") as HeroData).duplicate()
	hero.victory_time = 0.0
	assert_object(HeroVictory.play(_host(), _player(hero, true), count)).is_null()
	assert_object(HeroVictory.play(_host(), null, count)).is_null()
	assert_int(won[0]).is_equal(3)


func test_time_is_capped() -> void:
	var hero: HeroData = (load("res://data/heroes/gwanggaeto.tres") as HeroData).duplicate()
	hero.victory_time = 4.0
	assert_float(HeroVictory.time_for(_player(hero, true))).is_equal(HeroVictory.MAX_TIME)
