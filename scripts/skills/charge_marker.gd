class_name ChargeMarker
extends RefCounted
## 충전 표시 진행·그리기 (SkillCaster가 부른다). 영웅별 ChargeMarkerData, 없으면 공통 붓 고리.

var data: ChargeMarkerData
var _spark_cd: float = 0.0
var _was_full: bool = false
var _flash_left: float = 0.0
var _age: float = 0.0


func _init(p_data: ChargeMarkerData = null) -> void:
	data = p_data


## 매 프레임: charging = 모으는 중, c = 0~1. 입자·다 찬 순간 번쩍임을 낸다. 반환: 이번에 다 찼으면 true.
func tick(delta: float, charging: bool, c: float, pos: Vector2) -> bool:
	_age += delta
	_flash_left = maxf(_flash_left - delta, 0.0)
	if not charging:
		_was_full = false
		_spark_cd = 0.0
		return false
	var became_full := false
	if data:
		_spark_cd -= delta
		if data.spark_vfx and _spark_cd <= 0.0:
			_spark_cd = maxf(data.spark_interval, 0.02)
			Feedback.vfx_burst(data.spark_vfx, pos, Vector2.UP)
		if c >= 1.0 and not _was_full:
			became_full = true
			_flash_left = data.full_flash_time
			if data.full_vfx:
				Feedback.vfx_burst(data.full_vfx, pos, Vector2.UP)
	_was_full = c >= 1.0
	return became_full


## 바로 지운다 (죽었을 때: 번쩍임도 남기지 않음).
func cancel() -> void:
	_flash_left = 0.0
	_spark_cd = 0.0


## 영웅이 바뀌어 새로 만들 때 이어받기 (같은 충전으로 번쩍임이 두 번 나지 않게).
func carry_from(old: ChargeMarker) -> void:
	if old:
		_was_full = old._was_full
		_age = old._age


func flash_left() -> float:
	return _flash_left


func draw(canvas: CanvasItem, charging: bool, c: float) -> void:
	if not charging and _flash_left <= 0.0:
		return
	if data == null or data.art == null:
		_draw_default(canvas, c)
		return
	var k := 1.0 - _flash_left / maxf(data.full_flash_time, 0.001) if _flash_left > 0.0 else 1.0
	var flash := _flash_left > 0.0
	var size := lerpf(data.size_min, data.size_max, c) * (lerpf(data.full_flash_scale, 1.0, k) if flash else 1.0)
	var a := lerpf(data.alpha_min, data.alpha_max, c)
	var bright := lerpf(data.full_flash_bright, 1.0, k) if flash else 1.0
	_tex(canvas, data.art, size, _age * data.spin, Color(data.tint * bright, data.tint.a * a))
	if data.art2:
		_tex(canvas, data.art2, size * data.inner_scale, _age * data.spin2, Color(data.tint2 * bright, data.tint2.a * a))


func _tex(canvas: CanvasItem, tex: Texture2D, size: float, rot: float, col: Color) -> void:
	canvas.draw_set_transform(Vector2.ZERO, rot, Vector2.ONE)
	canvas.draw_texture_rect(tex, Rect2(-size * 0.5, -size * 0.5, size, size), false, col)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 영웅 표시가 없을 때: 공통 붓 고리 (그것도 없으면 먹선 호).
func _draw_default(canvas: CanvasItem, c: float) -> void:
	var art := Feedback.feel_data().ring_art
	if art:
		_tex(canvas, art, (36.0 + 20.0 * c) * 2.4, c * TAU, Color(0.4, 0.8, 1.0, 0.35 + 0.6 * c))
		return
	canvas.draw_arc(Vector2.ZERO, 36.0 + 20.0 * c, -PI / 2, -PI / 2 + TAU * maxf(c, 0.02), 32, Color(0.4, 0.8, 1.0, 0.9), 5.0)
