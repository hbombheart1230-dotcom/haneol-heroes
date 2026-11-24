class_name LaneStrike
extends Node2D
## 가로줄 공격 (한산 포격선): 예고 동안 줄이 붉게 차오르며 북이 울리고, 끝에 줄 위 모두를 친다 (적 enemy_damage,
## 영웅 hero_damage — 대시·피격 무적이면 영웅은 안 맞는다). 수치·그림·소리는 LaneStrikeData, 계산은 LanePlan.
## 세로 화면에서 가로줄은 위아래로 조금만 비키면 피할 수 있다. 줄이 화면 밖으로 나가면 화면 끝에 화살표.

var data: LaneStrikeData
var host: StageHazards
var clock: HazardClock
## 지금(또는 마지막) 줄 번호 (data.rows), -1 = 아직 없음.
var row: int = -1
## 마지막 포격에서 맞은 적 수, 영웅이 맞았는지 (시험·도구).
var last_enemy_hits: int = 0
var last_hero_hit: bool = false
var strikes: int = 0

var _beats := PackedFloat32Array()
var _beat_i: int = 0
var _beat_flash: float = 0.0
var _flash: float = 0.0


func _init(d: LaneStrikeData) -> void:
	data = d
	clock = HazardClock.new(d)
	_beats = LanePlan.beat_times(d.warn_time, d.beats)


func _physics_process(delta: float) -> void:
	if host == null or data.rows.is_empty():
		return
	match clock.step(delta, host.running(), host.boss()):
		HazardClock.Event.WARN:
			_begin_warn()
		HazardClock.Event.STRIKE:
			strike()
	if clock.warning():
		while _beat_i < _beats.size() and clock.warn_elapsed() >= _beats[_beat_i]:
			_beat_i += 1
			_beat_flash = 1.0
			_play(data.beat_sfx, 1.0 + 0.06 * (_beat_i - 1))
	_beat_flash = maxf(_beat_flash - delta * 5.0, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	if clock.warning() or _flash > 0.0 or _beat_flash > 0.0:
		queue_redraw()


func _begin_warn() -> void:
	var pts := PackedVector2Array()
	for e in host.enemies():
		if e is Node2D and is_instance_valid(e):
			pts.append((e as Node2D).global_position)
	var hero := host.player.global_position if host.player else Vector2.ZERO
	row = LanePlan.pick_row(data.rows, host.view_rect(), data.view_margin, hero, pts, data.half_width,
		row if data.avoid_repeat else -1)
	_beat_i = 0
	queue_redraw()


## 지금 줄에 포격 (예고 끝). 시험이 바로 부를 수도 있다.
func strike() -> void:
	last_enemy_hits = 0
	last_hero_hit = false
	if row < 0:
		return
	var r := data.rows[row]
	strikes += 1
	for e in host.enemies():
		var en := e as Enemy
		if en == null or not is_instance_valid(en) or en.health == null or not en.health.is_alive():
			continue
		if LanePlan.in_lane(r, data.half_width, en.global_position, en.body_radius * en.size_mult):
			last_enemy_hits += 1
			en.health.damage(data.enemy_damage)
			en.apply_knockback(LanePlan.push_dir(r.x, en.global_position) * data.enemy_push)
	var p := host.player
	if p and is_instance_valid(p) and LanePlan.in_lane(r, data.half_width, p.global_position, p.body_radius):
		last_hero_hit = p.apply_hit(data.hero_damage)
	_flash = data.flash_time
	_strike_fx(r)
	queue_redraw()


func _strike_fx(r: Vector3) -> void:
	var a := Vector2(r.y, r.x)
	var b := Vector2(r.z, r.x)
	_play(data.strike_sfx, data.strike_pitch)
	_play(data.strike_layer_sfx, 1.0)
	if Feedback.instance:
		Feedback.instance.add_trauma(data.shake, Vector2.UP)
	Feedback.vfx_burst(data.muzzle_vfx, a, Vector2.RIGHT, 1)
	Feedback.vfx_burst(data.muzzle_vfx, b, Vector2.LEFT, 1)
	if data.splinter_vfx and data.hit_spacing > 0.0:
		var view := host.view_rect().grow(60.0)
		var x := a.x + data.hit_spacing * 0.5
		while x < b.x:
			var at := Vector2(x, r.x)
			if view.has_point(at):
				Feedback.vfx_burst(data.splinter_vfx, at, Vector2.UP)
			x += data.hit_spacing


func _play(kind: StringName, pitch: float) -> void:
	if kind != &"" and Feedback.instance:
		Feedback.instance.play(kind, 0.05, pitch)


func _draw() -> void:
	if row < 0 or (not clock.warning() and _flash <= 0.0):
		return
	var r := data.rows[row]
	var hw := data.half_width
	var rect := Rect2(r.y, r.x - hw, r.z - r.y, hw * 2.0)
	if clock.warning():
		var t := clock.warn_ratio()
		var c := data.warn_color
		var wm := InkUiStyle.default().wash_alpha_mult  # 범위(rect)는 그대로, 안쪽만 먹 번짐
		InkPaint.wash_rect(self, rect, Color(c, lerpf(data.fill_alpha.x, data.fill_alpha.y, t) * wm * (1.0 + 0.5 * _beat_flash)))  # 박자마다 번짐이 짙어진다
		var half := rect.size.x * 0.5 * t  # 양 끝 대포에서 가운데로 차오른다
		var fill := Color(c, (data.fill_alpha.y + 0.1) * wm)
		InkPaint.wash_rect(self, Rect2(rect.position, Vector2(half, rect.size.y)), fill)
		InkPaint.wash_rect(self, Rect2(Vector2(rect.end.x - half, rect.position.y), Vector2(half, rect.size.y)), fill)
		var w := data.edge_width * (1.0 + 0.8 * _beat_flash)
		var edge := Color(c, 0.75 + 0.25 * _beat_flash)
		InkPaint.edge(self, rect.position.x, rect.end.x, rect.position.y, w * 2.4, edge)  # 위아래 경계: 거친 붓 획
		InkPaint.edge(self, rect.position.x, rect.end.x, rect.end.y, w * 2.4, edge)
		_draw_offscreen(r.x, c)
	if _flash > 0.0:
		var k := _flash / maxf(data.flash_time, 0.001)
		draw_rect(rect.grow_individual(0, -hw * (1.0 - k), 0, -hw * (1.0 - k)), Color(data.flash_color, data.flash_color.a * k))


## 줄이 화면 위·아래 밖이면 그쪽 화면 끝에 화살표 (영웅 x에).
func _draw_offscreen(y: float, c: Color) -> void:
	var view := host.view_rect()
	if y + data.half_width >= view.position.y and y - data.half_width <= view.end.y:
		return
	var up := y < view.position.y
	var x := clampf(host.player.global_position.x if host.player else view.get_center().x, view.position.x + 40, view.end.x - 40)
	var tip := Vector2(x, view.position.y + 24.0 if up else view.end.y - 24.0)
	var back := tip + (Vector2.DOWN if up else Vector2.UP) * 34.0
	draw_colored_polygon(PackedVector2Array([tip, back + Vector2(-26, 0), back + Vector2(26, 0)]), Color(c, 0.6 + 0.4 * _beat_flash))
