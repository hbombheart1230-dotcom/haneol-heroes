class_name BossBanner
extends Control
## 보스 등장 연출: 화면 가운데 큰 이름 띠("적장 출현" + 보스 이름)가 잠깐 나오고,
## 등장하는 동안(pulse_time초) 화면 가장자리와 무대가 붉게 몇 번 깜박이다가 원래대로 돌아온다 (CanvasModulate).
## 음악 바뀜은 RunMusic(보스 → 후렴)이 따로 한다.

@export var spawner: EnemySpawner
## 이름 띠가 떠 있는 시간(초). 붉게 깜박이는 시간(초)과 횟수, 깜박임이 끝난 뒤 남은 붉음이 빠지는 시간(초).
@export var banner_time: float = 3.0
@export var pulse_time: float = 3.0
@export var pulses: int = 3
@export var mood_fade: float = 0.4
## 가장자리 어둠 진하기와 색, 무대 색조.
@export var vignette_alpha: float = 0.8
@export var vignette_color: Color = Color(0.28, 0.02, 0.02)
@export var world_tint: Color = Color(0.74, 0.56, 0.56)
@export var subtitle: String = "적장 출현"
@export var name_px: int = 78

var boss: Enemy
var mood: float = 0.0
var _t: float = INF
## 처치 띠 ("적장 격파", BossFeelData가 있는 보스만): 이름 띠를 다시 띄우되 붉게 깜박이지 않는다.
var defeated: bool = false
var _len: float = 3.0
## 띠 글자 (보스가 사라진 뒤에도 그리려고 들고 있는다).
var _sub: String = ""
var _name: String = "적장"
## 한꺼번에 나온 중간 우두머리 이름들 (띠에 한 줄씩). 첫 이름이 뜬 뒤 _collect초 안에 나온 이웃을 모은다.
var _names: PackedStringArray = PackedStringArray()
var _collect: float = 0.0
var _tint: CanvasModulate


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE  # 설정 화면 등으로 멈추면 같이 멈춘다 (HUD는 ALWAYS)
	if spawner:
		spawner.boss_spawned.connect(show_boss)
		spawner.elite_spawned.connect(func(e: Enemy) -> void:
			if not (e.data and e.data.boss_feel):
				return
			if _collect > 0.0:  # 같이 나온 이웃: 같은 띠에 이름만 더한다
				add_name(e)
			elif not boss_alive():  # 중간 보스 (무리면 처음 하나가 띠를 연다)
				show_boss(e)
				_collect = WaveBannerData.default().group_collect_time)


func show_boss(b: Enemy) -> void:
	boss = b
	_t = 0.0
	_len = banner_time
	defeated = false
	_sub = subtitle
	if b and b.data and b.data.boss_feel and b.data.boss_feel.intro_subtitle != "":
		_sub = b.data.boss_feel.intro_subtitle
	_name = b.data.display_name if b and b.data and b.data.display_name != "" else "적장"
	_names = PackedStringArray([_name])
	_collect = 0.0
	if b and b.data and b.data.boss_feel:
		b.killed.connect(_on_boss_killed.bind(b.data.boss_feel), CONNECT_ONE_SHOT)
	if Feedback.instance:
		Feedback.instance.add_trauma(0.8)
		Feedback.instance.haptic(120, 1.0)
		Feedback.instance.play(&"counter")


## 같은 띠에 이웃 이름 더하기 (이름이 없으면 적지 않는다).
func add_name(e: Enemy) -> void:
	if e and e.data and e.data.display_name != "" and not _names.has(e.data.display_name):
		_names.append(e.data.display_name)


## 처치 띠: 승리 화면이 뜨기 조금 전에 빠지게 (승리하면 멈춘 채 남지 않도록).
func _on_boss_killed(_e: Enemy, f: BossFeelData) -> void:
	defeated = true
	_t = 0.0
	_len = maxf(f.finale_time - 0.25, 0.8)
	_sub = f.finale_subtitle
	mood = 0.0


func banner_visible() -> bool:
	return _t < _len


func boss_alive() -> bool:
	return boss != null and is_instance_valid(boss) and boss.health != null and not boss.health.is_dead()


func step(delta: float) -> void:
	_t += delta
	_collect = maxf(_collect - delta, 0.0)
	if _t < pulse_time and boss_alive() and not defeated:  # 0 → 1 → 0을 pulses번 (깜박임)
		mood = 0.5 - 0.5 * cos(TAU * pulses * _t / maxf(pulse_time, 0.01))
	else:
		mood = move_toward(mood, 0.0, delta / maxf(mood_fade, 0.01))
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
	var a := minf(k_in, clampf((_len - _t) / 0.5, 0.0, 1.0))
	var cy := vp.y * 0.34
	var d := WaveBannerData.default()
	var lines := _names if not defeated and _names.size() > 1 else PackedStringArray([_name])
	var extra := (lines.size() - 1) * d.group_line_gap
	var px := name_px if lines.size() == 1 else d.group_name_px
	var band := Rect2(0, cy - 100, vp.x, 200 + extra)
	draw_rect(band, Color(0.05, 0.02, 0.02, 0.8 * a))
	var half := vp.x * 0.42 * (1.0 - pow(1.0 - k_in, 3.0))
	UiStyle.gold_rule(self, Vector2(vp.x * 0.5, band.position.y + 14), half, a)
	UiStyle.gold_rule(self, Vector2(vp.x * 0.5, band.end.y - 14), half, a)
	UiStyle.text(self, UiStyle.BODY_FONT, Vector2(0, cy - 44), _sub, 40 if defeated else 32, Color(UiStyle.PAPER, a), vp.x,
		Color(0, 0, 0, 0.8 * a), 6)
	var pop := 1.0 + 0.35 * (1.0 - k_in)
	draw_set_transform(Vector2(vp.x * 0.5, cy + 46), 0.0, Vector2.ONE * pop)
	for i in lines.size():
		var fit := fit_px(lines[i], px, vp.x - d.group_side_margin * 2.0)
		UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(-vp.x * 0.5, i * d.group_line_gap), lines[i], fit,
			Color(EnemyNameTag.BOSS_COLOR, a), vp.x, Color(0, 0, 0, 0.9 * a), 10)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 한 줄이 max_w 안에 들게 줄인 글자 크기 (붓글씨 제목 글꼴 기준; 긴 이름이 세로 화면 폭에서 잘리지 않게).
static func fit_px(text: String, px: int, max_w: float) -> int:
	var w := UiStyle.TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	return px if w <= max_w else maxi(int(floor(px * max_w / w)), 16)
