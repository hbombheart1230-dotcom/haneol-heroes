class_name StoneCover
extends Node2D
## 엄폐 (경복궁): 마당에 선 기둥·품계석이 곧게 날아가는 것을 막는다. 막을 때마다 먹선 금이 하나씩 늘고
## max_hits번에 깨진 그림으로 바뀌며 걸음 막는 원도 빠진다. 날아가는 것은 장면에 들어올 때(node_added) 붙잡아
## 둔다 — 적·영웅 파일을 건드리지 않는다. 수치·그림·소리는 CoverData, 상태 계산은 CoverState.

var data: CoverData
var host: StageHazards
var state: CoverState
## 지금까지 막은 수 (시험·시뮬): 적 탄 / 영웅 기술.
var blocked_enemy: int = 0
var blocked_hero: int = 0
var broken_count: int = 0

var _shots: Array[Node2D] = []
var _basic := {}


func _init(d: CoverData) -> void:
	data = d
	state = CoverState.new(d)


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	if host and host.obstacles:
		var list := host.obstacles.circles.duplicate()
		for i in state.at.size():
			list.append(state.circle(i))
		host.obstacles.build(list)
	var atk := _auto_attack()
	if atk:
		atk.projectile_fired.connect(func(p: Projectile) -> void: _basic[p.get_instance_id()] = true)
	queue_redraw()


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _auto_attack() -> AutoAttack:
	if host == null or host.player == null:
		return null
	for c in host.player.get_children():
		if c is AutoAttack:
			return c
	return null


func _on_node_added(n: Node) -> void:
	if (n is EnemyArrow and data.block_enemy_shots) or (n is Projectile and (data.block_hero_skills or data.block_hero_basic)):
		_shots.append(n)


func _physics_process(_delta: float) -> void:
	for j in range(_shots.size() - 1, -1, -1):
		var s := _shots[j]
		if not is_instance_valid(s) or s.is_queued_for_deletion() or not s.is_inside_tree():
			_shots.remove_at(j)
			continue
		var is_arrow := s is EnemyArrow
		if not is_arrow and not _blocks_projectile(s as Projectile):
			continue
		var r := (s as EnemyArrow).radius if is_arrow else 12.0 * (s as Projectile).size_scale
		var i := state.touching(s.global_position, r)
		if i < 0:
			continue
		_shots.remove_at(j)
		if is_arrow:
			blocked_enemy += 1
		else:
			blocked_hero += 1
		_hit(i, s.global_position)
		s.queue_free()


## 센 것 (시뮬 결과에 더한다).
func report() -> Dictionary:
	return {"cover_blocked_enemy": blocked_enemy, "cover_blocked_hero": blocked_hero, "cover_broken": broken_count}


func _blocks_projectile(p: Projectile) -> bool:
	var basic := _basic.has(p.get_instance_id())
	return data.block_hero_basic if basic else data.block_hero_skills


func _hit(i: int, at: Vector2) -> void:
	var broke := state.hit(i)
	Feedback.vfx_burst(data.dust_vfx, at, Vector2.UP, 1 if broke else 0)
	if Feedback.instance:
		Feedback.instance.play(data.break_sfx if broke else data.hit_sfx, 0.04, 0.8 if broke else data.hit_pitch)
	if broke:
		broken_count += 1
		if host and host.obstacles:
			host.obstacles.remove_circle(state.circle(i))
		Feedback.shake(data.shake_on_break)
	queue_redraw()


func _draw() -> void:
	for i in state.at.size():
		var k := int(data.pieces[i].z)
		var broke := state.is_broken(i)
		var texs := data.broken if broke else data.intact
		var tex: Texture2D = texs[k] if k < texs.size() else null
		var h := data.heights[k] if k < data.heights.size() else 160.0
		var foot := state.at[i] + Vector2(0, state.radius[i] * 0.45)
		if tex:
			var w := h * tex.get_width() / maxf(tex.get_height(), 1.0)
			draw_texture_rect(tex, Rect2(foot - Vector2(w * 0.5, h), Vector2(w, h)), false)
		elif broke:
			_draw_rubble(foot, state.radius[i], i)
		if not broke:
			_draw_cracks(foot, h, state.hits[i], i)


## 깨진 그림이 없는 종류: 바닥에 흩어진 돌 조각 (먹 얼룩 몇 개).
func _draw_rubble(foot: Vector2, r: float, seed_i: int) -> void:
	Ink.shadow(self, foot, r * 0.9)
	for c in 5:
		var off := Vector2.from_angle(seed_i * 1.7 + c * 1.26) * r * (0.25 + 0.12 * c)
		Ink.blob(self, foot + Vector2(off.x, off.y * 0.5 - 6.0), r * (0.32 - 0.03 * c), Color(0.62, 0.6, 0.56), seed_i + c)


## 맞은 수만큼 먹선 금 (엄폐마다 모양이 다르게 번호로 비튼다).
func _draw_cracks(foot: Vector2, h: float, n: int, seed_i: int) -> void:
	for c in n:
		var a := foot + Vector2((-0.18 + 0.2 * c) * h * 0.4, -h * (0.75 - 0.18 * c))
		var dir := Vector2.from_angle(1.2 + 0.7 * c + 0.4 * seed_i).normalized()
		var mid := a + dir * h * 0.16 + dir.orthogonal() * 6.0
		Ink.stroke(self, a, mid, data.crack_width, data.crack_color)
		Ink.stroke(self, mid, mid + dir.rotated(0.6) * h * 0.12, data.crack_width * 0.7, data.crack_color)
