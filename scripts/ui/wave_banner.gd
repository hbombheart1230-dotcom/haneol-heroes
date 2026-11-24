class_name WaveBanner
extends RefCounted
## 물결 시작 알림의 상태와 그리기 ("첫째 물결"): 무대 시작 문구와 같은 결 (옻칠 띠 + 금선 + 붓글씨 제목).
## 입력을 막지 않고 판을 멈추지 않는다. 막혀 있는 동안(무대 시작 문구·조작 안내)에는 기다렸다 그 뒤에 뜬다.

var _title: String = ""
var _note: String = ""
var _pending: bool = false
var _age: float = -1.0  ## 보이는 중이면 0~show_time, 아니면 -1


## 알림 요청. elite면 중간 우두머리 줄을 붙인다.
func request(index: int, elite: bool) -> void:
	var d := WaveBannerData.default()
	_title = d.title_for(index)
	_note = d.elite_note if elite else ""
	_pending = true


## blocked = 다른 문구가 떠 있거나 조작 안내 중. cancel = 안내 중이라 대기 중인 알림을 버린다.
func tick(delta: float, blocked: bool, cancel: bool = false) -> void:
	if cancel:
		_pending = false
		_age = -1.0
		return
	if _pending and not blocked:
		_pending = false
		_age = 0.0
	elif _age >= 0.0:
		_age += delta
		if _age >= WaveBannerData.default().show_time:
			_age = -1.0


func is_showing() -> bool:
	return _age >= 0.0


func is_pending() -> bool:
	return _pending


func title() -> String:
	return _title


## 지금 알파 (0이면 안 보임).
func alpha() -> float:
	if _age < 0.0:
		return 0.0
	var d := WaveBannerData.default()
	return minf(clampf(_age / maxf(d.fade_in, 0.01), 0.0, 1.0), clampf((d.show_time - _age) / maxf(d.fade_out, 0.01), 0.0, 1.0))


func draw(c: CanvasItem, size: Vector2) -> void:
	var a := alpha()
	if a <= 0.0:
		return
	var d := WaveBannerData.default()
	var y := size.y * d.y_ratio
	var band := Rect2(0, y - d.band_height * 0.5, size.x, d.band_height)
	c.draw_rect(band, Color(UiStyle.LACQUER, 0.8 * a))
	c.draw_line(band.position, Vector2(band.end.x, band.position.y), Color(UiStyle.GOLD, a), 2.0)
	c.draw_line(Vector2(0, band.end.y), band.end, Color(UiStyle.GOLD, a), 2.0)
	var ty := y + d.title_size * 0.3 - (14.0 if _note != "" else 0.0)
	UiStyle.text(c, UiStyle.TITLE_FONT, Vector2(0, ty), _title, d.title_size, Color(UiStyle.GOLD, a), size.x)
	if _note != "":
		UiStyle.gold_rule(c, Vector2(size.x * 0.5, ty + 18), size.x * 0.16, a)
		UiStyle.text(c, UiStyle.BODY_FONT, Vector2(0, ty + 52), _note, d.note_size, Color(UiStyle.PAPER, 0.92 * a), size.x,
			Color(0, 0, 0, 0.6 * a), 4)
