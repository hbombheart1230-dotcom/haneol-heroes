class_name ChargeAim
extends RefCounted
## 충전 조준 (SkillDef.charge_aim, 순수 로직 + 바닥 먹선 길): 모으기 시작할 때 바라보던 방향에서 시작해,
## 모으는 동안 이동 입력(한 손: 누른 손가락을 끄는 쪽, 두 손: 이동 손가락)이 min_input 이상이면 그쪽으로 돌린다.
## 손을 뗄 때 흔들리는 마지막 작은 움직임은 min_input 아래라 방향을 바꾸지 않는다. 놓으면 SkillContext.aim_dir로.

var dir: Vector2 = Vector2.ZERO
var active: bool = false
var _pts := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])  # 길 띠 (돌려 씀)
var _head := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


## 매 물리 프레임. charging = 살아서 모으는 중.
func tick(charging: bool, facing: Vector2, move: Vector2, min_input: float) -> void:
	if not charging:
		active = false
		return
	if not active:
		active = true
		dir = facing.normalized() if facing.length_squared() > 0.0001 else Vector2.DOWN
	if move.length() >= min_input and move.length_squared() > 0.0001:
		dir = move.normalized()


## 모으는 중 잡힌 방향 (모으지 않으면 ZERO).
func aim_dir() -> Vector2:
	return dir if active else Vector2.ZERO


## 바닥 먹선 길: 영웅 발밑(canvas 원점)에서 dir로 length만큼, 폭 width. 끝에 화살촉. c = 충전 0~1.
func draw(canvas: CanvasItem, length: float, width: float, c: float, d: ChargeMarkerData) -> void:
	if not active or length <= 0.0:
		return
	var a := lerpf(d.aim_alpha_min, d.aim_alpha_max, c)
	var side := dir.orthogonal() * width * 0.5
	var from := dir * d.aim_start
	var to := dir * maxf(length, d.aim_start + 1.0)
	_pts[0] = from + side
	_pts[1] = to + side
	_pts[2] = to - side
	_pts[3] = from - side
	canvas.draw_colored_polygon(_pts, Color(d.aim_fill, d.aim_fill.a * a))
	canvas.draw_line(from, to, Color(d.aim_ink, d.aim_ink.a * a), d.aim_line_width)
	var h := d.aim_head
	_head[0] = to + dir * h * 0.6
	_head[1] = to - dir * h * 0.4 + dir.orthogonal() * h * 0.6
	_head[2] = to - dir * h * 0.4 - dir.orthogonal() * h * 0.6
	canvas.draw_colored_polygon(_head, Color(d.aim_ink, d.aim_ink.a * a))
