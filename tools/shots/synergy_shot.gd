extends SceneTree
## 패 짝 견본 사진 (1080×1920): 순신 "젖은 바다" — 파도격에 젖은 적(젖음), 해일검기가 더 세게 (물먹은 적).
## 짝 없음/있음 두 판에서 해일검기 한 번이 넣은 피해 합도 찍어 낸다.
## godot --path . -s res://tools/shots/synergy_shot.gd -- <출력 폴더>

const SOLDIER := preload("res://data/enemies/waegun_soldier.tres")

var out := "user://synergy"
var sv: SubViewport
var cur: Node


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if not a.is_empty():
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	sv = SubViewport.new()
	sv.size = Vector2i(1080, 1920)
	sv.size_2d_override = Vector2i(720, 1280)
	sv.size_2d_override_stretch = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	_run()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _pick(m: Node, id: StringName) -> UpgradeDef:
	for u in m.build.hero.upgrade_pool.upgrades:
		if u.id == id:
			return u
	return null


## 순신 판 하나: 두 패를 고른 채로 (with_synergy가 false면 짝만 끈다). 파도격 → 해일검기 순으로 쏘고 해일검기 피해 합을 돌려준다.
func _round(with_synergy: bool, tag: String) -> int:
	if cur:
		paused = false
		cur.free()
	cur = load("res://scenes/main.tscn").instantiate()
	sv.add_child(cur)
	await _wait(5)
	var m := cur
	m.player.health.damageable = false
	m.state.elapsed = 5.0
	m.spawner.set_process(false)
	m.spawner.set_physics_process(false)
	m.build.apply(_pick(m, &"pado_more"))  # 두 판 다 같은 패 (짝 효과만 비교)
	m.build.apply(_pick(m, &"haeil_big"))
	if not with_synergy:
		SynergyState.reset()
	var p: Vector2 = m.player.global_position
	var foes: Array[Enemy] = []
	for i in 5:
		var e: Enemy = m.spawner.spawn_at(SOLDIER, p + Vector2(110 + i * 55, -30 + (i % 2) * 60))
		e.health.max = 9999
		e.health.current = 9999
		e.set_physics_process(false)
		foes.append(e)
	m.player.facing = Vector2.RIGHT
	var caster: SkillCaster = m.player.get_node("SkillCaster")
	caster.cast(SkillCaster.Slot.DASH)
	await _wait(18)
	if with_synergy:
		await _shot(tag + "_1_wet")
	var hp := 0
	for e in foes:
		hp += e.health.current
	caster.cast(SkillCaster.Slot.CHARGE, 1.0)
	await _wait(14)
	if with_synergy:
		await _shot(tag + "_2_haeil")
	await _wait(90)
	var after := 0
	for e in foes:
		after += e.health.current if is_instance_valid(e) else 0
	return hp - after


func _run() -> void:
	GameSettings.settings_path = GameSettings.test_path()
	GameSettings.opening_seen = true
	GameSettings.title_seen = true
	GameSettings.hero_picked = true
	GameSettings.want_stage_list = false
	GameSettings.story_enabled = false
	GameSettings.tutorial_enabled = false
	GameSettings.tutorial_done = true
	GameSettings.hero_id = &"yi_sun_sin"
	GameSettings.stage_picked = false
	GameSettings.save_settings()
	var plain := await _round(false, "plain")
	var wet := await _round(true, "wet")
	print("haeil_total plain=%d wet=%d ratio=%.2f" % [plain, wet, float(wet) / maxf(plain, 1.0)])
	quit()
