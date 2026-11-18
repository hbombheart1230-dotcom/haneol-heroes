class_name SkillContext
extends RefCounted
## 기술이 세계와 상호작용하는 공통 도구 (대상 찾기, 피해, 투사체, 이펙트).
## 영웅별 기술은 이 도구만 사용해 노드 구조에 의존하지 않는다.

var player: Player
var world: Node
var fx: FxLayer
var projectile_scene: PackedScene
var enemy_source: Callable
var hit_stop_enabled: bool = true


## 히트스톱: 아주 짧게 게임 시간을 거의 멈춘다 (엔진 기본 time_scale + 실시간 타이머).
func hit_stop(duration: float, scale: float = 0.05) -> void:
	if not hit_stop_enabled or duration <= 0.0 or player == null or not player.is_inside_tree():
		return
	Engine.time_scale = scale
	var timer := player.get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(func() -> void: Engine.time_scale = 1.0)


func enemies() -> Array:
	return enemy_source.call() if enemy_source.is_valid() else []


func enemies_in_radius(center: Vector2, radius: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in enemies():
		var en := e as Enemy
		if en and is_instance_valid(en) and en.global_position.distance_to(center) <= radius:
			out.append(en)
	return out


func enemies_near_segment(a: Vector2, b: Vector2, half_width: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in enemies():
		var en := e as Enemy
		if en == null or not is_instance_valid(en):
			continue
		var p := Geometry2D.get_closest_point_to_segment(en.global_position, a, b)
		if p.distance_to(en.global_position) <= half_width:
			out.append(en)
	return out


## 살아 있는 적에게 피해. 반환: 실제로 맞았으면 true.
func hit(en: Enemy, dmg: int) -> bool:
	var h := en.get_node_or_null("Health") as Health
	if h == null or not h.is_alive():
		return false
	h.damage(dmg)
	if fx:
		fx.add_spark(en.global_position)
	return true


## 투사체 생성. configure는 트리에 들어가기 전(_ready 전)에 호출된다.
func spawn_projectile_configured(configure: Callable) -> Projectile:
	if projectile_scene == null:
		return null
	var p := projectile_scene.instantiate() as Projectile
	configure.call(p)
	p.global_position = player.global_position
	var parent := world if world else player.get_parent()
	parent.add_child(p)
	return p
