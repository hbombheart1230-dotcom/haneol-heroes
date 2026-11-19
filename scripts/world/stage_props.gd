class_name StageProps
extends Node2D
## 무대 바닥에 흩뿌리는 수묵 소품 (풀포기·바위). 이미지 없이 코드로 한 번만 그린다 (가볍다).
## 위치는 StageTheme.seed로 정해져 판마다 같다.

var theme: StageTheme
var rect: Rect2
## [위치, 종류(0 풀, 1 바위), 크기, 모양 씨앗]
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
	return out


func _draw() -> void:
	if theme == null:
		return
	for it in items:
		var p: Vector2 = it[0]
		var s: float = it[2]
		var sd: float = it[3]
		if it[1] == 0:
			_grass(p, s, sd)
		else:
			_rock(p, s, sd)


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
