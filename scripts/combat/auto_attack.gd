class_name AutoAttack
extends Node2D
## 자동 기본 공격 (영웅 공통). 수치는 BasicAttackData(영웅 데이터)에서 읽는다.
## - 근접: 사거리 안에 적이 있으면 가장 가까운 적 방향 부채꼴 베기.
## - 원거리: 근접 사거리 밖, 원거리 사거리 안의 가장 가까운 적에게 투사체 발사.
## 이동 중에도 계속 발동한다.

signal melee_swung(direction: Vector2, hits: int)
## 근접: 휘두르는 동작 시작 (피해는 melee_delay 뒤 칼이 닿을 때, PlayerView가 동작을 맞춘다).
signal melee_windup(direction: Vector2)
signal projectile_fired(projectile: Projectile)
## 원거리: 던지는 동작 시작 (손을 떠나기 전, PlayerView가 동작을 맞춘다).
signal ranged_windup(direction: Vector2)

@export var player: Player
## 비어 있으면 player.hero.attack, 그것도 없으면 기본값.
@export var data: BasicAttackData
@export var projectile_scene: PackedScene
## 투사체를 붙일 노드 (월드). 비어 있으면 플레이어의 부모.
@export var projectile_parent: Node

var _melee_cd: float = 0.0
var _ranged_cd: float = 0.0
var _glyph_i: int = 0
var _swing_dir: Vector2 = Vector2.DOWN
var _swing_time: float = 0.0
## 던지는 중인 탄: 손을 떠나기까지 남은 시간과 방향.
var _release_left: float = -1.0
var _release_dir: Vector2 = Vector2.ZERO
## 던지기 시작할 때의 수치 사본 (던지는 사이 성장이 같은 리소스를 바꿔도 이 탄은 그대로)과
## 그때의 데이터 (영웅이 바뀌어 data가 다른 것으로 바뀌면 던지지 않는다).
var _release_data: BasicAttackData
var _release_src: BasicAttackData
## 휘두르는 중: 칼이 닿기까지 남은 시간 (-1 = 없음)과 그때의 데이터 (바뀌면 버린다).
var _melee_left: float = -1.0
var _melee_src: BasicAttackData


func _ready() -> void:
	if data == null and player and player.hero:
		data = player.hero.attack
	if data == null:
		data = BasicAttackData.new()


## 사용 중인 수치 (테스트 등에서 _ready 전에 호출돼도 기본값을 준다).
func stats() -> BasicAttackData:
	if data == null:
		data = BasicAttackData.new()
	return data


func enemies() -> Array:
	return get_tree().get_nodes_in_group(Enemy.GROUP) if is_inside_tree() else []


## 공격 타이머 진행. 테스트에서 적 목록을 직접 넣을 수 있다.
func tick(delta: float, enemy_list: Array) -> void:
	_melee_cd = maxf(_melee_cd - delta, 0.0)
	_ranged_cd = maxf(_ranged_cd - delta, 0.0)
	_swing_time = maxf(_swing_time - delta, 0.0)
	if player == null:
		return
	if player.is_dead():  # 죽으면 손에 든 탄·휘두르던 칼은 버린다
		_release_left = -1.0
		_melee_left = -1.0
	if _melee_left >= 0.0:
		_melee_left -= delta
		if _melee_left < 0.0 and _melee_src == data:
			_strike(player.global_position, enemy_list)
		_release_data = null
		return
	if _release_left >= 0.0:
		_release_left -= delta
		if _release_left < 0.0:
			_release(enemy_list)
	var from := player.global_position
	var nearest := Targeting.nearest(enemy_list, from, stats().ranged_range)
	if nearest == null:
		return
	var to_nearest := nearest.global_position - from
	if to_nearest.length() <= stats().melee_range:
		if _melee_cd <= 0.0:
			_melee(from, to_nearest, enemy_list)
	elif _ranged_cd <= 0.0:
		_fire(from, to_nearest.normalized())


func _melee(from: Vector2, toward: Vector2, enemy_list: Array) -> void:
	var d := stats()
	_melee_cd = d.melee_interval
	_swing_dir = toward.normalized() if toward.length_squared() > 0.0001 else player.facing
	melee_windup.emit(_swing_dir)
	var delay := melee_delay()
	if delay > 0.0:
		_melee_left = delay
		_melee_src = data
		return
	_strike(from, enemy_list)


## 이 영웅의 근접 피해 지연 (데이터 또는 시트의 맞닿는 프레임).
func melee_delay() -> float:
	var d := stats()
	if d.melee_delay >= 0.0:
		return d.melee_delay
	var sheet := player.hero.sprite_sheet if player and player.hero else null
	var feel := Feedback.feel_data()
	if sheet == null or not sheet.has_anim("attack"):
		return feel.melee_delay_min
	var i := sheet.anim_names.find("attack")
	return AttackTiming.melee_delay(-1.0, sheet.strike_frame("attack"), sheet.fps[i], feel.melee_delay_min, feel.melee_delay_max)


## 칼이 닿는 순간: 그때 부채꼴 안의 적에게 피해·넉백.
func _strike(from: Vector2, enemy_list: Array) -> void:
	var d := stats()
	_swing_time = 0.12
	var hits := Targeting.in_arc(enemy_list, from, _swing_dir, d.melee_range, d.melee_arc_degrees)
	for e in hits:
		var h := e.get_node_or_null("Health") as Health
		if h:
			h.damage(d.melee_damage)
		if e is Enemy:  # 피격 반응: 살짝 밀려남
			(e as Enemy).apply_knockback((e.global_position - from).normalized() * d.melee_knockback)
	if not hits.is_empty() and d.melee_recoil > 0.0:  # 칼이 닿은 반동 (Hollow Knight식)
		player.apply_recoil(-_swing_dir * d.melee_recoil)
	melee_swung.emit(_swing_dir, hits.size())
	queue_redraw()


## 원거리: 던지는 동작을 시작하고 release_delay초 뒤 손에서 놓는다 (0이면 바로).
func _fire(from: Vector2, dir: Vector2) -> void:
	var d := stats()
	_ranged_cd = d.ranged_interval
	ranged_windup.emit(dir)
	if d.release_delay > 0.0:
		_release_left = d.release_delay
		_release_dir = dir
		_release_data = d.duplicate()
		_release_src = data
		return
	_spawn(from, dir, d)


## 손을 떠나는 순간: 가장 가까운 적으로 다시 겨눈다. 그사이 적이 다 사라졌으면 던지지 않는다.
func _release(enemy_list: Array) -> void:
	var d := _release_data
	_release_data = null
	if d == null or _release_src != data:  # 영웅·데이터가 바뀌었으면 손에 든 탄은 버린다
		return
	var from := player.global_position
	var nearest: Node2D = null
	var best := d.ranged_range * d.ranged_range
	for n in enemy_list:  # 막 죽어 아직 지워지기 전인 적은 겨누지 않는다 (Codex 88d3160)
		var node := n as Node2D
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		var h := node.get_node_or_null("Health") as Health
		if h and not h.is_alive():
			continue
		var d2 := from.distance_squared_to(node.global_position)
		if d2 <= best:
			best = d2
			nearest = node
	if nearest == null:
		return
	var to := nearest.global_position - from
	_spawn(from, to.normalized() if to.length_squared() > 1.0 else _release_dir, d)


func _spawn(from: Vector2, dir: Vector2, d: BasicAttackData) -> void:
	if projectile_scene == null:
		return
	var p := projectile_scene.instantiate() as Projectile
	p.direction = dir
	p.damage = d.ranged_damage
	p.speed = d.ranged_speed
	p.lifetime = d.ranged_lifetime
	p.knockback = d.ranged_knockback
	p.art = d.proj_art
	p.art_size = d.proj_size
	p.glyph_px = d.glyph_px
	p.trail_color = d.proj_trail_color
	p.trail_len = d.proj_trail_len
	if d.ranged_glyphs != "":
		p.glyph = d.ranged_glyphs[_glyph_i % d.ranged_glyphs.length()]
		_glyph_i += 1
	p.global_position = from + release_point(dir, d)  # 손·무기 끝에서
	var parent := projectile_parent if projectile_parent else player.get_parent()
	parent.add_child(p)
	projectile_fired.emit(p)


## 탄이 나가는 자리 (영웅 기준 오프셋): 시트에 무기 끝이 기록돼 있으면 던지는 동작의 맞닿는 프레임에서
## (T2, 방향마다 다름), 없으면 release_offset (앞으로 x, 위로 y).
func release_point(dir: Vector2, d: BasicAttackData) -> Vector2:
	var fallback := dir * d.release_offset.x + Vector2(0, -d.release_offset.y)
	var h := player.hero if player else null
	if h == null or h.sprite_sheet == null or d.ranged_anim == &"":
		return fallback
	var anim := String(d.ranged_anim)
	var sheet := h.sprite_sheet
	var px := sheet.tip(anim, sheet.dir_index(dir), sheet.strike_frame(anim))
	return AttackTiming.tip_offset(px, h.sprite_offset, Vector2.ONE * h.sprite_scale, fallback)


func _physics_process(delta: float) -> void:
	tick(delta, enemies())
	queue_redraw()


func _draw() -> void:
	if _swing_time <= 0.0:
		return
	var a := _swing_dir.angle()
	var half := deg_to_rad(stats().melee_arc_degrees * 0.5)
	var alpha := _swing_time / 0.12
	var art := Feedback.feel_data().crescent_art
	var col := stats().swing_color
	if art:  # 붓으로 그린 초승달 베기 (오른쪽 = 베는 방향)
		var r := stats().melee_range
		draw_set_transform(Vector2.ZERO, a, Vector2.ONE)
		draw_texture_rect(art, Rect2(r * 0.2, -r * sin(half) * 0.9, r * 0.95, r * sin(half) * 1.8), false,
			Color(col, col.a * alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_arc(Vector2.ZERO, stats().melee_range * 0.85, a - half, a + half, 20, Color(col, col.a * alpha), 10.0)
