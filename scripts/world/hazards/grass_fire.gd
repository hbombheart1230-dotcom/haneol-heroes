class_name GrassFire
extends Node2D
## 들불 (만주 벌판): 마른 풀 칸을 금빛 풀포기로 그려 두고, 불이 붙으면 칸마다 불꽃 혀가 일렁이며 이웃으로 번진다
## (번지기 전 연기). 불 위의 적·영웅은 tick마다 피해. 붙이기: 번개·유성 기술이 떨어진 자리 (ElementEvents),
## 박자마다 하늘에서 떨어지는 불씨 (예고 원 → 불). 끄기: 물결 기술의 자리와 날아가는 물결 탄의 길.
## 수치·그림·소리는 FireData, 칸 상태는 FireGrid, 불씨 박자는 HazardClock (숨 고르기·강화 고르기 중엔 멈춤).

var data: FireData
var host: StageHazards
var grid: FireGrid
var clock: HazardClock
## 불씨가 떨어질 칸 (예고 중), -1 = 없음.
var ember: int = -1
## 센 것 (시험·시뮬).
var ignited: int = 0
var doused: int = 0
var enemy_ticks: int = 0
var hero_ticks: int = 0
var embers: int = 0

var _tick_t: float = 0.0
var _t: float = 0.0
var _wet: Array[Node2D] = []


func _init(d: FireData) -> void:
	data = d
	grid = FireGrid.new(d)
	clock = HazardClock.new(d)
	add_to_group(StepGuard.GROUP)


## 연타 전진이 타는 칸 안으로 들어가지 않게 (StepGuard).
func step_danger_at(p: Vector2, _r: float) -> bool:
	return grid.burning_at(p)


func _ready() -> void:
	ElementEvents.listen(_on_element)
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	ElementEvents.unlisten(_on_element)
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func report() -> Dictionary:
	return {"fire_ignited": ignited, "fire_doused": doused, "fire_enemy_ticks": enemy_ticks, "fire_hero_ticks": hero_ticks,
		"fire_embers": embers}


func _on_node_added(n: Node) -> void:
	if n is Projectile:
		_wet.append(n)


func _on_element(element: StringName, pos: Vector2, radius: float) -> void:
	if data.ignite.has(element):
		_ignite(pos, maxf(radius, data.ignite_radius))
	elif data.douse.has(element):
		_douse(pos, maxf(radius, data.douse_radius))


func _ignite(pos: Vector2, r: float) -> void:
	var n := grid.ignite(pos, r)
	if n > 0:
		ignited += n
		_play(data.ignite_sfx)
		Feedback.vfx_burst(data.burn_vfx, pos, Vector2.UP, 1)
		queue_redraw()


func _douse(pos: Vector2, r: float) -> void:
	var n := grid.douse(pos, r)
	if n > 0:
		doused += n
		_play(data.douse_sfx)
		Feedback.vfx_burst(data.steam_vfx, pos, Vector2.UP)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_t += delta
	if host:
		match clock.step(delta, host.running(), host.boss()):
			HazardClock.Event.WARN:
				ember = _pick_ember()
			HazardClock.Event.STRIKE:
				if ember >= 0:
					embers += 1
					_ignite(grid.at[ember], data.ember_radius)
				ember = -1
	var spread := grid.step(delta)
	ignited += spread.size()
	_tick_wet()
	_tick_t += delta
	if _tick_t >= data.tick:
		_tick_t -= data.tick
		_burn_units()
	queue_redraw()


func _pick_ember() -> int:
	var pts := PackedVector2Array()
	for e in host.enemies():
		if e is Node2D and is_instance_valid(e):
			pts.append((e as Node2D).global_position)
	var hero := host.player.global_position if host.player else Vector2.ZERO
	return grid.pick_ember(host.view_rect(), hero, pts, data.ember_radius)


## 물결 탄이 지나가는 길의 불을 끈다.
func _tick_wet() -> void:
	for j in range(_wet.size() - 1, -1, -1):
		var p := _wet[j]
		if not is_instance_valid(p) or p.is_queued_for_deletion() or not p.is_inside_tree():
			_wet.remove_at(j)
			continue
		if data.douse.has(p.get_meta(&"element", &"")):
			var i := grid.cell_at(p.global_position)
			if i >= 0 and grid.state[i] != FireGrid.State.ASH:
				_douse(p.global_position, data.douse_radius * (p as Projectile).size_scale)


func _burn_units() -> void:
	if host == null:
		return
	for e in host.enemies():
		var en := e as Enemy
		if en and is_instance_valid(en) and en.health and en.health.is_alive() and grid.burning_at(en.global_position):
			enemy_ticks += 1
			en.health.damage(data.enemy_damage)
	var p := host.player
	if p and is_instance_valid(p) and not p.is_dead() and not p.is_invulnerable() and grid.burning_at(p.global_position):
		hero_ticks += 1
		p.health.damage(data.hero_damage)  # 작은 화상: 피격 무적·밀쳐내기 없이 (불 속에 서서 무적이 되지 않게)


func _play(kind: StringName) -> void:
	if kind != &"" and Feedback.instance:
		Feedback.instance.play(kind, 0.08)


## 칸 덩어리·풀잎·불꽃을 모아 한 번에 그린다 (모양·색은 Ink.blob·Ink.stroke 그대로).
var _batch := InkBatch.new()


func _draw() -> void:
	var view := host.view_rect().grow(data.cell) if host else Rect2(-1e6, -1e6, 2e6, 2e6)
	var c := data.cell
	for i in grid.size():
		var p := grid.at[i] + _jitter(i, c * 0.22)  # 칸마다 조금씩 비틀어 줄 맞춘 격자로 안 보이게
		if not view.has_point(p):
			continue
		match grid.state[i]:
			FireGrid.State.DRY:
				_batch.blob(p, c * 0.62, Color(data.dry_color, 0.16), i, 0.3, 0.6)
				_draw_dry(p, c, i)
				if grid.smoking(i):
					_batch.blob(p + Vector2(0, -c * 0.25 - fmod(_t * 30.0 + i * 7.0, 20.0)), c * 0.3, data.smoke_color, i)
			FireGrid.State.BURNING:
				_batch.blob(p, c * 0.75, Color(data.flame_color, 0.2), i, 0.3, 0.55)
				_draw_flames(p, c, i)
			FireGrid.State.ASH:
				_batch.blob(p, c * 0.58, data.ash_color, i, 0.3, 0.55)
	_batch.flush(self)  # 칸마다 그리기 호출이던 것을 한 번에 (InkBatch, 모양·색 그대로)
	if ember >= 0:
		_draw_ember(grid.at[ember])


## 칸 번호로 정해지는 작은 비틀기 (판마다 같다).
static func _jitter(i: int, amount: float) -> Vector2:
	return Vector2(sin(i * 12.9898) * 43758.5453, sin(i * 78.233) * 12543.123).posmod(1.0) * 2.0 * amount - Vector2.ONE * amount


func _draw_dry(p: Vector2, c: float, i: int) -> void:
	for k in 4:
		var base := p + Vector2((k - 1.5) * c * 0.24 + sin(i * 2.1 + k) * 8.0, cos(i * 1.3 + k) * c * 0.22)
		_batch.stroke(base, base + Vector2(-8.0 + k * 5.0, -c * (0.34 + 0.08 * sin(i + k))), 6.0, data.dry_color)


func _draw_flames(p: Vector2, c: float, i: int) -> void:
	var n := 2 + i % 3
	for k in n:
		var f := 0.7 + 0.3 * sin(_t * 9.0 + i * 1.7 + k * 2.1)
		var base := p + Vector2((k - (n - 1) * 0.5) * c * 0.3, c * (0.08 + 0.06 * sin(i + k)))
		var tip := base + Vector2(sin(_t * 6.0 + k + i) * 7.0, -c * (0.5 + 0.25 * ((i + k) % 3) * 0.5) * f)
		_batch.stroke(base, tip, c * 0.24, data.flame_color)
		_batch.stroke(base, base.lerp(tip, 0.55), c * 0.11, data.flame_core)


## 불씨 예고: 떨어질 자리에 줄어드는 고리 + 하늘에서 내려오는 불똥.
func _draw_ember(p: Vector2) -> void:
	var t := clock.warn_ratio()
	var r := data.ember_radius * (1.25 - 0.25 * t)
	var st := InkUiStyle.default()  # 반지름 r은 그대로: 붓 고리의 바깥이 r, 안쪽은 먹 번짐
	InkPaint.wash(self, p, r, Color(data.ember_color, (0.08 + 0.12 * t) * st.wash_alpha_mult))
	InkPaint.ring(self, p, r, Color(data.ember_color, (0.45 + 0.5 * t) * st.ring_alpha_mult))
	var drop := p + Vector2(0, -520.0 * (1.0 - t))
	Ink.blob(self, drop, 14.0, data.ember_color, 3.0)
	Ink.stroke(self, drop + Vector2(0, -60), drop, 10.0, Color(data.ember_color, 0.6))
