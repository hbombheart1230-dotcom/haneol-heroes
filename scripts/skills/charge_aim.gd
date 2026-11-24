class_name ChargeAim
extends RefCounted
## 충전 조준 (SkillDef.charge_aim, 순수 로직 + 바닥 먹선 길): 모으기 시작할 때 바라보던 방향에서 시작해,
## 모으는 동안 이동 입력(한 손: 누른 손가락을 끄는 쪽, 두 손: 이동 손가락)이 min_input 이상이면 그쪽으로 돌린다.
## 손을 뗄 때 흔들리는 마지막 작은 움직임은 min_input 아래라 방향을 바꾸지 않는다. 놓으면 SkillContext.aim_dir로.

var dir: Vector2 = Vector2.ZERO
var active: bool = false
## 모으는 동안 한 번이라도 끌었는지 (끌지 않으면 자동인 기술은 지금처럼: SkillDef.charge_aim_auto).
var steered: bool = false
var _pts := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])  # 길 띠 (돌려 씀)
var _head := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


## 매 물리 프레임. charging = 살아서 모으는 중.
func tick(charging: bool, facing: Vector2, move: Vector2, min_input: float) -> void:
	if not charging:
		active = false
		return
	if not active:
		active = true
		steered = false
		dir = facing.normalized() if facing.length_squared() > 0.0001 else Vector2.DOWN
	if move.length() >= min_input and move.length_squared() > 0.0001:
		dir = move.normalized()
		steered = true


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


## 바닥 먹 원 (자리를 잡는 기술: 낙뢰·화폭): center(영웅 발밑 기준)에 반경 r. c = 충전 0~1.
static func draw_circle_aim(canvas: CanvasItem, center: Vector2, r: float, c: float, d: ChargeMarkerData) -> void:
	if r <= 0.0:
		return
	var a := lerpf(d.aim_alpha_min, d.aim_alpha_max, c)
	canvas.draw_circle(center, r, Color(d.aim_fill, d.aim_fill.a * a))
	canvas.draw_arc(center, r, 0.0, TAU, 48, Color(d.aim_ink, d.aim_ink.a * a), d.aim_line_width)


## 바닥 먹 꺾은선 (별자리): pts를 폭 width로 잇고 마디마다 점. c = 충전 0~1.
static func draw_polyline_aim(canvas: CanvasItem, pts: PackedVector2Array, width: float, c: float, d: ChargeMarkerData) -> void:
	if pts.size() < 2:
		return
	var a := lerpf(d.aim_alpha_min, d.aim_alpha_max, c)
	canvas.draw_polyline(pts, Color(d.aim_fill, d.aim_fill.a * a), width)
	canvas.draw_polyline(pts, Color(d.aim_ink, d.aim_ink.a * a), d.aim_line_width)
	for p in pts:
		canvas.draw_circle(p, d.aim_line_width * 2.5, Color(d.aim_ink, d.aim_ink.a * a))
