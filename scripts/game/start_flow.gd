class_name StartFlow
extends RefCounted
## 판을 시작하기 전 화면들의 순서 (Main에서 분리):
## 입장(앱 켠 뒤 한 번) → 공통 이야기(입장 직후) → 영웅 고르기(필요할 때)
## → 그 영웅 이야기(고르기 화면에서 고른 직후) → [시험판: 전장 고르기] → 판 시작 (Main.begin_run).
## 이야기는 지금 매번 나온다 (GameSettings.story_once를 켜면 한 번 본 것은 건너뜀). 다시 시작(같은 영웅)은 건너뜀.
## 화면이 떠 있는 동안 게임은 멈춘다 (Main.waiting_pick).

var main: Node
## 공통 이야기 (StoryIntro에 처음 붙어 있던 데이터). 영웅 이야기를 연 뒤에도 남게 따로 둔다.
var prologue: IntroData
## 입장 직후 공통 이야기, 영웅을 고른 직후 그 영웅 이야기를 보여 줄 차례인지.
var prologue_pending := false
var hero_story_pending := false


func _init(m: Node) -> void:
	main = m
	if main.story_intro:
		prologue = main.story_intro.data


func next() -> void:
	var player: Player = main.player
	if main.title_screen and not GameSettings.title_seen:
		_hold()
		main.title_screen.entered.connect(_on_title_entered, CONNECT_ONE_SHOT)
		main.title_screen.open()
	elif prologue_pending and main.story_intro and prologue:
		prologue_pending = false
		_hold()
		main.story_intro.finished.connect(_on_prologue_finished, CONNECT_ONE_SHOT)
		main.story_intro.open(prologue)
	elif main.playable_heroes().size() > 1 and not GameSettings.hero_picked and main.hero_select:
		_hold()
		main.hero_select.picked.connect(_on_hero_picked, CONNECT_ONE_SHOT)
		main.hero_select.open(main.heroes)
	elif main.story_intro and pending_hero_story():
		hero_story_pending = false
		_hold()
		main.story_intro.finished.connect(_on_hero_story_finished.bind(player.hero.id), CONNECT_ONE_SHOT)
		main.story_intro.open(player.hero.story)
	elif main.stages.size() > 1 and not GameSettings.stage_picked and main.stage_select \
			and GameSettings.unlock_all_stages():
		# 시험판만: 아무 무대나 골라 시험. 정식판은 영웅의 무대 순서대로 바로 간다.
		_hold()
		main.stage_select.picked.connect(_on_stage_picked, CONNECT_ONE_SHOT)
		main.stage_select.open(main.stages, StageUnlock.flags(main.stages, GameSettings.cleared_stages, true))
	else:
		main.begin_run()


## 방금 고른 영웅의 이야기를 보여 줄 차례면 true.
func pending_hero_story() -> bool:
	var player: Player = main.player
	if not hero_story_pending or player == null or player.hero == null or player.hero.story == null:
		return false
	return GameSettings.should_show_story(GameSettings.seen_stories.has(String(player.hero.id)))


func _hold() -> void:
	main.waiting_pick = true
	main.get_tree().paused = true


func _on_title_entered() -> void:
	Feedback.ui()
	GameSettings.title_seen = true
	prologue_pending = GameSettings.should_show_story(GameSettings.intro_seen)
	next()


func _on_prologue_finished() -> void:
	GameSettings.intro_seen = true
	GameSettings.save_settings()
	next()


func _on_hero_picked(h: HeroData) -> void:
	Feedback.ui()
	GameSettings.hero_id = h.id
	GameSettings.hero_picked = true
	hero_story_pending = true
	GameSettings.save_settings()
	var player: Player = main.player
	if player and h != player.hero:
		player.change_hero(h)
	next()


func _on_hero_story_finished(hero_id: StringName) -> void:
	if not GameSettings.seen_stories.has(String(hero_id)):
		GameSettings.seen_stories.append(String(hero_id))
	GameSettings.save_settings()
	next()


func _on_stage_picked(st: StageTheme) -> void:
	Feedback.ui()
	GameSettings.stage_id = st.id
	GameSettings.stage_picked = true
	var player: Player = main.player
	if player and player.hero:
		GameSettings.hero_stages[String(player.hero.id)] = String(st.id)
	GameSettings.save_settings()
	next()
