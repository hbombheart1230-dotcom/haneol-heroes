class_name AllyHero
extends Node2D
## 불려 온 주인 영웅 (HomeSummonButton, 사용자 2026-11-26 "기술 한 방이 끝이라 짧다. 같이 싸우는 게 좋겠다"):
## 원정 온 영웅 옆에 나타나 HomeSummonData.ally_time초 동안 같이 싸우다 물러간다.
## 몸은 플레이어와 같은 부품을 그대로 쓴다 (Player·PlayerView(3D 자동)·Health·AutoAttack·SkillCaster — 새 전투 코드 없음),
## 손 대신 이 노드가 움직임·탭을 넣는다: 가장 가까운 적(우두머리 먼저)에 붙어 탭 연타 (4타 마무리 포함, TapChain 그대로),
## ally_skill_times초에 부르기 기술 (HomeSummonCast). 맞지 않고(무적, 접촉 감지 없음) 적의 겨냥 대상도 아니다 (적은 spawner.target만 본다).
## 이름 띠는 머리 위에 작게 (이 노드가 그린다).

const BODY_SCRIPT := preload("res://scripts/player/player.gd")
const VIEW_SCRIPT := preload("res://scripts/player/player_view.gd")

var data: HomeSummonData
var hero: HeroData
var body: Player
var caster: SkillCaster
var attack: AutoAttack
var rules: HomeSummonRules
var _left: float = 0.0
var _age: float = 0.0
var _tap_t: float = 0.0
var _skills_done: int = 0
var _runs: Array[SkillRun] = []
var _leaving := false
## 시뮬레이션(tests/ally_boss_sim.gd): 부품의 물리 틱을 끄고 step()으로 손으로 굴린다 (BossSim과 같은 판 시각).
var manual := false


## 주인 영웅을 main 옆에 세운다. main.player·FxLayer·투사체 장면을 빌린다. 만들었으면 그 노드.
static func spawn(main: Node, p_rules: HomeSummonRules) -> AllyHero:
	return spawn_into(main, main.player, p_rules)


## world 아래, me(고른 영웅) 옆에. p_manual이면 시뮬레이션이 step()으로 굴린다.
static func spawn_into(world: Node, me: Player, p_rules: HomeSummonRules, p_manual: bool = false) -> AllyHero:
	if me == null or p_rules == null or p_rules.home == null:
		return null
	var a := AllyHero.new()
	a.name = "AllyHero"
	a.rules = p_rules
	a.data = p_rules.data
	a.hero = p_rules.home
	a.manual = p_manual
	a._left = a.data.ally_time
	a.z_index = 30  # 이름 띠: 기술 그림 위
	world.add_child(a)
	a._build(world, me)
	if p_manual:
		for n: Node in [a, a.body, a.attack, a.caster]:
			n.set_physics_process(false)
	return a


func _build(main: Node, me: Player) -> void:
	var my_atk := me.get_node_or_null("AutoAttack") as AutoAttack
	var my_caster := me.get_node_or_null("SkillCaster") as SkillCaster
	body = BODY_SCRIPT.new()
	body.name = "Ally_%s" % hero.id
	body.collision_mask = me.collision_mask
	body.motion_mode = me.motion_mode
	body.arena_rect = me.arena_rect
	body.walk_area = me.walk_area  # 걸을 수 있는 곳 (#216)
	var shape := me.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		body.add_child(shape.duplicate())
	var view := Node2D.new()
	view.name = "PlayerView"
	view.set_script(VIEW_SCRIPT)  # Live3DSwitch가 3D로 바꾼다 (트리에 들어올 때)
	view.set("player", body)
	body.add_child(view)
	var h := Health.new()
	h.name = "Health"
	body.add_child(h)
	attack = AutoAttack.new()
	attack.name = "AutoAttack"
	attack.player = body
	attack.projectile_scene = my_atk.projectile_scene if my_atk else null
	attack.projectile_parent = main
	body.add_child(attack)
	caster = SkillCaster.new()
	caster.name = "SkillCaster"
	caster.player = body
	caster.projectile_scene = my_caster.projectile_scene if my_caster else null
	caster.world = main
	caster.fx = my_caster.fx if my_caster else null
	caster.hit_stop_enabled = false  # 판 전체를 멈추는 기술 멈춤은 고른 영웅 것만
	if my_caster:
		caster.enemy_source = my_caster.enemy_source
	body.add_child(caster)
	body.hero = hero  # 능력치·기술 묶음·그림 (Player가 AutoAttack·SkillCaster에 나눠 준다)
	body.global_position = me.global_position + data.ally_offset
	main.add_child(body)
	body.grant_invulnerability(data.ally_time + 1.0)
	_ink(body.global_position)


## 머리 위 이름 띠 위치 (월드).
func label_pos() -> Vector2:
	return body.global_position + Vector2(0, -data.ally_name_lift) if is_instance_valid(body) else global_position


func active() -> bool:
	return is_instance_valid(body) and not _leaving


func _physics_process(delta: float) -> void:
	_brain(delta)


## 시뮬레이션 한 틱: 머리 + 몸·평타·기술 (BossSim이 고른 영웅을 굴리는 순서와 같게).
func step(delta: float, t: float, list: Array) -> void:
	_brain(delta)
	if not active():
		return
	body._physics_process(delta)
	caster.tick(delta, t)
	attack.tick(delta, list)


func _brain(delta: float) -> void:
	if not is_instance_valid(body):
		queue_free()
		return
	for r in _runs.duplicate():
		if r.tick(delta):
			_runs.erase(r)
	_age += delta
	_left -= delta
	if _left <= 0.0:
		_leave()
		return
	body.grant_invulnerability(maxf(_left, 0.1))
	_skills(delta)
	_fight(delta)


## 가장 가까운 적에 붙어 연타. 사거리 안이면 서서 탭, 밖이면 걸어간다.
func _fight(delta: float) -> void:
	var foe := HomeSummonCast.target(caster._context())
	if foe == null:
		body.set_move_input(Vector2.ZERO)
		return
	var to := foe.global_position - body.global_position
	var reach := attack.stats().melee_range * data.ally_reach_mult if attack.stats().use_melee \
		else attack.stats().ranged_range * data.ally_reach_mult
	if to.length() > reach:
		body.set_move_input(to.normalized())
		return
	body.set_move_input(Vector2.ZERO)
	body.facing = to.normalized()
	_tap_t -= delta
	if _tap_t <= 0.0:
		_tap_t = data.ally_tap_gap
		caster.combo_tap()


## 부르기 기술: ally_skill_times초마다 한 번씩 (등장 때 0초 = 지금까지의 한 방).
func _skills(_delta: float) -> void:
	if _skills_done >= data.ally_skill_times.size() or _age < data.ally_skill_times[_skills_done]:
		return
	_skills_done += 1
	var foe := HomeSummonCast.target(caster._context())
	var k := rules.damage_scale_for(foe.data if foe else null) * data.ally_skill_scale
	var run := HomeSummonCast.cast(caster, hero, rules.skill(), data.charge, k)
	if run and not run.finished:
		_runs.append(run)


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	if is_instance_valid(body):
		_ink(body.global_position)
		body.queue_free()
	queue_free()


func _ink(at: Vector2) -> void:
	if Feedback.instance and Feedback.instance.kill_fx:
		Feedback.instance.kill_fx.death_burst(at, data.ally_ink_style, true)  # 먹 번짐 (나타남·물러감)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not active():
		return
	var p := label_pos() - global_position
	var a := clampf(minf(_age, _left) / 0.3, 0.0, 1.0)  # 나타날 때·물러갈 때 흐려짐
	UiStyle.text(self, UiStyle.TITLE_FONT, p + Vector2(-90, 0), hero.display_name, data.ally_name_px,
		Color(UiStyle.GOLD, a), 180.0, Color(UiStyle.INK, 0.85 * a), 5)
