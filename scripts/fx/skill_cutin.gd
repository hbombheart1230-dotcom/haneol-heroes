class_name SkillCutin
extends CanvasLayer
## 큰 기술 컷인 (던파식 "필살기" 신호, 한얼 식): 먹 띠가 화면을 가로질러 그어지고, 영웅 카드 그림이 띠 속으로
## 밀려 들어오며, 붓글씨 기술 이름이 찍힌다 → 띠가 먹으로 갈라지며 사라진다. 그동안 게임은 잠깐 느려진다.
## 화면 좌표 (카메라 흔들림과 상관없음), 실제 시간으로 움직인다 (느린 시간에도 제 속도). 수치는 SkillStageFeel "컷인".

const LAYER := 40

static var _last_ms: int = -1000000

var def: SkillDef
var hero: HeroData
var stage: SkillStageFeel
var _start_ms: int = 0
var _canvas: Node2D
## 가장자리 흐림 칸 경계: 바깥 테두리만 투명, 안쪽 네모는 불투명 (사방 25%가 부드럽게 흐려짐).
const FEATHER_STOPS := [0.0, 0.25, 0.75, 1.0]
## 세로는 위를 조금만 흐린다 (얼굴이 위쪽에 있어서).
const FEATHER_STOPS_Y := [0.0, 0.08, 0.75, 1.0]
var _qp := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _qu := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _qc := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])


## 컷인을 띄울 수 있는지 (순수 계산): 지난 컷인에서 gap초가 지났는지.
static func can_play(now_ms: int, last_ms: int, gap: float) -> bool:
	return now_ms - last_ms >= int(gap * 1000.0)


## 테스트용: 간격 기록 지우기.
static func reset() -> void:
	_last_ms = -1000000


## def.cutin인 기술이면 컷인을 띄우고 게임을 잠깐 느리게. 띄웠으면 true.
static func play(tree: SceneTree, p_def: SkillDef, p_hero: HeroData, force: bool = false) -> bool:
	if tree == null or p_def == null or not (p_def.cutin or force):  # force = 성장 단계가 높아 컷인 (SkillGrowthData)
		return false
	var st := SkillStageFeel.get_default()
	var now := Time.get_ticks_msec()
	if not can_play(now, _last_ms, st.cutin_min_gap):
		return false
	_last_ms = now
	var c := SkillCutin.new()
	c.def = p_def
	c.hero = p_hero
	c.stage = st
	var parent: Node = tree.current_scene if tree.current_scene else tree.root
	parent.add_child(c)
	GameTime.stop(tree, st.cutin_slow, st.cutin_slow_scale)  # 소리는 기술의 sfx_layers (북·징 등)
	return true


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start_ms = Time.get_ticks_msec()
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_cutin)
	add_child(_canvas)


func _process(_delta: float) -> void:
	if progress() >= 1.0:
		queue_free()
		return
	_canvas.queue_redraw()


## 0~1 진행 (실제 시간).
func progress() -> float:
	return clampf((Time.get_ticks_msec() - _start_ms) / 1000.0 / maxf(stage.cutin_time, 0.05), 0.0, 1.0)


func _draw_cutin() -> void:
	var view := get_viewport().get_visible_rect().size
	var k := progress()
	var feel := Feedback.feel_data()
	var band_h := view.y * stage.cutin_band
	var cy := view.y * stage.cutin_y
	var wipe := clampf(k / 0.18, 0.0, 1.0)  # 앞 18%: 붓이 왼쪽에서 오른쪽으로 긋는다
	var out := clampf((k - 0.72) / 0.28, 0.0, 1.0)  # 끝 28%: 위아래로 갈라지며 사라진다
	var ease := 1.0 - pow(1.0 - wipe, 3.0)
	var stroke := feel.stroke_art
	var a := 1.0 - out
	if stroke:  # 먹 띠: 붓 획 그림을 길게, 그어지는 만큼만 (그림 영역을 잘라 그려 끝이 붓 머리). 두 번 겹쳐 진하게
		var w := view.x * 1.3 * ease
		var tw := float(stroke.get_width())
		var th := float(stroke.get_height())
		for layer in 2:
			var bh := band_h * (1.25 if layer == 0 else 0.85)
			for half in 2:  # 사라질 때 위·아래 반쪽이 벌어진다
				var dy := (out * bh * 0.4) * (1.0 if half == 1 else -1.0)
				var src := Rect2(tw * (1.0 - ease), th * 0.5 * half, tw * ease, th * 0.5)
				var dst := Rect2(-view.x * 0.15, cy - bh * 0.5 + bh * 0.5 * half + dy, w, bh * 0.5)
				_canvas.draw_texture_rect_region(stroke, dst, src, Color(0.05, 0.05, 0.07, (0.8 if layer == 0 else 0.95) * a))
	if hero and hero.card_art:  # 영웅 그림: 오른쪽에서 밀려 들어와 띠 안에 (얼굴 쪽 윗부분), 가장자리는 먹처럼 흐려짐
		var slide := 1.0 - pow(1.0 - clampf((k - 0.05) / 0.22, 0.0, 1.0), 3.0)
		var h := band_h * 1.5
		var w := view.x * 0.55
		var art := hero.card_art
		var src_h := minf(art.get_width() * h / w, art.get_height() * 0.6)
		var dst := Rect2(view.x * (1.02 - 0.55 * slide), cy - h * 0.55, w, h)
		_feathered(art, dst, Rect2(0, art.get_height() * 0.02, art.get_width(), src_h), a * slide)
	if def:  # 기술 이름: 붓글씨가 크게 찍혔다가 자리 잡는다
		var stamp := clampf((k - 0.1) / 0.16, 0.0, 1.0)
		if stamp > 0.0:
			var col := Color(UiStyle.GOLD.lightened(0.25), a * stamp)
			draw_name(_canvas, Vector2(view.x * 0.06, cy), def.display_name, stage.cutin_font_px,
				lerpf(1.5, 1.0, 1.0 - pow(1.0 - stamp, 3.0)), col)


## 그림을 3×3 칸(정점 4×4) 다각형으로 그려 바깥 테두리 정점만 투명하게 (네모 칼선 대신 부드러운 가장자리).
## 기술 이름 한 줄: 글꼴은 늘 size 크기로 그리고 찍히는 크기는 늘려 그린다 (프레임마다 새 글꼴 크기를 만들면
## 첫 컷인마다 글자 그림을 새로 만드느라 멈칫한다; FxWarmupLayer가 같은 함수로 미리 그린다). at = 왼쪽 가운데 줄.
static func draw_name(c: CanvasItem, at: Vector2, text: String, size: int, grow: float, col: Color) -> void:
	c.draw_set_transform(at, 0.0, Vector2.ONE * grow)
	UiStyle.text(c, UiStyle.TITLE_FONT, Vector2(0, size * 0.35), text, size, col, -1.0, Color(0, 0, 0, 0.85), maxi(size / 10, 4))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _feathered(tex: Texture2D, dst: Rect2, src: Rect2, alpha: float) -> void:
	var ts := tex.get_size()
	for gy in 3:
		for gx in 3:
			for v in 4:
				var cx := gx + (1 if v == 1 or v == 2 else 0)
				var cyi := gy + (1 if v >= 2 else 0)
				var fx: float = FEATHER_STOPS[cx]
				var fy: float = FEATHER_STOPS_Y[cyi]
				_qp[v] = dst.position + dst.size * Vector2(fx, fy)
				_qu[v] = (src.position + src.size * Vector2(fx, fy)) / ts
				var edge := cx == 0 or cx == 3 or cyi == 0 or cyi == 3
				_qc[v] = Color(1, 1, 1, 0.0 if edge else alpha)
			_canvas.draw_polygon(_qp, _qc, _qu, tex)
