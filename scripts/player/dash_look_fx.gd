class_name DashLookFx
extends Node2D
## 내닫기 생김새 효과 (DashLookData, PlayerView가 영웅 그림 뒤에 붙인다):
## 피하는 내닫기 = 지나간 자리마다 지금 자세 그림을 옅은 색으로 남기는 잔상, 치는 내닫기 = 도착할 때 출발 → 도착 칼 궤적 한 줄.
## 영웅 회피 생김새의 지나간 길 띠는 DashLookData.style_path로 끈다. 잔상 자리는 미리 잡은 배열을 돌려 쓴다 (프레임마다 할당 없음).

const MAX := 12

var player: Player
var sprite: AnimatedSprite2D
## 잔상: 월드 자리, 지난 시간 (음수 = 비었음), 그 칸 그림.
var _pos := PackedVector2Array()
var _age := PackedFloat32Array()
var _tex: Array[Texture2D] = []
var _next: int = 0
var _gap_left: float = 0.0
var _start := Vector2.ZERO


func _init(p: Player = null, s: AnimatedSprite2D = null) -> void:
	player = p
	sprite = s
	_pos.resize(MAX)
	_age.resize(MAX)
	_age.fill(-1.0)
	_tex.resize(MAX)
	if player:
		player.dash_started.connect(_on_dash_started)
		player.dash_ended.connect(_on_dash_ended)


func _on_dash_started(_dir: Vector2) -> void:
	var d := DashLook.data(player)
	if d == null:
		return
	_start = player.global_position
	_gap_left = 0.0
	if player.dash_runner:
		player.dash_runner.draw_path = d.style_path


## 치는 내닫기가 끝남: 칼 궤적 한 줄 (출발 → 도착).
func _on_dash_ended() -> void:
	var d := DashLook.data(player)
	if d == null or not d.strike_line or not player.dash_strikes:
		return
	if _start.distance_squared_to(player.global_position) < 16.0:
		return
	var col := player.hero.attack.swing_color.lerp(Color.WHITE, d.line_lighten)
	Feedback.vfx_stroke(_start, player.global_position, d.line_width, d.line_time, col)


func _process(delta: float) -> void:
	if sprite != null and not is_instance_valid(sprite):
		queue_free()
		return
	var d := DashLook.data(player)
	if d == null:
		return
	for i in MAX:
		if _age[i] >= 0.0:
			_age[i] = _age[i] + delta if _age[i] + delta < d.afterimage_life else -1.0
	if DashLook.is_evade(player) and d.afterimages > 0:
		_gap_left -= delta
		if _gap_left <= 0.0:
			_gap_left = maxf(d.afterimage_gap, 0.005)
			_leave(mini(d.afterimages, MAX))
	queue_redraw()


## 지금 자리·칸을 잔상 하나로 (count개를 돌려 쓴다).
func _leave(count: int) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return
	_next = (_next + 1) % maxi(count, 1)
	_pos[_next] = player.global_position
	_age[_next] = 0.0
	_tex[_next] = tex


func live_count() -> int:
	var n := 0
	for a in _age:
		n += int(a >= 0.0)
	return n


func _draw() -> void:
	var d := DashLook.data(player)
	if d == null or sprite == null:
		return
	for i in MAX:
		if _age[i] < 0.0 or _tex[i] == null:
			continue
		var k := 1.0 - _age[i] / maxf(d.afterimage_life, 0.001)
		var size := _tex[i].get_size()
		var at := to_local(_pos[i]) - to_local(player.global_position) + sprite.position + sprite.offset \
			- (size * 0.5 if sprite.centered else Vector2.ZERO) * sprite.scale
		draw_set_transform(at, 0.0, sprite.scale)
		draw_texture(_tex[i], Vector2.ZERO, Color(d.afterimage_color, d.afterimage_alpha * k * k))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
