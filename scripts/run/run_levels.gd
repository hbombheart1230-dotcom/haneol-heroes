class_name RunLevels
extends RefCounted
## 판 안 레벨 (Main에서 나눔): 점수 수집(ScoreFeed) → 레벨업 순간 능력치·기술 모습 단계 → 카드 1장 적립,
## 숨 고르기에서 적립 카드를 LevelRules.plan대로 고른다 (한 번에 최대 2번, 넘치면 합쳐 여러 단계, 보스 직전엔 전부).
## 싸움은 멈추지 않는다: 레벨업은 HUD 연출만 (Hud.on_level_up). 저장하지 않는다.

var main: Node
var feed: ScoreFeed
## 이번 숨 고르기에 남은 고르기마다 오르는 단계 수 (앞에서부터 쓴다).
var gains: Array[int] = []


func _init(p_main: Node) -> void:
	main = p_main
	var cfg: RunConfig = main.run_config
	feed = ScoreFeed.new(main.progress, cfg.score if cfg else null)
	feed.clock = func() -> float: return main.state.elapsed if main.state else 0.0
	feed.active = func() -> bool: return main.state != null and main.state.is_playing()
	main.progress.leveled_up.connect(_on_level_up)


func rules() -> LevelRules:
	return main.progress.rules()


## 판 시작 (영웅 사본이 생긴 뒤): 행동 신호를 잇는다.
func begin() -> void:
	var p: Player = main.player
	feed.connect_to(p, p.get_node_or_null("SkillCaster") as SkillCaster if p else null)


func on_kill(e: Enemy, stage_mult: float) -> void:
	feed.kill(e, stage_mult)


func _on_level_up(level: int) -> void:
	var r := rules()
	var b: RunBuild = main.build
	if r == null or b == null or b.hero == null:
		return
	if r.grants_stats(level) and b.hero.level_up:
		b.apply(b.hero.level_up)
	b.set_level_vfx(r.vfx_bonus(level))
	if Feedback.instance:
		Feedback.instance.play(&"magic")
		Feedback.instance.haptic(40, 0.6)


## 숨 고르기 하나의 고르기 계획을 세운다. 반환: 고르기 횟수. last = 보스 직전 숨 고르기.
func plan_break(last: bool) -> int:
	feed.new_wave()
	var r := rules()
	if r == null:
		gains = []
		return 1
	gains = r.plan(main.progress.pending, last)
	main.progress.pending = maxi(main.progress.pending - LevelRules.used(gains), 0)
	return gains.size()


## 지금 고르기가 올리는 단계 수 (계획이 없으면 무대 기본값 fallback).
func current_gain(fallback: int) -> int:
	return gains[0] if not gains.is_empty() else fallback


## 고르기 하나를 마쳤다.
func consume() -> void:
	if not gains.is_empty():
		gains.pop_front()
