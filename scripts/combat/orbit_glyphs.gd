class_name OrbitGlyphs
extends Node2D
## 몸 주위를 도는 글자 고리 (세종 정음진). 글자에 닿은 적은 같은 적마다 hit_interval초에 한 번 피해.
## 플레이어를 따라다닌다 (부모가 아니라 follow를 매 프레임 따라감: 월드에 붙여 히트스톱·정지와 같이 움직임).

var ctx: SkillContext
var follow: Node2D
var glyphs: String = "ㄱㄴㄷㅁㅅㅇ"
var radius: float = 110.0
var duration: float = 4.0
var damage: int = 10
var hit_interval: float = 0.5
var spin_speed: float = 3.2
## 글자 하나의 판정 반경(px).
var glyph_radius: float = 30.0
## 고리 밑에 깔리는 그림 (정음 자모 고리, 함께 돈다)과 크기 배율(반지름 대비)·투명도.
var art: Texture2D
var art_scale: float = 2.4
var art_alpha: float = 0.55

var hits: int = 0
var _age: float = 0.0
var _last_hit: Dictionary = {}


func glyph_positions() -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := maxi(glyphs.length(), 1)
	for i in n:
		out.append(global_position + Vector2.from_angle(_age * spin_speed + TAU * i / n) * radius)
	return out


func _physics_process(delta: float) -> void:
	_age += delta
	if follow and is_instance_valid(follow):
		global_position = follow.global_position
	if ctx:
		var now := _age
		for p in glyph_positions():
			for en in ctx.enemies_in_radius(p, glyph_radius):
				if not en.health.is_alive():
					continue
				var id := en.get_instance_id()
				if now - float(_last_hit.get(id, -INF)) < hit_interval:
					continue
				_last_hit[id] = now
				if ctx.hit(en, damage, false):
					hits += 1
	if _age >= duration:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var fade := clampf((duration - _age) / 0.4, 0.0, 1.0)
	if art:
		var s := radius * art_scale
		draw_set_transform(Vector2.ZERO, _age * spin_speed * 0.5, Vector2.ONE)
		draw_texture_rect(art, Rect2(-s * 0.5, -s * 0.5, s, s), false, Color(1, 1, 1, art_alpha * fade))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(UiStyle.GOLD, 0.25 * fade), 2.0)
	var n := maxi(glyphs.length(), 1)
	for i in n:
		var p := Vector2.from_angle(_age * spin_speed + TAU * i / n) * radius
		UiStyle.text(self, UiStyle.TITLE_FONT, p + Vector2(-22, 16), glyphs[i], 46, Color(UiStyle.GOLD, fade), 44.0,
			Color(0, 0, 0, 0.7 * fade), 5)
