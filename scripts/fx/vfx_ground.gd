class_name VfxGround
extends Node2D
## 기술이 바닥에 남기는 먹 자국 (SkillVfxData.ground_*): 적·영웅 아래에 깔려 천천히 번져 사라진다.
## 이펙트 층(FxLayer, 위쪽 z) 아래에 붙지만 z를 절대값 0으로 두어, 바닥(Arena) 다음·적과 영웅 앞에 그린다.
## 그림은 무채색 웅덩이 붓 그림(CombatFeelData.pool_art)을 기술 색으로. 상한은 SkillStageFeel.max_ground.

var stage: SkillStageFeel
## {pos, rot, size, color, t, life}
var _items: Array[Dictionary] = []


func _init(p_stage: SkillStageFeel = null) -> void:
	stage = p_stage if p_stage else SkillStageFeel.get_default()
	z_as_relative = false
	z_index = 0  # 셰이더 없이 보통 투명도로 (옅은 먹 얼룩)


func count() -> int:
	return _items.size()


## size_k: 그림을 판정에 맞춰 줄이거나 키운 배율 (자국도 같이).
func mark(d: SkillVfxData, pos: Vector2, level: int, size_k: float = 1.0) -> void:
	if d == null or d.ground_time <= 0.0:
		return
	_items.append({"pos": pos, "rot": randf() * TAU, "size": d.ground_size * d.size_mult(level) * size_k,
		"color": d.ground_color if d.ground_art == null else Color(1, 1, 1, d.ground_color.a), "tex": d.ground_art,
		"t": 0.0, "life": d.ground_time})
	while _items.size() > maxi(stage.max_ground, 0):
		_items.pop_front()


func _process(delta: float) -> void:
	step(delta)
	queue_redraw()


func step(delta: float) -> void:
	var i := _items.size() - 1
	while i >= 0:
		_items[i]["t"] = float(_items[i]["t"]) + delta
		if float(_items[i]["t"]) >= float(_items[i]["life"]):
			_items.remove_at(i)
		i -= 1


func _draw() -> void:
	var pool := Feedback.feel_data().pool_art
	for it in _items:
		var tex: Texture2D = it["tex"] if it["tex"] != null else pool  # 그려 넣은 바닥 자국, 없으면 공용 웅덩이
		if tex == null:
			continue
		var t := float(it["t"])
		var k := t / float(it["life"])
		var appear := minf(t / maxf(stage.ground_fade_in, 0.001), 1.0)
		var s := float(it["size"]) * lerpf(0.55, 1.0, appear) * (1.0 + 0.12 * k)
		var c: Color = it["color"]
		draw_set_transform(it["pos"], float(it["rot"]), Vector2(1.0, 0.62))  # 바닥에 눕힌다
		draw_texture_rect(tex, Rect2(-Vector2.ONE * s * 0.5, Vector2.ONE * s), false,
			Color(c.r, c.g, c.b, c.a * (1.0 - k) * appear))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
