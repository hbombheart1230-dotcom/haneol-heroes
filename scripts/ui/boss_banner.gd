class_name BossBanner
extends Control
## 보스 등장 연출: 화면 가운데 큰 이름 띠("적장 출현" + 보스 이름)가 잠깐 나오고,
## 보스가 살아 있는 동안 화면 가장자리가 붉게 어두워지고 무대도 어둡고 붉어진다 (CanvasModulate).
## 보스가 쓰러지면 천천히 원래대로. 음악 바뀜은 RunMusic(보스 → 후렴)이 따로 한다.

@export var spawner: EnemySpawner
## 이름 띠가 떠 있는 시간(초), 무대 분위기가 바뀌는 데 걸리는 시간(초).
@export var banner_time: float = 3.0
@export var mood_fade: float = 1.2
## 가장자리 어둠 진하기와 색, 무대 색조.
@export var vignette_alpha: float = 0.8
@export var vignette_color: Color = Color(0.28, 0.02, 0.02)
@export var world_tint: Color = Color(0.74, 0.56, 0.56)
@export var subtitle: String = "적장 출현"
@export var name_px: int = 78

var boss: Enemy
var mood: float = 0.0
var _t: float = INF
var _tint: CanvasModulate


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE  # 설정 화면 등으로 멈추면 같이 멈춘다 (HUD는 ALWAYS)
	if spawner:
		spawner.boss_spawned.connect(show_boss)


func show_boss(b: Enemy) -> void:
	boss = b
	_t = 0.0
	if Feedback.instance:
		Feedback.instance.add_trauma(0.8)
		Feedback.instance.haptic(120, 1.0)
		Feedback.instance.play(&"counter")


func banner_visible() -> bool:
	return _t < banner_time


func boss_alive() -> bool:
	return boss != null and is_instance_valid(boss) and boss.health != null and not boss.health.is_dead()


func step(delta: float) -> void:
	_t += delta
	mood = move_toward(mood, 1.0 if boss_alive() else 0.0, delta / maxf(mood_fade, 0.01))
	if mood > 0.0 or _tint:
		_apply_tint()


func _process(delta: float) -> void:
	step(delta / maxf(Engine.time_scale, 0.001))  # 실제 초: 고르기 슬로·타격 멈춤에 늘어지지 않게
	if mood > 0.0 or banner_visible():
		queue_redraw()


func _apply_tint() -> void:
	if _tint == null:
		var world := get_tree().current_scene if is_inside_tree() else null
		if world == null:
			return
		_tint = CanvasModulate.new()
		world.add_child(_tint)
	_tint.color = Color.WHITE.lerp(world_tint, mood)


func _exit_tree() -> void:
	if _tint and is_instance_valid(_tint):
		_tint.queue_free()


func _draw() -> void:
	var vp := size if size.x > 0.0 else get_viewport_rect().size
	if mood > 0.0:
		_draw_vignette(vp, vignette_alpha * mood)
	if banner_visible():
		_draw_banner(vp)


## 네 가장자리에서 안쪽으로 옅어지는 붉은 어둠.
func _draw_vignette(vp: Vector2, a: float) -> void:
	draw_edge_glow(self, vp, vignette_color, a)


## 화면 네 가장자리에서 안쪽으로 옅어지는 색 (영웅 피격 HurtVignette도 쓴다).
static func draw_edge_glow(ci: CanvasItem, vp: Vector2, color: Color, a: float, depth: float = 0.36) -> void:
	var d := minf(vp.x, vp.y) * depth
	var o := Color(color, a)
	var i := Color(color, 0.0)
	var quads := [
		[Vector2.ZERO, Vector2(vp.x, 0), Vector2(vp.x - d, d), Vector2(d, d)],
		[Vector2(0, vp.y), Vector2(d, vp.y - d), Vector2(vp.x - d, vp.y - d), vp],
		[Vector2.ZERO, Vector2(d, d), Vector2(d, vp.y - d), Vector2(0, vp.y)],
		[Vector2(vp.x, 0), vp, Vector2(vp.x - d, vp.y - d), Vector2(vp.x - d, d)],
	]
	for q in quads:
		var cols := PackedColorArray()
		for k in 4:
			var p: Vector2 = q[k]
			var outer := p.x <= 0.0 or p.y <= 0.0 or p.x >= vp.x or p.y >= vp.y
			cols.append(o if outer else i)
		ci.draw_polygon(PackedVector2Array(q), cols)


func _draw_banner(vp: Vector2) -> void:
	var k_in := clampf(_t / 0.3, 0.0, 1.0)
	var a := minf(k_in, clampf((banner_time - _t) / 0.5, 0.0, 1.0))
	var cy := vp.y * 0.34
	var band := Rect2(0, cy - 100, vp.x, 200)
	draw_rect(band, Color(0.05, 0.02, 0.02, 0.8 * a))
	var half := vp.x * 0.42 * (1.0 - pow(1.0 - k_in, 3.0))
	UiStyle.gold_rule(self, Vector2(vp.x * 0.5, band.position.y + 14), half, a)
	UiStyle.gold_rule(self, Vector2(vp.x * 0.5, band.end.y - 14), half, a)
	UiStyle.text(self, UiStyle.BODY_FONT, Vector2(0, cy - 44), subtitle, 32, Color(UiStyle.PAPER, a), vp.x,
		Color(0, 0, 0, 0.8 * a), 6)
	var name_text := boss.data.display_name if boss and is_instance_valid(boss) and boss.data else "적장"
	var pop := 1.0 + 0.35 * (1.0 - k_in)
	draw_set_transform(Vector2(vp.x * 0.5, cy + 46), 0.0, Vector2.ONE * pop)
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(-vp.x * 0.5, 0), name_text, name_px,
		Color(EnemyNameTag.BOSS_COLOR, a), vp.x, Color(0, 0, 0, 0.9 * a), 10)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
