class_name BreakableField
extends Node2D
## 무대에 흩어진 부서지는 물건: 대시로 뚫거나 근접 공격이 닿으면 깨지고, 확률로 탕약(체력 회복)이 떨어진다.
## 깨진 물건은 respawn_time 뒤 다른 곳에 다시 생긴다. 수치는 BreakableData (무대마다 StageTheme.breakable).

signal broken(pos: Vector2, dropped: bool)
signal potion_taken(pos: Vector2, healed: int)

@export var player: Player
@export var fx: FxLayer
## 근접 공격이 물건도 깨게 (부채꼴 안).
@export var auto_attack: AutoAttack

var data: BreakableData
var area: Rect2
## 놓인 물건 위치, 깨진 뒤 다시 생길 때까지 남은 시간들, 바닥의 탕약 {pos, age}.
var jars: PackedVector2Array = PackedVector2Array()
var respawns: PackedFloat32Array = PackedFloat32Array()
var potions: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var _t: float = 0.0


func _ready() -> void:
	if auto_attack:
		auto_attack.melee_swung.connect(_on_melee_swung)


## 무대를 열 때: 물건을 새로 놓는다. data가 없으면 비운다.
func setup(d: BreakableData, r: Rect2, seed_value: int = 0) -> void:
	data = d
	area = r
	rng.seed = seed_value
	jars = PackedVector2Array()
	respawns = PackedFloat32Array()
	potions.clear()
	if d:
		for i in d.count:
			_place()
	queue_redraw()


## 빈자리 고르기: 영역 안, 시작 원 밖, 다른 물건·영웅과 min_gap 이상. 30번 안에 못 찾으면 가장 덜 붐비는 곳.
static func pick_spot(r: RandomNumberGenerator, rect: Rect2, avoid: PackedVector2Array, gap: float, clear: float) -> Vector2:
	var best := rect.get_center()
	var best_d := -1.0
	for i in 30:
		var p := Vector2(r.randf_range(rect.position.x, rect.end.x), r.randf_range(rect.position.y, rect.end.y))
		if p.length() < clear:
			continue
		var d := INF
		for q in avoid:
			d = minf(d, p.distance_to(q))
		if d >= gap:
			return p
		if d > best_d:
			best_d = d
			best = p
	return best


func _place() -> void:
	var avoid := jars.duplicate()
	if player:
		avoid.append(player.global_position)
	jars.append(pick_spot(rng, area, avoid, data.min_gap, data.clear_radius))


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if data == null:
		return
	_t += delta
	for i in range(respawns.size() - 1, -1, -1):
		respawns[i] -= delta
		if respawns[i] <= 0.0:
			respawns.remove_at(i)
			_place()
	if player and player.is_dashing():
		for i in range(jars.size() - 1, -1, -1):
			if jars[i].distance_to(player.global_position) <= data.radius + 24.0:
				break_at(i)
	for i in range(potions.size() - 1, -1, -1):
		potions[i].age += delta
		if player and (potions[i].pos as Vector2).distance_to(player.global_position) <= data.pickup_radius:
			_drink(i)
		elif potions[i].age >= data.potion_lifetime:
			potions.remove_at(i)
	queue_redraw()


func _on_melee_swung(direction: Vector2, _hits: int) -> void:
	if data == null or player == null or auto_attack == null:
		return
	var s := auto_attack.stats()
	var half := deg_to_rad(s.melee_arc_degrees) * 0.5
	for i in range(jars.size() - 1, -1, -1):
		var to := jars[i] - player.global_position
		if to.length() <= s.melee_range + data.radius and absf(direction.angle_to(to)) <= half:
			break_at(i)


func break_at(i: int) -> void:
	var p := jars[i]
	jars.remove_at(i)
	respawns.append(data.respawn_time)
	var dropped := rng.randf() < data.drop_chance
	if dropped:
		potions.append({"pos": p, "age": 0.0})
	if fx:
		fx.add_ring(p, data.radius * 2.0, 0.3, Ink.INK)
		fx.add_spark(p, Ink.PAPER)
	if Feedback.instance:
		Feedback.instance.play(&"hit")
	broken.emit(p, dropped)


func _drink(i: int) -> void:
	var p: Vector2 = potions[i].pos
	potions.remove_at(i)
	var healed := 0
	if player and player.health:
		healed = ceili(player.health.max * data.heal_fraction)
		player.health.heal(healed)
	if fx:
		fx.add_ring(p, 70.0, 0.4, Color(0.45, 0.8, 0.45))
	if Feedback.instance:
		Feedback.instance.play(&"magic")
	potion_taken.emit(p, healed)


func _draw() -> void:
	if data == null:
		return
	if data.texture:
		var ts := data.texture.get_size()
		var size := Vector2(ts.x / ts.y * data.display_height, data.display_height)
		var glint := 0.6 + 0.3 * sin(_t * 3.0)
		for p in jars:  # 발밑 금빛 먹 고리: 깰 수 있는 물건 표시
			draw_set_transform(p, 0.0, Vector2(1.0, 0.4))
			draw_arc(Vector2.ZERO, data.radius * 1.2, 0.0, TAU, 40, Color(Ink.GOLD, glint), 5.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_texture_rect(data.texture, StageProps.picture_rect(p, size), false)
	for pot in potions:
		_draw_potion(pot.pos, pot.age)


## 탕약 사발: 흰 사발에 검붉은 약, 김 두 줄, 초록 빛무리. 사라지기 3초 전부터 깜빡인다.
const POTION_SCALE := 1.5


func _draw_potion(p: Vector2, age: float) -> void:
	var left := data.potion_lifetime - age
	if left < 3.0 and fmod(left, 0.4) < 0.15:
		return
	draw_set_transform(p, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2(0, 30), 26.0 * POTION_SCALE, Color(0, 0, 0, 0.2))
	draw_circle(Vector2.ZERO, (40.0 + sin(_t * 4.0) * 5.0) * POTION_SCALE, Color(0.55, 0.9, 0.5, 0.28))
	var base := Transform2D(0.0, Vector2.ONE * POTION_SCALE, 0.0, p + Vector2(0, sin(_t * 3.0 + p.x) * 4.0))
	draw_set_transform_matrix(base)
	var bowl := Color(0.95, 0.94, 0.88)
	draw_colored_polygon(PackedVector2Array([Vector2(-20, -2), Vector2(20, -2), Vector2(12, 14), Vector2(-12, 14)]), bowl)
	draw_polyline(PackedVector2Array([Vector2(-20, -2), Vector2(-12, 14), Vector2(12, 14), Vector2(20, -2)]), Ink.INK, 2.0)
	draw_set_transform_matrix(base * Transform2D(0.0, Vector2(1.0, 0.35), 0.0, Vector2(0, -2)))
	draw_circle(Vector2.ZERO, 20.0, bowl)
	draw_circle(Vector2.ZERO, 16.0, Color(0.35, 0.12, 0.06))
	draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, Ink.INK, 2.0)
	draw_set_transform_matrix(base)
	for k in 2:
		var x := -6.0 + k * 12.0
		var w := sin(_t * 2.0 + k) * 4.0
		Ink.stroke(self, Vector2(x, -10), Vector2(x + w, -32), 3.0, Color(1, 1, 1, 0.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
