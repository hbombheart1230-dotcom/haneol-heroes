class_name StageProps
extends Node2D
## 무대 바닥에 흩뿌리는 수묵 소품 (풀포기·바위). 이미지 없이 코드로 한 번만 그린다 (가볍다).
## 위치는 StageTheme.seed로 정해져 판마다 같다.

var theme: StageTheme
var rect: Rect2
## [위치, 종류(0 풀, 1 바위, 2 그림), 크기(그림이면 배율), 모양 씨앗(그림이면 그림 번호)]
var items: Array = []


func setup(p_theme: StageTheme, p_rect: Rect2) -> void:
	theme = p_theme
	rect = p_rect
	items = scatter(theme, rect)
	queue_redraw()


## 순수 계산 (테스트용): 밀도에 맞춰 위치를 고르고 시작 지점 주변은 비운다.
static func scatter(t: StageTheme, r: Rect2) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = t.seed
	var area_m := r.get_area() / 1_000_000.0
	var out: Array = []
	for kind in 2:
		var n := roundi(area_m * (t.grass_per_mpx if kind == 0 else t.rock_per_mpx))
		for i in n:
			var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
			if p.length() < t.clear_radius:
				continue
			var size := rng.randf_range(24.0, 42.0) if kind == 0 else rng.randf_range(22.0, 48.0)
			out.append([p, kind, size, rng.randf() * 100.0])
	if not t.prop_textures.is_empty():
		var n := roundi(area_m * t.picture_props_per_mpx)
		var placed: Array[Vector2] = []
		for i in n * 3:  # 서로 너무 붙지 않게 몇 번 다시 뽑는다
			if placed.size() >= n:
				break
			var idx := rng.randi() % t.prop_textures.size()
			var sc := rng.randf_range(t.prop_scale_min, t.prop_scale_max)
			var size := t.prop_textures[idx].get_size() * sc
			# 그림 전체가 경기장 안에 들어가게 (아래 가운데 기준), 시작 지점 빈 원과도 겹치지 않게 (Codex 25dc72d)
			var p := Vector2(rng.randf_range(r.position.x + size.x * 0.5, r.end.x - size.x * 0.5),
				rng.randf_range(r.position.y + size.y * 0.92, r.end.y - size.y * 0.08))
			var box := picture_rect(p, size)
			var crowded := placed.any(func(q: Vector2) -> bool: return q.distance_to(p) < 220.0)
			if not r.encloses(box) or _rect_distance_to_origin(box) < t.clear_radius or crowded:
				continue
			placed.append(p)
			out.append([p, 2, sc, idx])
	out.sort_custom(func(x: Array, y: Array) -> bool: return (x[0] as Vector2).y < (y[0] as Vector2).y)  # 위에서 아래로
	return out


func _draw() -> void:
	if theme == null:
		return
	for it in items:
		var p: Vector2 = it[0]
		var s: float = it[2]
		var sd: float = it[3]
		match it[1]:
			0:
				_grass(p, s, sd)
			1:
				_rock(p, s, sd)
			_:
				_picture(p, s, int(sd))


## 그림 소품이 그려지는 영역 (아래 가운데 = p).
static func picture_rect(p: Vector2, size: Vector2) -> Rect2:
	return Rect2(p - Vector2(size.x * 0.5, size.y * 0.92), size)


static func _rect_distance_to_origin(box: Rect2) -> float:
	return Vector2.ZERO.clamp(box.position, box.end).length()


## 그림 소품: 아래 가운데를 바닥 위치에 맞추고 옅은 그림자를 깐다.
func _picture(p: Vector2, scale: float, index: int) -> void:
	var tex := theme.prop_textures[index]
	var size := tex.get_size() * scale
	Ink.shadow(self, p + Vector2(0, -4), size.x * 0.42)
	draw_texture_rect(tex, picture_rect(p, size), false)


func _grass(p: Vector2, s: float, sd: float) -> void:
	for k in 5:  # 바람에 누운 풀잎 다섯 획
		var a := -PI * 0.5 + (k - 2) * 0.32 + sin(sd + k) * 0.12
		var tip := p + Vector2.from_angle(a) * s * (0.7 + 0.3 * absf(sin(sd * 1.7 + k)))
		Ink.stroke(self, p, tip, 3.2, theme.grass_color)


func _rock(p: Vector2, s: float, sd: float) -> void:
	Ink.shadow(self, p + Vector2(0, s * 0.35), s * 0.9)
	Ink.blob(self, p, s * 0.55, theme.rock_color, sd, 0.18, 0.75)
	Ink.stroke(self, p + Vector2(-s * 0.3, -s * 0.1), p + Vector2(s * 0.15, -s * 0.3), 2.0,
		Color(theme.rock_color, theme.rock_color.a * 0.6))
