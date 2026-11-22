class_name AnimBlend
extends Sprite2D
## 동작이 바뀌는 순간 앞 동작의 마지막 그림을 잠깐 겹쳐 흐리게 사라지게 한다 (스프라이트 동작 사이 교차 섞기,
## 사용자: "연계가 뚝뚝 끊어지는것"). 칸을 새로 굽지 않고 그림만으로 자세가 튀는 한두 칸을 메운다.
## 시간·처음 진하기는 CombatFeelData (anim_blend_time · anim_blend_alpha). 그림 하나를 돌려 쓴다 (할당 없음).

var _left: float = 0.0
var _time: float = 0.08
var _alpha: float = 0.6


func _init() -> void:
	visible = false
	centered = true


## 지금 보이는 칸을 찍어 두고 time초 동안 alpha → 0 (스프라이트와 같은 자리·크기·뒤집기·색).
func snapshot(src: AnimatedSprite2D, time: float, alpha: float) -> void:
	if src == null or src.sprite_frames == null or time <= 0.0 or alpha <= 0.0:
		return
	if not src.sprite_frames.has_animation(src.animation):
		return
	var n := src.sprite_frames.get_frame_count(src.animation)
	if n <= 0:
		return
	texture = src.sprite_frames.get_frame_texture(src.animation, clampi(src.frame, 0, n - 1))
	position = src.position
	scale = src.scale
	rotation = src.rotation
	flip_h = src.flip_h
	offset = src.offset
	material = src.material
	_time = time
	_alpha = alpha
	_left = time
	modulate = Color(src.modulate, src.modulate.a * alpha)
	visible = true


func tick(delta: float) -> void:
	if _left <= 0.0:
		return
	_left = maxf(_left - delta, 0.0)
	modulate.a = _alpha * (_left / maxf(_time, 0.001))
	visible = _left > 0.0


func active() -> bool:
	return _left > 0.0
