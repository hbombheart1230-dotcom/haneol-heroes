class_name AutoAttack
extends Node2D
## 이순신 자동 공격 (P0-B).
## - 근접: 사거리 안에 적이 있으면 바라보는(또는 가장 가까운 적) 방향 부채꼴 베기.
## - 원거리: 근접 사거리 밖, 원거리 사거리 안의 가장 가까운 적에게 검기 발사.
## 이동 중에도 계속 발동한다. 수치는 실험 값.

signal melee_swung(direction: Vector2, hits: int)
signal projectile_fired(projectile: Projectile)

@export var player: Player
@export var projectile_scene: PackedScene
## 투사체를 붙일 노드 (월드). 비어 있으면 플레이어의 부모.
@export var projectile_parent: Node

@export_group("Melee")
@export var melee_interval: float = 0.55
@export var melee_range: float = 110.0
@export var melee_arc_degrees: float = 140.0
@export var melee_damage: int = 12

@export_group("Ranged")
@export var ranged_interval: float = 0.8
@export var ranged_range: float = 480.0

var _melee_cd: float = 0.0
var _ranged_cd: float = 0.0
var _swing_dir: Vector2 = Vector2.DOWN
var _swing_time: float = 0.0


func enemies() -> Array:
	return get_tree().get_nodes_in_group(Enemy.GROUP) if is_inside_tree() else []


## 공격 타이머 진행. 테스트에서 적 목록을 직접 넣을 수 있다.
func tick(delta: float, enemy_list: Array) -> void:
	_melee_cd = maxf(_melee_cd - delta, 0.0)
	_ranged_cd = maxf(_ranged_cd - delta, 0.0)
	_swing_time = maxf(_swing_time - delta, 0.0)
	if player == null:
		return
	var from := player.global_position
	var nearest := Targeting.nearest(enemy_list, from, ranged_range)
	if nearest == null:
		return
	var to_nearest := nearest.global_position - from
	if to_nearest.length() <= melee_range:
		if _melee_cd <= 0.0:
			_melee(from, to_nearest, enemy_list)
	elif _ranged_cd <= 0.0:
		_fire(from, to_nearest.normalized())


func _melee(from: Vector2, toward: Vector2, enemy_list: Array) -> void:
	_melee_cd = melee_interval
	_swing_dir = toward.normalized() if toward.length_squared() > 0.0001 else player.facing
	_swing_time = 0.12
	var hits := Targeting.in_arc(enemy_list, from, _swing_dir, melee_range, melee_arc_degrees)
	for e in hits:
		var h := e.get_node_or_null("Health") as Health
		if h:
			h.damage(melee_damage)
	melee_swung.emit(_swing_dir, hits.size())
	queue_redraw()


func _fire(from: Vector2, dir: Vector2) -> void:
	_ranged_cd = ranged_interval
	if projectile_scene == null:
		return
	var p := projectile_scene.instantiate() as Projectile
	p.direction = dir
	p.global_position = from
	var parent := projectile_parent if projectile_parent else player.get_parent()
	parent.add_child(p)
	projectile_fired.emit(p)


func _physics_process(delta: float) -> void:
	tick(delta, enemies())
	queue_redraw()


func _draw() -> void:
	if _swing_time <= 0.0:
		return
	var a := _swing_dir.angle()
	var half := deg_to_rad(melee_arc_degrees * 0.5)
	var alpha := _swing_time / 0.12
	draw_arc(Vector2.ZERO, melee_range * 0.85, a - half, a + half, 20, Color(0.55, 0.85, 1.0, 0.8 * alpha), 10.0)
