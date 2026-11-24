class_name Hud
extends Control
## P0 HUD: 체력, 남은 시간, 처치 수, 대시 충전, 결과 화면, 터치 디버그 표시.
## 고정 조이스틱 UI는 그리지 않는다. 디버그 표시는 show_touch_debug로 끌 수 있다.

@export var player: Player
@export var controller: TouchController
@export var show_touch_debug: bool = true

var state: GameState
## P0-D 성능 기록. 결과 화면에 요약을 보여준다.
var perf: PerfStats
## 런 성장 진행 (경험치 막대·레벨 표시). 없으면 그리지 않는다.
var progress: RunProgress
## 구석 영웅 묶음 (초상·체력·경험치 고리·레벨 도장·적립 카드·레벨업 연출).
var badge := HeroBadge.new()
## 판 시작 때 띄우는 무대 이름 (연도 · 전장).
var stage: StageTheme
## 물결 진행 표시: 적 내보내는 쪽 (물결 모드일 때만 그린다).
var spawner: EnemySpawner
var _wave_prev_cleared: int = 0
var _wave_flash: float = 0.0
var _wave_clock: float = 0.0
var _wave_flash_at: int = -1
var _wave_banner := WaveBanner.new()
const STAGE_TITLE_TIME := 3.2
## 보스 막대의 방금 깎인 자국 (비율): CHIP_DELAY초 뒤 CHIP_SPEED/초로 따라 내려간다.
var _boss_chip: float = 1.0
var _chip_wait: float = 0.0
const CHIP_DELAY := 0.45
const CHIP_SPEED := 0.6


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_tick_boss_chip(delta)
	_tick_wave_track(delta)
	# 패 고르기·멈춤 동안은 띠를 그리지 않으니 시간도 세지 않는다 (안 보인 채 지나가지 않게)
	var banner_blocked := stage_title_alpha() > 0.0 or FxLayer.numbers_hidden or get_tree().paused
	_wave_banner.tick(delta, banner_blocked, hold_stage_title)
	badge.player = player
	badge.tick(delta)
	queue_redraw()


func _tick_boss_chip(delta: float) -> void:
	var b := _boss()
	var pct := b.health.percent() if b else 1.0
	if _boss_chip <= pct:
		_boss_chip = pct
		_chip_wait = CHIP_DELAY
	elif _chip_wait > 0.0:
		_chip_wait -= delta
	else:
		_boss_chip = move_toward(_boss_chip, pct, CHIP_SPEED * delta)


## 물결이 곧 시작됨 (EnemySpawner.wave_announce): 크게 알리고, 위쪽 점도 그 점에서 번진다.
func on_wave_announce(index: int, elite: bool) -> void:
	_wave_banner.request(index, elite)
	_wave_flash = 1.0
	_wave_flash_at = index


func _wave_runner() -> WaveRunner:
	return spawner.waves if spawner and is_instance_valid(spawner) else null


## 끝낸 물결이 늘면 번짐 시작, 시간과 함께 줄인다.
func _tick_wave_track(delta: float) -> void:
	_wave_clock += delta
	var cleared := WaveTrack.cleared_count(_wave_runner())
	if cleared > _wave_prev_cleared:
		_wave_flash = 1.0
		_wave_flash_at = cleared - 1
	_wave_prev_cleared = cleared
	_wave_flash = maxf(_wave_flash - delta / maxf(InkUiStyle.default().wave_flash_time, 0.05), 0.0)


## 조작 안내 중에는 숨긴다 (연습 상대만 나오고 물결이 아니라서).
func wave_track_visible() -> bool:
	return _wave_runner() != null and not hold_stage_title and state != null and state.is_playing()


func _draw_wave_track() -> void:
	if not wave_track_visible():
		return
	var runner := _wave_runner()
	var cx := (BossBarDrawer.TOP_FREE.x + size.x - 70.0) * 0.5  # 우두머리 막대와 같은 가운데
	WaveTrackDrawer.draw(self, WaveTrack.kinds(runner.data), WaveTrack.states(runner), WaveTrack.shown_number(runner),
		cx, _wave_flash, _wave_flash_at, _wave_clock)


func _boss() -> Enemy:
	var bosses: Array = get_tree().get_nodes_in_group(Enemy.BOSS_GROUP) if is_inside_tree() else []
	var b := bosses[0] as Enemy if not bosses.is_empty() else null
	return b if b and is_instance_valid(b) and not b.health.is_dead() else null


func _draw() -> void:
	if player:
		badge.player = player
		badge.progress = progress
		badge.draw(self, state.kills if state else 0)
		_draw_dash_pips()
	if controller and controller.skill_caster:
		SkillButtonDrawer.draw(self, controller, get_theme_default_font())
	if state:
		_draw_status()
		_draw_boss_bar()
		_draw_wave_track()
		_draw_stage_title()
		if not FxLayer.numbers_hidden:  # 패 고르기 화면 동안 숨김 (SealChoice.BATTLE_TEXT 와 같은 때)
			_wave_banner.draw(self, size)
	if show_touch_debug and GameSettings.show_stats and controller:
		_draw_touch_debug()
	if state and not state.is_playing():
		_draw_result()


## 조작 안내 중에는 무대 문구를 띄우지 않는다 (시간이 멈춰 있어 안 사라지고 연습 상대를 가린다). 끝나면 처음부터.
var hold_stage_title: bool = false


## 물결 시작 알림이 떠 있거나 뜰 차례 (영웅 대사가 그 띠와 겹치지 않게 기다린다).
func wave_banner_busy() -> bool:
	return _wave_banner.is_showing() or _wave_banner.is_pending()


## 무대 시작 문구: 연도 · 전장 이름 · 한 줄 설명. 처음 STAGE_TITLE_TIME초, 끝 1초 동안 흐려진다.
func stage_title_alpha() -> float:
	if stage == null or state == null or not state.is_playing() or hold_stage_title:
		return 0.0
	return clampf(STAGE_TITLE_TIME - state.elapsed, 0.0, 1.0)


func _draw_stage_title() -> void:
	var a := stage_title_alpha()
	if a <= 0.0:
		return
	var y := size.y * 0.3
	var band := Rect2(0, y - 92, size.x, 190)
	draw_rect(band, Color(UiStyle.LACQUER, 0.8 * a))
	draw_line(band.position, Vector2(band.end.x, band.position.y), Color(UiStyle.GOLD, a), 2.0)
	draw_line(Vector2(0, band.end.y), band.end, Color(UiStyle.GOLD, a), 2.0)
	UiStyle.text(self, UiStyle.BODY_FONT, Vector2(0, y - 46), stage.year_label, 30, Color(UiStyle.PAPER, a), size.x)
	UiStyle.text(self, UiStyle.TITLE_FONT, Vector2(0, y + 30), stage.title, 84, Color(UiStyle.GOLD, a), size.x)
	UiStyle.gold_rule(self, Vector2(size.x * 0.5, y + 50), size.x * 0.22, a)
	UiStyle.text(self, UiStyle.BODY_FONT, Vector2(0, y + 82), stage.subtitle, 22, Color(UiStyle.PAPER, 0.9 * a), size.x,
		Color(0, 0, 0, 0.6 * a), 4)


func _draw_status() -> void:
	var font := get_theme_default_font()
	var t := "%d" % ceili(state.time_left())
	if state.survive_time <= 0.0:  # 런: 지난 시간 (분:초)
		t = "%d:%02d" % [floori(state.elapsed / 60.0), floori(state.elapsed) % 60]
	if progress == null:
		_ink_text(font, Vector2(16, 200), "처치 %d" % state.kills, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
	# 위쪽 가운데는 우두머리 띠 자리: 시간은 톱니 단추 아래
	UiStyle.text(self, UiStyle.BODY_FONT, Vector2(size.x - 112, 196), t, 34, UiStyle.PAPER, 120, Color(0, 0, 0, 0.85), 6)


## 보스 체력 막대 (보스가 살아 있을 때 화면 위).
func _draw_boss_bar() -> void:
	var b := _boss()
	if b:
		BossBarDrawer.draw(self, b, _boss_chip, size.x, BossBarDrawer.TOP_FREE.y, BossBarDrawer.TOP_FREE.x)  # 단계 눈금·자국·전환 무적


## 내닫기 충전: 먹 붓 고리 칸 (영웅 체력 띠와 같은 먹·금). 찬 칸 = 금빛 번짐이 속을 채움,
## 차는 중 = 고리를 따라 금빛 호가 도는 빈 칸, 빈 칸 = 옅은 먹 고리만.
func _draw_dash_pips() -> void:
	var d := player.dash
	var st := InkUiStyle.default()
	var origin := Vector2(48, size.y - 64)
	for i in d.max_charges:
		var c := origin + Vector2(i * 56, 0)
		var r := st.pip_radius
		if i < d.charges:
			InkPaint.wash(self, c, r * st.pip_fill_scale, st.pip_gold)
			InkPaint.ring(self, c, r, st.pip_ring)
			draw_arc(c, r * 0.9, 0.0, TAU, 24, Color(st.pip_gold, 0.9), 2.0)  # 찼다: 금 테두리가 한 바퀴 닫힘
		else:
			InkPaint.ring(self, c, r, st.pip_empty)
			if i == d.charges:
				draw_arc(c, r * 0.9, -PI / 2, -PI / 2 + TAU * d.get_recharge_ratio(), 24, Color(st.pip_gold, 0.85), 4.0)


func _draw_result() -> void:
	ResultDrawer.draw(self)


func _draw_touch_debug() -> void:
	var t := controller.touch_input
	if t.is_active():
		draw_arc(t.get_anchor(), t.full_speed_radius, 0, TAU, 32, Color(Ink.INK, 0.12), 2.0)
		draw_circle(t.get_anchor(), 6, Color(Ink.INK, 0.25))
		draw_circle(t.get_current(), 10, Color(Ink.INK, 0.3))
	var font := get_theme_default_font()
	var enemies := get_tree().get_nodes_in_group(Enemy.GROUP).size()
	var info := "초당 %d장 · 적 %d" % [Engine.get_frames_per_second(), enemies]
	if controller.dash_note != "":
		_ink_text(font, Vector2(16, size.y - 140), controller.dash_note, HORIZONTAL_ALIGNMENT_LEFT, size.x - 32, 20)
	_ink_text(font, Vector2(16, size.y - 110), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)


## 한지 바탕 위 글자: 먹색 + 종이색 테두리.
func _ink_text(font: Font, pos: Vector2, text: String, align: HorizontalAlignment, width: float, size_px: int) -> void:
	draw_string_outline(font, pos, text, align, width, size_px, 5, Color(Ink.PAPER, 0.9))
	draw_string(font, pos, text, align, width, size_px, Color(Ink.INK, 0.9))


## 경지가 오른 순간 (RunProgress.leveled_up): 고리·도장 번쩍 + "경지 오름" + "패 +1". 싸움은 멈추지 않는다.
func on_level_up(level: int) -> void:
	badge.on_level_up(level)


## 점수가 들어옴 (RunProgress.scored): 띠 반짝, 행동 점수는 작은 글씨.
func on_scored(kind: StringName, amount: int) -> void:
	badge.on_scored(kind, amount)


## 숨 고르기에서 카드를 꺼냄.
func cards_used(_n: int) -> void:
	badge.on_cards_used()
