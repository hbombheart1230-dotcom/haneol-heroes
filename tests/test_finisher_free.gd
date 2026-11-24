extends GdUnitTestSuite
## 연타 마무리와 쿨타임 (사용자 2026-11-24 "해보자"): 순신·광개토는 1·2·3 뒤 넷째 탭이 늘 마무리 — 기술 단추 쿨타임을
## 쓰지도 기다리지도 않는다. 세종·사임당은 예전대로 (쿨타임 중이면 넷째 탭은 평타). 1·2타 뒤에는 어느 영웅도 마무리가 없다.
## 준비 표시 조건(TapChain.finisher_armed) = 실제로 마무리가 나가는 조건.

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const DT := 1.0 / 60.0
const FREE := ["yi_sun_sin", "gwanggaeto"]
const KEPT := ["sejong", "shin_saimdang"]

var player: Player
var caster: SkillCaster
var casts: Array = []
var now: float = 0.0


func after_test() -> void:
	for n in get_children():
		if n is Projectile or n is OrbitGlyphs or n is DamageZone:
			remove_child(n)
			n.free()


func _setup(id: String) -> void:
	var hero: HeroData = load("res://data/heroes/%s.tres" % id)
	casts = []
	now = 0.0
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	player.hero = hero
	var attack := AutoAttack.new()
	attack.name = "AutoAttack"
	attack.player = player
	attack.data = hero.attack.duplicate()
	attack.data.melee_delay = 0.0
	attack.data.release_delay = 0.0
	attack.projectile_scene = PROJECTILE_SCENE
	attack.projectile_parent = self
	player.add_child(attack)
	add_child(player)
	player.set_physics_process(false)
	attack.set_physics_process(false)
	caster = auto_free(SkillCaster.new())
	caster.player = player
	caster.kit = hero.kit
	caster.projectile_scene = PROJECTILE_SCENE
	caster.world = self
	caster.enemy_source = func() -> Array: return []
	caster.hit_stop_enabled = false
	add_child(caster)
	caster.set_physics_process(false)
	caster.skill_started.connect(func(s: SkillCaster.Slot, _d: SkillDef) -> void: casts.append(s))
	caster.auto_attack()


func _wait(seconds: float) -> void:
	for i in ceili(seconds / DT):
		now += DT
		caster.auto_attack().tick(DT, [])
		caster.tick(DT, now)


func _tap() -> void:
	caster.gesture_down(0, Vector2(100, 100), now)
	_wait(DT)
	caster.gesture_up(0, now)


## n타를 박자대로 잇는다 (마무리가 나가면 거기서 멈춤). 반환: 마무리가 나간 탭 번호 (없으면 0).
func _taps(n: int) -> int:
	for i in n:
		_tap()
		if casts.has(SkillCaster.Slot.TAP):
			return i + 1
		_wait(caster.tap_gap() + 0.15)
	return 0


func test_free_heroes_always_finish_on_the_fourth_tap() -> void:
	for id: String in FREE:
		_setup(id)
		assert_bool(caster.kit.combo_finisher_free).override_failure_message(id).is_true()
		caster._cd[SkillCaster.Slot.TAP] = 3.9  # 기술 단추로 막 썼다
		assert_int(_taps(2)).override_failure_message(id).is_equal(0)  # 1·2타 뒤엔 없음
		assert_bool(TapChain.finisher_armed(caster)).is_false()
		_taps(1)
		assert_bool(TapChain.finisher_armed(caster)).override_failure_message(id).is_true()  # 준비 표시 조건
		var cd_before := caster.cooldown_left(SkillCaster.Slot.TAP)
		assert_int(_taps(1)).override_failure_message(id).is_equal(1)  # 넷째 탭 = 마무리 (쿨타임 중인데도)
		assert_float(caster.cooldown_left(SkillCaster.Slot.TAP)).override_failure_message(id) \
			.is_equal_approx(cd_before, 0.05)  # 단추 쿨타임은 그대로 흐른다 (쓰지도 늘리지도 않음)
		assert_bool(caster.is_ready(SkillCaster.Slot.TAP)).is_false()  # 단추는 여전히 쿨타임
		assert_bool(TapChain.finisher_armed(caster)).is_false()


func test_free_finisher_comes_every_loop() -> void:
	_setup("yi_sun_sin")
	for loop in 3:
		assert_int(_taps(4)).override_failure_message("loop %d" % loop).is_equal(4)
		casts.clear()
		_wait(TapChain.recover(caster) + 0.05)


func test_kept_heroes_still_wait_for_the_cooldown() -> void:
	for id: String in KEPT:
		_setup(id)
		assert_bool(caster.kit.combo_finisher_free).override_failure_message(id).is_false()
		caster._cd[SkillCaster.Slot.TAP] = 30.0
		assert_int(_taps(4)).override_failure_message(id).is_equal(0)  # 넷째 탭은 평타
		caster._cd[SkillCaster.Slot.TAP] = 0.0
		_wait(caster.kit.combo_window + 0.1)  # 연타를 끊고 새로
		assert_int(_taps(3)).override_failure_message(id).is_equal(0)  # 1·2·3을 새로 (2·3타로는 안 나감)
		assert_bool(TapChain.finisher_armed(caster)).override_failure_message(id).is_true()
		assert_int(_taps(1)).override_failure_message(id).is_equal(1)
		assert_float(caster.cooldown_left(SkillCaster.Slot.TAP)).is_greater(0.0)  # 마무리가 쿨타임을 건다


## 준비 표시 조건이 실제 결과와 같다: 쿨타임을 따르는 영웅이 쿨타임 중이면 준비가 아니다.
func test_armed_is_false_while_a_kept_hero_waits() -> void:
	_setup("sejong")
	_taps(3)
	caster._cd[SkillCaster.Slot.TAP] = 5.0
	assert_bool(TapChain.finisher_armed(caster)).is_false()
	assert_int(_taps(1)).is_equal(0)


## 준비 표시(FinisherCue)는 finisher_armed와 같이 켜지고 꺼진다: 네 영웅, 쿨타임을 따르는 영웅은 쿨타임 중 꺼짐.
func test_ready_cue_follows_the_real_finisher_condition() -> void:
	for id: String in FREE + KEPT:
		_setup(id)
		var cue := caster.finisher_cue
		_taps(2)
		caster._physics_process(DT)
		assert_bool(cue.shown).override_failure_message(id + " 2타").is_false()
		_taps(1)
		caster._physics_process(DT)
		assert_bool(cue.shown).override_failure_message(id + " 3타").is_true()
		if KEPT.has(id):
			caster._cd[SkillCaster.Slot.TAP] = 5.0
			caster._physics_process(DT)
			assert_bool(cue.shown).override_failure_message(id + " 쿨타임").is_false()
			caster._cd[SkillCaster.Slot.TAP] = 0.0
			caster._physics_process(DT)
		assert_bool(cue.shown).is_equal(TapChain.finisher_armed(caster))
		_taps(1)  # 마무리
		caster._physics_process(DT)
		assert_bool(cue.shown).override_failure_message(id + " 마무리 뒤").is_false()
		_taps(3)
		_wait(caster.kit.combo_window + 0.1)  # 연타 끊김
		caster._physics_process(DT)
		assert_bool(cue.shown).override_failure_message(id + " 끊김").is_false()
