class_name EvadeRim
extends Node2D
## 회피 성공 무적 동안 영웅 몸 둘레 금빛 테두리 (EvadeRimData): 영웅 그림(_sprite) 뒤에서 지금 칸을 금색 실루엣으로
## 둘레 8방향에 조금씩 밀어 그린다 → 앞의 몸이 가운데를 덮어 테두리만 보인다. 2D 구운 칸이든 3D 화면 그림이든 같은 _sprite를 읽는다
## (몸 재질은 건드리지 않음: 3D 먹 셰이더와 겹치지 않게). Player.evaded 때 켜지고, 남은 무적만큼 옅어진다.

const SHADER := preload("res://shaders/silhouette.gdshader")
const DIRS: Array[Vector2] = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(0.707, 0.707), Vector2(-0.707, 0.707), Vector2(0.707, -0.707), Vector2(-0.707, -0.707)]

var player: Player
var sprite: AnimatedSprite2D
var data: EvadeRimData
var _total: float = 0.0
var _t: float = 0.0


func _init(p: Player = null, s: AnimatedSprite2D = null) -> void:
	player = p
	sprite = s
	data = load(EvadeRimData.PATH) as EvadeRimData
	if data == null:
		data = EvadeRimData.new()
	var m := ShaderMaterial.new()
	m.shader = SHADER
	material = m
	if player:
		player.evaded.connect(func() -> void: _total = maxf(player.evade_invuln_time, 0.001))


## 0~1 진하기: 회피 무적 남은 시간 ÷ 전체 (회피로 켜진 무적만, 끝나기 직전 깜빡).
func strength() -> float:
	if player == null or _total <= 0.0:
		return 0.0
	var left := minf(player.skill_invuln_left(), _total)
	if left <= 0.0:
		_total = 0.0
		return 0.0
	var k := pow(left / _total, data.fade_power)
	if data.blink_below > 0.0 and left < data.blink_below and int(_t * data.blink_hz) % 2 == 1:
		return 0.0
	return k


func _process(delta: float) -> void:
	if sprite != null and not is_instance_valid(sprite):  # 영웅 그림이 지워지면 같이 (다시 만들 때 새 테두리가 붙는다)
		queue_free()
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var k := strength()
	if k <= 0.0 or sprite == null or sprite.sprite_frames == null or not sprite.visible:
		return
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return
	var size := tex.get_size()
	var col := Color(data.color, data.color.a * k)
	var at := sprite.position + sprite.offset - (size * 0.5 if sprite.centered else Vector2.ZERO) * sprite.scale
	for d in DIRS:  # 영웅 그림은 8방향 시트라 뒤집지 않는다 (flip_h 안 씀)
		draw_set_transform(at + d * data.width_px, 0.0, sprite.scale)
		draw_texture(tex, Vector2.ZERO, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
