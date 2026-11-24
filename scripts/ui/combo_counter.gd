class_name ComboCounter
extends Control
## 연타 글씨: 칼·내닫기 타격·기술 어느 것으로든 적을 맞히면 "1타"·"2타"… 계속 오르고 (다단 기술은 한 타마다),
## 연타 유지 시간(ComboTextData.break_time, 없으면 kit.combo_window) 동안 못 맞히면 바로 0 (ComboHits).
## 붓글씨 한지 톤, 타수가 오를수록 크게 (상한), 넷째 탭 마무리 동안은 인주색. 화면 왼쪽 가운데 위
## (영웅·적·피해 숫자를 가리지 않게), 끊기면 옅어진다. 설정 "연타 글씨"로 끈다.
## 명중은 Feedback.hit_serial이 늘어난 만큼 센다. 글은 타수가 바뀔 때만 만든다 (프레임마다 할당 없음).

const DATA_PATH := "res://data/ui/combo_text.tres"
const FONT := preload("res://assets/fonts/DeogonPrincess.ttf")
const FALLBACK_WINDOW := 1.2

@export var caster: SkillCaster
@export var data: ComboTextData

var hits := ComboHits.new()
## 지금 보이는 타 (0 = 없음, 끊긴 뒤 옅어지는 동안은 마지막 타), 그 글, 튄 뒤 흐른 시간, 투명도, 마무리 색 남은 시간.
var _n: int = 0
var _label: String = ""
var _age: float = INF
var _alpha: float = 0.0
var _finish_left: float = 0.0
var _seen: int = 0
## 판이 끝나면(이김·쓰러짐) 바로 지우고 더 세지 않는다 (결과 판 위에 남지 않게, Main._on_ended).
var stopped := false


func _ready() -> void:
	add_to_group(SealChoice.BATTLE_TEXT)  # 패 고르기 화면 동안 숨김
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if data == null:
		data = load(DATA_PATH) as ComboTextData
	_seen = Feedback.hit_serial
	bind(caster)


func bind(c: SkillCaster) -> void:
	if caster and caster.combo_count.is_connected(_on_tap_count):
		caster.combo_count.disconnect(_on_tap_count)
	caster = c
	if caster and not caster.combo_count.is_connected(_on_tap_count):
		caster.combo_count.connect(_on_tap_count)


## 넷째 탭 마무리 (SkillCaster.combo_count = combo_hits + 1): 마무리 색.
func _on_tap_count(n: int) -> void:
	if caster and caster.kit and n > caster.kit.combo_hits and data:
		_finish_left = data.finish_hold
		queue_redraw()


## 적을 n번 맞혔다 (Feedback.hit_serial이 아닌 곳에서 직접 넣을 때도).
func add_hits(n: int = 1) -> void:
	if n <= 0 or data == null:
		return
	hits.add(n)
	if not GameSettings.combo_text:
		return
	_n = hits.count
	_label = data.label_format % _n
	if _age > data.pop_min_gap:  # 다단 타격이 몰아쳐도 매번 튀지 않는다
		_age = 0.0
	_alpha = 1.0
	queue_redraw()


func stop() -> void:
	stopped = true
	_n = 0
	_alpha = 0.0
	queue_redraw()


## 지금 보이는 글이 차지하는 자리 (화면 좌표, 안 보이면 빈 칸). 영웅 대사가 이 자리를 피한다.
func text_rect() -> Rect2:
	if _n == 0 or _alpha <= 0.0 or data == null or _under_boss_banner():
		return Rect2()
	var px := size_for(_n, finishing(), data)
	var vp := size if size.x > 0.0 else get_viewport_rect().size
	var at := vp * data.anchor
	var w := FONT.get_string_size(_label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	return Rect2(at.x - w * 0.5, at.y - px, w, px * 1.25)


func shown() -> int:
	return _n


func alpha() -> float:
	return _alpha


func count() -> int:
	return hits.count


func finishing() -> bool:
	return _finish_left > 0.0


## 끊기는 시간 (초): 데이터, 없으면 영웅 연타 유지 시간.
func break_time() -> float:
	if data and data.break_time > 0.0:
		return data.break_time
	return caster.kit.combo_window if caster and caster.kit else FALLBACK_WINDOW


func _process(delta: float) -> void:
	if stopped:
		return
	var serial := Feedback.hit_serial
	if serial != _seen:
		add_hits(serial - _seen)
		_seen = serial
	hits.tick(delta, break_time())
	_finish_left = maxf(_finish_left - delta, 0.0)
	if _n == 0:
		return
	_age += delta
	if not GameSettings.combo_text:
		_alpha = 0.0
	elif hits.count == 0:  # 끊겼다: 숫자는 이미 0, 글만 옅어진다
		_alpha -= delta / maxf(data.fade_time, 0.001)
	if _alpha <= 0.0:
		_n = 0
		_alpha = 0.0
	queue_redraw()


## 글자 크기 (px): 타마다 커지다 size_max에서 멈춤, 마무리 동안은 finish_size.
static func size_for(n: int, finishing_now: bool, d: ComboTextData) -> int:
	if finishing_now:
		return d.finish_size
	return mini(d.size_base + d.size_step * maxi(n - 1, 0), d.size_max)


## 우두머리 등장 띠(이름)나 물결 알림 띠가 떠 있는 동안은 글씨를 그리지 않는다 (이름 위에 겹쳐 읽기 어렵지 않게). 수는 계속 센다.
func _under_boss_banner() -> bool:
	var b := get_node_or_null("../BossBanner") as BossBanner
	if b != null and b.banner_visible():
		return true
	var hud := get_parent() as Hud
	return hud != null and hud.wave_banner_showing()


func _draw() -> void:
	if _n == 0 or data == null or _under_boss_banner():
		return
	var fin := finishing()
	var px := size_for(_n, fin, data)
	var vp := size if size.x > 0.0 else get_viewport_rect().size
	var at := vp * data.anchor
	var k := clampf(_age / maxf(data.pop_time, 0.001), 0.0, 1.0)
	var pop := lerpf(data.finish_pop_scale if fin else data.pop_scale, 1.0, 1.0 - (1.0 - k) * (1.0 - k))
	draw_set_transform(at, 0.0, Vector2(pop, pop))
	if data.stroke_mult > 0.0:  # 글 뒤 먹 붓자국
		var half := px * data.stroke_mult * 0.5
		draw_line(Vector2(-half, -px * 0.32), Vector2(half, -px * 0.4), Color(data.stroke_color, data.stroke_color.a * _alpha), px * 0.9)
	var col := data.finish_color if fin else data.color
	var w := px * 4.0
	UiStyle.text(self, FONT, Vector2(-w * 0.5, 0.0), _label, px, Color(col, col.a * _alpha), w,
		data.outline, data.outline_px)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
