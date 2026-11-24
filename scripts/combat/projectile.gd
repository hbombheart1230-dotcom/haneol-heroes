class_name Projectile
extends HitBox2D
## 검기 투사체. 자동 원거리 공격(단일 적중)과 해일검기(관통 대형 물결)에 함께 쓴다.
## 피해 적용은 HitBox2D(health_hitbox_hurtbox)가 HurtBox2D에 들어갈 때 처리한다.
## 관통 시 같은 적은 한 번만 맞는다 (영역 진입 시 1회 적용).

@export var speed: float = 700.0
@export var lifetime: float = 0.8
@export var damage: int = 10
## 적중 시 진행 방향으로 미는 힘 (0이면 없음).
@export var knockback: float = 0.0
## true면 적중 후에도 사라지지 않고 계속 관통한다.
@export var pierce: bool = false
## 크기 배율 (충돌 영역과 그림 모두).
@export var size_scale: float = 1.0
## true면 해일검기 물결 모양으로 그린다.
@export var wave_style: bool = false
## 비어 있지 않으면 이 글자를 붓글씨로 그린다 (세종 문자탄).
@export var glyph: String = ""
@export var glyph_px: int = 40
## 영웅별 탄 그림 (오른쪽 = 진행 방향)과 길이·두께(px). 비면 먹 획.
@export var art: Texture2D
@export var art_size: Vector2 = Vector2(96, 36)
## 뒤 자취 자취 색과 길이(px). 길이 0이면 없음.
@export var trail_color: Color = Color(0.3, 0.55, 0.9, 0.6)
@export var trail_len: float = 0.0
@export_group("물결 연출 (해일검기)")
## 그림 뒤에 끌리는 옅은 잔상 수와 간격(px). 0이면 없음.
@export var ghosts: int = 0
@export var ghost_gap: float = 30.0
## 나갈 때 앞으로 늘어났다 자리 잡는 시간(초)과 출렁임 세기 (0이면 그림 그대로).
@export var launch_stretch: float = 0.0
@export var surge: float = 0.0
## 날아가며 뒤로 흩뿌리는 물보라 (wake_interval초마다). 비면 없음.
@export var wake: SkillVfxData
@export var wake_interval: float = 0.06
## 0보다 크면 그림 속이 일렁인다 (수묵 그림 셰이더, 잔상은 먹으로 갉혀 옅어짐). 0이면 보통 그림.
@export var flicker: float = 0.0
## 물결 몸통의 물마루 겹 수 (해일검기 긁기): 앞선 날 뒤로 날이 줄지어 출렁이며 밀려온다. 0이면 한 장.
@export var blades: int = 0
## 겹 사이 간격 (그림 길이 대비).
@export var blade_gap: float = 0.42
## 뒤따르는 날의 길이 배율 (짧아야 날 사이 틈이 보인다).
@export var blade_len: float = 0.5
## 비어 있지 않으면 art 대신 이 프레임 시트를 되풀이 재생한다 (칸 수, 초당 장 수, 쓸 장 수 0 = 전부).
@export var art_sheet: Texture2D
@export var art_sheet_grid: Vector2i = Vector2i(4, 2)
@export var art_sheet_fps: float = 14.0
@export var art_sheet_count: int = 0

static var _flow_mat: ShaderMaterial

var direction: Vector2 = Vector2.RIGHT
var hits: int = 0
var _age: float = 0.0
var _wake_left: float = 0.0


func _ready() -> void:
	super._ready()
	var a: Array[HealthAction] = [HealthAction.new(Health.Affect.DAMAGE, HealthActionType.Enum.KINETIC, damage)]
	actions = a
	action_applied.connect(_on_action_applied)
	rotation = direction.angle()
	scale = Vector2.ONE * size_scale
	if art_sheet and art == null:
		art = art_sheet  # 그림 있음 표시 (실제로는 장마다 바꿔 그림)
	if flicker > 0.0 and art:
		material = flow_material()


## 일렁이는 물결용 수묵 셰이더 (VfxDecals와 같은 셰이더, 한 번만 만든다).
static func flow_material() -> ShaderMaterial:
	if _flow_mat == null:
		_flow_mat = ShaderMaterial.new()
		_flow_mat.shader = preload("res://shaders/ink_decal.gdshader")
		var noise := NoiseTexture2D.new()
		noise.noise = FastNoiseLite.new()
		noise.seamless = true
		_flow_mat.set_shader_parameter("noise_tex", noise)
		_flow_mat.set_shader_parameter("flicker_amp", 0.05)
		_flow_mat.set_shader_parameter("flicker_speed", Vector2(-0.6, 0.1))  # 물결이 뒤로 흘러간다
	return _flow_mat


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()
	if wake:
		_wake_left -= delta
		if _wake_left <= 0.0:
			_wake_left += wake_interval
			Feedback.vfx_burst(wake, global_position - direction * art_size.x * 0.4 * size_scale, -direction)
	if wave_style or ghosts > 0:
		queue_redraw()


func _on_action_applied(hurt_box: HurtBox2D) -> void:
	hits += 1
	if knockback > 0.0 and hurt_box and hurt_box.get_parent() is Enemy:
		(hurt_box.get_parent() as Enemy).apply_knockback(direction * knockback)
	if pierce:
		return
	ignore_collisions = true
	set_deferred("monitoring", false)
	queue_free()


## 나갈 때 앞으로 쭉 늘었다 자리 잡고, 날아가며 물마루가 출렁인다 (그림 한 장이 그대로 밀려 나가지 않게).
func _surge_scale() -> Vector2:
	var sx := 1.0
	if launch_stretch > 0.0 and _age < launch_stretch:
		var k := _age / launch_stretch
		sx = lerpf(0.45, 1.0, 1.0 - pow(1.0 - k, 3.0)) + 0.25 * sin(k * PI)
	var sy := 1.0 + surge * sin(_age * 17.0)
	return Vector2(sx - surge * 0.5 * sin(_age * 17.0), sy)


func _draw() -> void:
	if trail_len > 0.0:  # 뒤 자취: 뒤로 갈수록 가늘고 옅게
		var w := art_size.y * 0.45 if art else float(glyph_px) * 0.22  # 자모는 글자 칸 안에 작게 그려진다
		Ink.stroke(self, Vector2(-trail_len, 0), Vector2(-4, 0), w, trail_color)
	if art:
		var tex := art
		if art_sheet:
			var f := VfxSheets.frame_at(art_sheet, art_sheet_grid.x, art_sheet_grid.y, art_sheet_count, art_sheet_fps, _age, true)
			tex = f if f else tex
		var rect := Rect2(-art_size.x * 0.6, -art_size.y * 0.5, art_size.x, art_size.y)
		for g in range(ghosts, 0, -1):  # 잔상: 뒤로 갈수록 옅고 가늘게
			var f := 1.0 - float(g) / float(ghosts + 1)
			draw_set_transform(Vector2(-ghost_gap * g, 0.0), 0.0, Vector2(1.0, lerpf(0.6, 1.0, f)))
			var gc := Color(0.85, flicker, 0.0, lerpf(0.2, 0.75, f)) if flicker > 0.0 else Color(0.75, 0.9, 1.0, 0.45 * f * f)
			draw_texture_rect(tex, rect, false, gc)
		for b in range(blades, 0, -1):  # 뒤따르는 날: 저마다 다른 박자로 출렁이며 위아래로 엇갈린다
			var ph := sin(_age * 19.0 + b * 1.9)
			draw_set_transform(Vector2(-art_size.x * blade_gap * b, art_size.y * 0.14 * (1.0 if b % 2 else -1.0) * ph),
				0.0, Vector2(blade_len * (1.0 + 0.1 * ph), lerpf(0.95, 0.7, float(b) / float(blades + 1))))
			draw_texture_rect(tex, rect, false, Color(1.0, flicker, 0.0, lerpf(0.9, 0.55, float(b) / float(blades + 1)))
				if flicker > 0.0 else Color(1, 1, 1, 0.7))
		draw_set_transform(Vector2.ZERO, 0.0, _surge_scale())
		draw_texture_rect(tex, rect, false, Color(1.0, flicker, 0.0, 1.0) if flicker > 0.0 else Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if glyph != "":
		draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)  # 글자는 똑바로
		var g := float(glyph_px)
		UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(-g * 0.5, g * 0.35), glyph, glyph_px, UiStyle.GOLD, g,
			Color(0, 0, 0, 0.7), maxi(roundi(g / 8.0), 3))
		return
	if wave_style:
		var a := 1.0 - _age / lifetime * 0.5
		for i in 3:
			var r := 22.0 - i * 6.0
			draw_arc(Vector2(-i * 10.0, 0), r, -PI * 0.55, PI * 0.55, 16, Color(Ink.WATER.darkened(0.2 * i), a * (1.0 - i * 0.25)), 7.0 - i)
		return
	Ink.stroke(self, Vector2(-20, 0), Vector2(18, 0), 8.0, Ink.INDIGO)
	draw_line(Vector2(-8, 0), Vector2(14, 0), Ink.WATER, 2.0)
