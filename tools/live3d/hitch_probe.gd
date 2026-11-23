extends SceneTree
## 첫 등장 멈칫 재기: 실제 main 장면(순신 · 한산)을 띄우고 프레임 시간을 기록한다.
## 구간: 장면 넣기(불러오기) → 처음 6초 → 동작마다 처음 쓰는 순간 (연타 1·2·3, 해룡참, 대시+파도격, 충전, 피격, 반격).
## 창 모드, 수직 동기 끔: godot --path . -s res://tools/live3d/hitch_probe.gd
## 3D와 구운 그림 비교는 override.cfg의 [hh] art/live3d로 바꿔 두 번 돌린다.
## 결과: HITCH {"load_ms":..., "first6s_max_ms":..., "events": {이름: 그 뒤 20프레임 최대 ms}, "over_50ms": n}

var _times: PackedFloat32Array = PackedFloat32Array()
var _prev: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
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
	var t0 := Time.get_ticks_usec()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var load_ms := (Time.get_ticks_usec() - t0) / 1000.0
	_prev = Time.get_ticks_usec()
	var first := await _frames(360)
	var player := main.get_node("Player") as Player
	var atk := player.get_node("AutoAttack") as AutoAttack
	var caster := player.get_node("SkillCaster") as SkillCaster
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	spawner.active = false
	var ev := {}
	atk.manual_strike(1, false)
	ev["attack1"] = await _frames(20)
	atk.manual_strike(2, false)
	ev["attack2"] = await _frames(20)
	atk.manual_strike(3, false)
	ev["attack3"] = await _frames(30)
	caster.cast(SkillCaster.Slot.TAP)
	ev["skill_tap"] = await _frames(40)
	player.request_dash(Vector2.RIGHT)
	caster.cast(SkillCaster.Slot.DASH)
	ev["dash_skill"] = await _frames(40)
	caster.cast(SkillCaster.Slot.CHARGE, 1.0)
	ev["skill_charge"] = await _frames(40)
	player.grant_invulnerability(0.0)
	player.apply_hit(1)
	ev["hit"] = await _frames(30)
	caster.cast(SkillCaster.Slot.COUNTER)
	ev["skill_counter"] = await _frames(40)
	var over := 0
	for t in _times:
		if t > 50.0:
			over += 1
	var view := player.get_node("PlayerView")
	print("HITCH ", JSON.stringify({"live3d": view.get("rig") != null, "load_ms": load_ms, "first6s_max_ms": first,
		"events": ev, "over_50ms": over, "frames": _times.size()}))
	quit()


## n프레임 진행하며 그 동안의 최대 프레임 시간(ms).
func _frames(n: int) -> float:
	var worst := 0.0
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - _prev) / 1000.0
		_prev = now
		_times.append(dt)
		worst = maxf(worst, dt)
	return worst
