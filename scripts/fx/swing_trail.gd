class_name SwingTrail
extends Node2D
## 평타 검기 궤적: 칼이 지나간 자리에 붓 획 띠가 그려졌다 꼬리부터 사라진다 (정해진 초승달 한 장 대신).
## 부채꼴 판정과 같은 각도·사거리를 휩쓸고 (1타 가로, 2타 반대쪽에서, 3타 좁고 길고 굵게),
## 3타 모으기 동안엔 그리지 않고, 칼이 닿아 멈추는 동안(히트스톱)엔 같이 멈춘다.
## 굽기 때 기록한 무기 끝(SpriteSheetSet.tips)은 칸마다 크게 튀어 (예: 순신 attack2 오른쪽 -24→120px)
## 그대로 이으면 지그재그가 되어, 각도·시각만 동작에 맞추고 모양은 부채꼴로 그린다.
## 수치: data/feel/swing_trail.tres. 쓰는 영웅이 아니면 예전 초승달 (SwingCrescent).

const DEFAULT := preload("res://data/feel/swing_trail.tres")

@export var attack: AutoAttack
@export var data: SwingTrailData = DEFAULT

var arc := SwingArc.new()
var _clock: float = 0.0
var _active: bool = false
## 이번 휘두르기의 영웅 검기 색 (BasicAttackData.swing_color).
var color: Color = Color(0.15, 0.45, 0.85)
var _outer := PackedVector2Array()
var _inner := PackedVector2Array()
var _f := PackedFloat32Array()
var _quad := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _uv := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _cols := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])


## 이 플레이어의 평타를 궤적이 그리는지 (그러면 AutoAttack은 초승달을 그리지 않는다).
static func covers(player: Node) -> bool:
	if player == null or not player.has_meta(&"swing_trail"):
		return false
	var h: HeroData = player.get("hero")
	var d: SwingTrailData = player.get_meta(&"swing_trail")
	return h != null and d != null and d.heroes.has(String(h.id))


func _ready() -> void:
	z_index = 4  # 캐릭터 위, 타격 섬광(FxLayer 5) 아래
	var n := maxi(data.segments, 2) + 1
	_outer.resize(n)
	_inner.resize(n)
	_f.resize(n)
	if attack:
		attack.melee_windup.connect(_on_windup)
		if attack.player:
			attack.player.set_meta(&"swing_trail", data)


func _on_windup(dir: Vector2) -> void:
	if not covers(attack.player):
		return
	var sd := attack.stats()
	color = sd.swing_color
	var step := attack.chain_step
	var half := deg_to_rad(sd.melee_arc_degrees * ComboSteps.at(sd.step_arc_mults, step, 1.0) * 0.5)
	var r := sd.melee_range * ComboSteps.at(sd.step_range_mults, step, 1.0) * data.reach
	var w := data.width * ComboSteps.at(data.step_widths, step, 1.0)
	arc.setup(dir.angle(), half, ComboSteps.at(sd.step_trail_flip, step, 1.0) * data.sweep_sign, r, w,
		attack.step_pause(), attack.melee_delay(), data)
	_clock = 0.0
	_active = true


func _process(delta: float) -> void:
	if not _active:
		return
	if not _hitstopped():
		_clock += delta
	if attack and attack.player:
		global_position = attack.player.global_position + data.center_offset
	_active = arc.alive(_clock, data)
	queue_redraw()


## 칼이 닿은 뒤 영웅 그림이 멈춘 동안 (PlayerView 히트스톱). 모으기 멈춤은 닿기 전이라 세지 않는다.
func _hitstopped() -> bool:
	if _clock < arc.strike or attack == null or attack.player == null:
		return false
	var view := attack.player.get_node_or_null("PlayerView")
	var left: Variant = view.get("_hitstop_left") if view else null
	return left != null and float(left) > 0.0


func _draw() -> void:
	if not _active:
		return
	arc.fill(_clock, data, _outer, _inner, _f)
	var tex := data.band
	var col := color
	if data.ink_alpha > 0.0:  # 먹 외곽선 (조금 넓게 먼저)
		_band(tex, Color(Ink.INK, data.ink_alpha), 1.0, data.ink_px)
	_band(tex, Color(col.lerp(Color.WHITE, data.lighten), 1.0), 1.0, 0.0)
	if data.core_alpha > 0.0:  # 밝은 심: 바깥 가장자리를 따라 가늘게
		_band(tex, Color(col.lerp(Color.WHITE, data.core_white), data.core_alpha), data.core_width, 0.0)


## 띠 한 겹: 바깥~(바깥→안쪽 frac 지점), 양쪽으로 grow px 넓힌다. 꼬리로 갈수록 옅게.
func _band(tex: Texture2D, c: Color, frac: float, grow: float) -> void:
	for i in _f.size() - 1:
		if _f[i + 1] <= 0.0:
			continue
		for j in 2:
			var k := i + j
			var o := _outer[k]
			var inn := o.lerp(_inner[k], frac)
			var g := (o - inn).normalized() * grow if grow > 0.0 else Vector2.ZERO
			_quad[j] = o + g
			_quad[3 - j] = inn - g
			_uv[j] = Vector2(_f[k] * 0.9 + 0.05, 0.0)
			_uv[3 - j] = Vector2(_f[k] * 0.9 + 0.05, 1.0)
			var a := Color(c, c.a * _f[k])
			_cols[j] = a
			_cols[3 - j] = a
		draw_primitive(_quad, _cols, _uv, tex)
