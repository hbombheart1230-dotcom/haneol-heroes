class_name ChargeMarker
extends RefCounted
## 충전 표시 진행·그리기 (SkillCaster가 부른다). 영웅별 ChargeMarkerData, 없으면 공통 붓 고리.

var data: ChargeMarkerData
var _spark_cd: float = 0.0
var _was_full: bool = false
var _flash_left: float = 0.0
var _age: float = 0.0
## 모으는 마디 (ChargeScaling.stages, 0이면 표시 없음): 지금 마디, 마디 수, 넘는 순간 고리 커짐.
var _stage: int = 0
var _stages: int = 0
var _pulse_left: float = 0.0
## 모으기 기술 쿨타임 남은 시간(초) (0이면 낼 수 있음).
var wait: float = 0.0


func _init(p_data: ChargeMarkerData = null) -> void:
	data = p_data


## 매 프레임: charging = 모으는 중, c = 0~1. 입자·다 찬 순간 번쩍임을 낸다. 반환: 이번에 다 찼으면 true.
## stages > 0이면 (ChargeScaling) 마디 점을 그리고, 마디를 넘을 때 소리 + 고리가 잠깐 커진다.
## wait > 0: 모으기 기술 쿨타임이 이만큼 남음 → 입자·번쩍임·소리 없이 흐린 고리 + 남은 시간 (draw).
func tick(delta: float, charging: bool, c: float, pos: Vector2, stage: int = 0, stages: int = 0, p_wait: float = 0.0) -> bool:
	_age += delta
	_flash_left = maxf(_flash_left - delta, 0.0)
	_pulse_left = maxf(_pulse_left - delta, 0.0)
	_stages = stages
	wait = p_wait if charging else 0.0
	if not charging or wait > 0.0:
		_was_full = false
		_spark_cd = 0.0
		_stage = 0
		return false
	if stages > 0 and stage > _stage and stage < stages and data:
		_pulse_left = data.stage_pulse_time
		_sfx(data.stage_sfx, 1.0 + data.stage_pitch_step * stage)
	_stage = stage
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
			_sfx(data.full_sfx, 1.0)
	_was_full = c >= 1.0
	return became_full


func _sfx(kind: StringName, pitch: float) -> void:
	if kind != &"" and Feedback.instance:
		Feedback.instance.play(kind, 0.04, pitch)


func stage() -> int:
	return _stage


func pulse_left() -> float:
	return _pulse_left


## 바로 지운다 (죽었을 때: 번쩍임도 남기지 않음).
func cancel() -> void:
	_flash_left = 0.0
	_spark_cd = 0.0
	_pulse_left = 0.0


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
	var pulse := lerpf(1.0, data.stage_pulse_scale, _pulse_left / maxf(data.stage_pulse_time, 0.001))
	var size := lerpf(data.size_min, data.size_max, c) * (lerpf(data.full_flash_scale, 1.0, k) if flash else 1.0) * pulse
	var dim := data.wait_dim if waiting() else 1.0
	var a := lerpf(data.alpha_min, data.alpha_max, c) * dim
	var bright := lerpf(data.full_flash_bright, 1.0, k) if flash else 1.0
	_tex(canvas, data.art, size, _age * data.spin, Color(data.tint * bright, data.tint.a * a))
	if data.art2:
		_tex(canvas, data.art2, size * data.inner_scale, _age * data.spin2, Color(data.tint2 * bright, data.tint2.a * a))
	if charging:
		_draw_pips(canvas, size, dim)
	if charging and waiting():
		_draw_wait(canvas, size)


func waiting() -> bool:
	return wait > 0.0


## 남은 시간 글자 (숫자만): 1초 이상은 올림 정수, 그 아래는 소수 한 자리.
static func wait_text(left: float) -> String:
	return str(ceili(left)) if left >= 1.0 else "%.1f" % maxf(left, 0.1)


func _draw_wait(canvas: CanvasItem, ring: float) -> void:
	var t := wait_text(wait)
	var at := Vector2(-80.0, ring * data.wait_ring_k + data.wait_gap + data.wait_font_px * 0.8)  # 발밑 고리 아래쪽 칠 바로 밑
	canvas.draw_string_outline(UiStyle.TITLE_FONT, at, t, HORIZONTAL_ALIGNMENT_CENTER, 160.0, data.wait_font_px,
		data.wait_outline_px, data.wait_outline)
	canvas.draw_string(UiStyle.TITLE_FONT, at, t, HORIZONTAL_ALIGNMENT_CENTER, 160.0, data.wait_font_px, data.wait_color)


## 마디 점: 고리 아래쪽 둘레에 stages개, 넘은 마디는 한지색으로 찬다.
func _draw_pips(canvas: CanvasItem, ring: float, dim: float = 1.0) -> void:
	if _stages <= 0:
		return
	var r := maxf(ring * 0.5, data.pip_radius)
	for i in _stages:
		var t := PI * 0.5 - (i - (_stages - 1) * 0.5) * 0.42  # 발 아래 (영웅 그림에 가리지 않게), 왼쪽부터
		var at := Vector2(cos(t), sin(t)) * r
		var lit := i < _stage
		InkPaint.wash(canvas, at, data.pip_size + 3.0, Color(0.09, 0.09, 0.11, 0.6 * dim))  # 먹 번짐 바탕
		if lit:
			InkPaint.wash(canvas, at, data.pip_size, Color(data.pip_full, data.pip_full.a * dim))
		else:
			InkPaint.ring(canvas, at, data.pip_size, Color(data.pip_empty, data.pip_empty.a * dim))  # 빈 마디: 한지색 붓 고리


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
	InkPaint.arc(canvas, Vector2.ZERO, 36.0 + 20.0 * c, -PI / 2, -PI / 2 + TAU * maxf(c, 0.02), 9.0, Color(0.4, 0.8, 1.0, 0.9), 24)
