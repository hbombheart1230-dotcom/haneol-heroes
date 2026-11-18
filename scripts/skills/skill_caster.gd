class_name SkillCaster
extends Node2D
## 이순신 상황 반응형 단일 스킬 버튼 (무공 연계, P0-C).
##   대시 중 / 대시 직후 누름 → 파도격 (누르는 즉시 발동)
##   짧게 눌렀다 뗌            → 해룡참
##   길게 눌러 충전 후 뗌      → 해일검기 (이동하며 충전 가능)
## 수치는 모두 실험 값.

signal skill_cast(skill: Skill, hits: int)

enum Skill { NONE, HAERYONG, PADO, HAEIL }

const NAMES := {Skill.NONE: "", Skill.HAERYONG: "해룡참", Skill.PADO: "파도격", Skill.HAEIL: "해일검기"}

@export var player: Player
@export var projectile_scene: PackedScene
## 투사체·이펙트를 붙일 월드 노드. 비어 있으면 플레이어의 부모.
@export var world: Node
@export var fx: FxLayer

@export_group("해룡참")
@export var haeryong_cooldown: float = 4.0
@export var haeryong_radius: float = 170.0
@export var haeryong_damage: int = 25
@export var haeryong_knockback: float = 420.0

@export_group("파도격")
@export var pado_cooldown: float = 3.0
## 대시가 끝난 뒤에도 파도격으로 인정하는 시간(초).
@export var pado_link_window: float = 0.25
@export var pado_length: float = 320.0
@export var pado_width: float = 90.0
@export var pado_hits: int = 3
@export var pado_damage_per_hit: int = 10
@export var pado_hit_interval: float = 0.07

@export_group("해일검기")
@export var haeil_cooldown: float = 5.0
@export var haeil_min_damage: int = 20
@export var haeil_max_damage: int = 60
@export var haeil_min_scale: float = 1.6
@export var haeil_max_scale: float = 3.2
@export var haeil_speed: float = 650.0
@export var haeil_lifetime: float = 1.1

var input := SkillInput.new()
## 적 목록 공급자. 테스트에서 교체할 수 있다.
var enemy_source: Callable = func() -> Array: return get_tree().get_nodes_in_group(Enemy.GROUP)

var _cd := {Skill.HAERYONG: 0.0, Skill.PADO: 0.0, Skill.HAEIL: 0.0}
var _cd_max := {}
## 진행 중인 파도격 연타: {"left": 남은 타수, "timer": 다음 타까지, "a": 시작점, "b": 끝점}
var _pado: Dictionary = {}


func _ready() -> void:
	_cd_max = {Skill.HAERYONG: haeryong_cooldown, Skill.PADO: pado_cooldown, Skill.HAEIL: haeil_cooldown}


func is_ready(skill: Skill) -> bool:
	return float(_cd[skill]) <= 0.0


## 0~1, 남은 쿨타임 비율.
func cooldown_ratio(skill: Skill) -> float:
	var m := float(_cd_max.get(skill, 1.0))
	return clampf(float(_cd[skill]) / maxf(m, 0.001), 0.0, 1.0)


## 지금 버튼을 누르거나 떼면 발동할 기술 (버튼 표시용).
func preview_skill() -> Skill:
	if input.state == SkillInput.State.CHARGING:
		return Skill.HAEIL
	if player and player.in_dash_link(pado_link_window) and is_ready(Skill.PADO):
		return Skill.PADO
	return Skill.HAERYONG


## 반환: 이 터치를 스킬 손가락으로 받았으면 true.
func on_press(index: int, time: float) -> bool:
	if player == null or player.is_dead() or not input.press(index, time):
		return false
	if player.in_dash_link(pado_link_window) and is_ready(Skill.PADO):
		input.consume()
		cast_pado()
	return true


func on_release(index: int, time: float) -> Skill:
	var r := input.release(index, time)
	match r["kind"]:
		"tap":
			if is_ready(Skill.HAERYONG):
				cast_haeryong()
				return Skill.HAERYONG
		"charge":
			if is_ready(Skill.HAEIL):
				cast_haeil(float(r["charge"]))
				return Skill.HAEIL
	return Skill.NONE


func cancel_input() -> void:
	input.reset()


func tick(delta: float, time: float) -> void:
	for k in _cd.keys():
		_cd[k] = maxf(float(_cd[k]) - delta, 0.0)
	input.update(time)
	if not _pado.is_empty():
		_pado["timer"] = float(_pado["timer"]) - delta
		while not _pado.is_empty() and float(_pado["timer"]) <= 0.0:
			_pado_hit()


func _physics_process(delta: float) -> void:
	tick(delta, Time.get_ticks_usec() / 1_000_000.0)
	queue_redraw()


# --- 기술 ---

func cast_haeryong() -> int:
	_cd[Skill.HAERYONG] = haeryong_cooldown
	var center := player.global_position
	var hits := 0
	for e in enemy_source.call():
		var en := e as Enemy
		if en == null or not is_instance_valid(en):
			continue
		var off := en.global_position - center
		if off.length() > haeryong_radius:
			continue
		var dir := off.normalized() if off.length_squared() > 0.01 else Vector2.RIGHT
		en.apply_knockback(dir * haeryong_knockback)
		_hit(en, haeryong_damage)
		hits += 1
	if fx:
		fx.add_ring(center, haeryong_radius, 0.35, Color(0.35, 0.75, 1.0))
	skill_cast.emit(Skill.HAERYONG, hits)
	return hits


func cast_pado() -> void:
	_cd[Skill.PADO] = pado_cooldown
	var dir := player.get_dash_direction()
	if dir.length_squared() < 0.0001:
		dir = player.facing
	var a := player.global_position - dir * 30.0
	var b := player.global_position + dir * pado_length
	_pado = {"left": pado_hits, "timer": 0.0, "a": a, "b": b, "total": 0}
	if fx:
		fx.add_slash(a, b, pado_width * 0.5, 0.3, Color(0.4, 0.9, 1.0))
	_pado_hit()


func _pado_hit() -> void:
	var a: Vector2 = _pado["a"]
	var b: Vector2 = _pado["b"]
	var hits := 0
	for e in enemy_source.call():
		var en := e as Enemy
		if en == null or not is_instance_valid(en):
			continue
		var p := Geometry2D.get_closest_point_to_segment(en.global_position, a, b)
		if p.distance_to(en.global_position) <= pado_width * 0.5:
			_hit(en, pado_damage_per_hit)
			hits += 1
	_pado["total"] = int(_pado["total"]) + hits
	_pado["left"] = int(_pado["left"]) - 1
	_pado["timer"] = float(_pado["timer"]) + pado_hit_interval
	if fx and int(_pado["left"]) >= 0:
		var side := (b - a).orthogonal().normalized() * (12.0 * (int(_pado["left"]) - 1))
		fx.add_slash(a + side, b + side, 10.0, 0.18, Color(0.7, 0.95, 1.0))
	if int(_pado["left"]) <= 0:
		skill_cast.emit(Skill.PADO, int(_pado["total"]))
		_pado = {}


func cast_haeil(charge: float) -> Projectile:
	_cd[Skill.HAEIL] = haeil_cooldown
	if projectile_scene == null:
		return null
	var c := clampf(charge, 0.0, 1.0)
	var p := projectile_scene.instantiate() as Projectile
	p.direction = player.facing
	p.speed = haeil_speed
	p.lifetime = haeil_lifetime
	p.pierce = true
	p.wave_style = true
	p.damage = roundi(lerpf(haeil_min_damage, haeil_max_damage, c))
	p.size_scale = lerpf(haeil_min_scale, haeil_max_scale, c)
	p.global_position = player.global_position
	var parent := world if world else player.get_parent()
	parent.add_child(p)
	skill_cast.emit(Skill.HAEIL, 0)
	return p


func _hit(en: Enemy, dmg: int) -> void:
	var h := en.get_node_or_null("Health") as Health
	if h and h.is_alive():
		h.damage(dmg)
		if fx:
			fx.add_spark(en.global_position)


func _draw() -> void:
	# 충전 중 표시: 플레이어 발밑 물결 고리
	if input.state != SkillInput.State.CHARGING:
		return
	var c := input.charge_ratio(Time.get_ticks_usec() / 1_000_000.0)
	draw_arc(Vector2.ZERO, 36.0 + 20.0 * c, -PI / 2, -PI / 2 + TAU * maxf(c, 0.02), 32, Color(0.4, 0.8, 1.0, 0.9), 5.0)
