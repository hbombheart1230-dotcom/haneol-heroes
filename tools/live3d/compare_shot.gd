extends SceneTree
## 구운 그림 ↔ 실시간 3D 나란히 비교 (시험): 실제 main 장면(순신 · 한산)에서 영웅 하나에 그림 두 개를 붙인다.
## 왼쪽 = 지금 PlayerView (구운 8방향 칸), 오른쪽 = PlayerView3D (실시간 3D). 같은 영웅 상태·같은 입력을 읽는다.
## Movie Maker(고정 60fps)로 찍는다. 창 크기 덮어쓰기(405x720) 대신 720x1280으로 찍으려면 프로젝트 폴더에 잠깐
## override.cfg ([display] window/size/window_width_override=720, window_height_override=1280)를 두고 찍은 뒤 지운다.
##   godot --path . --resolution 720x1280 --fixed-fps 60 --write-movie build/preview/live3d_frames/f.png
##     -s res://tools/live3d/compare_shot.gd -- build/preview/live3d_marks.json
## 그다음 python tools/live3d/compare_video.py 가 잘라서 mp4·프레임 띠를 만든다.

const GAP := 105.0
var _frame: int = 0
var _marks: Dictionary = {}


func _initialize() -> void:
	_run()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://marks.json"
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.stage_picked = true
	GameSettings.stage_id = &"hansan_1592"
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.tutorial_done = true
	GameSettings.tutorial_enabled = false
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.story_enabled = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var player := main.get_node("Player") as Player
	var baked := player.get_node("PlayerView") as Node2D
	baked.position = Vector2(-GAP, 0)
	var live := Node2D.new()
	live.set_script(load("res://scripts/player/player_view_3d.gd"))
	live.name = "PlayerView3D"
	live.position = Vector2(GAP, 0)
	player.add_child(live)
	_label(baked, "구운 그림 (지금)")
	_label(live, "실시간 3D")
	await _frames(10)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	spawner.active = false
	var atk := player.get_node("AutoAttack") as AutoAttack
	var caster := player.get_node("SkillCaster") as SkillCaster
	var soldier: EnemyData = load("res://data/enemies/waegun_soldier.tres")
	var list: Array = []
	for i in 3:
		var e := spawner.spawn_at(soldier, player.global_position + Vector2(-70.0 + 70.0 * i, 230.0))
		e.health.max = 9999
		e.health.current = 9999
		e.process_mode = Node.PROCESS_MODE_DISABLED  # 제자리에 세워 두기 (때리지 않게)
		list.append(e)
	player.facing = Vector2.DOWN
	await _frames(190)  # 무대 제목 띠가 사라질 때까지
	_mark("idle")
	await _frames(70)
	_mark("combo")
	player.facing = Vector2.DOWN
	atk.manual_strike(1, false, list)
	await _frames(17)
	atk.manual_strike(2, false, list)
	await _frames(18)
	atk.manual_strike(3, false, list)
	await _frames(30)
	_mark("haeryong")
	caster.cast(SkillCaster.Slot.TAP)
	await _frames(55)
	_mark("dash")
	player.facing = Vector2.RIGHT
	player.request_dash(Vector2.RIGHT)
	await _frames(9)
	caster.cast(SkillCaster.Slot.DASH)
	await _frames(55)
	_mark("hit")
	player.apply_hit(1)
	await _frames(55)
	_mark("run_attack")
	for f in 110:  # 달리며 평타 (적 앞을 좌우로): 구운 그림은 다리만, 실시간은 윗몸 공격 + 다리 달리기
		player.set_move_input(Vector2.LEFT if f < 55 else Vector2.RIGHT)
		if f % 22 == 0:
			atk.manual_strike(1 + (f / 22) % 3, false, list)
		await _frames(1)
	player.set_move_input(Vector2.ZERO)
	await _frames(30)
	_mark("run")
	for f in 150:  # 달리며 방향 바꾸기: 한 바퀴 반 원을 그리며
		player.set_move_input(Vector2.from_angle(f / 150.0 * TAU * 1.5))
		await _frames(1)
	player.set_move_input(Vector2.ZERO)
	await _frames(35)
	_mark("end")
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(_marks))
	f.close()
	quit()


func _label(parent: Node2D, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.position = Vector2(-80, -205)
	l.size = Vector2(160, 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)


func _mark(n: String) -> void:
	_marks[n] = _frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		_frame += 1
