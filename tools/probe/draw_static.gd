extends SceneTree
## 같은 자리에 적 N명(졸병·철포병·무사 섞어)을 세워 그리기 호출 수를 잰다 (번쩍임 0/일부). 재질·그리기 묶음 비교용.
## godot --path . --resolution 720x1280 -s res://tools/probe/draw_static.gd -- <적 수>
## 결과 줄: DRAWSTATIC n <n> idle <호출> flash_some <호출>


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 22
	var main: Node = await ShotStage.open(self)
	var player := main.get_node("Player") as Player
	player.grant_invulnerability(99999.0)
	for c in ["AutoAttack", "SkillCaster"]:
		var node := player.get_node_or_null(c)
		if node:
			node.set_process(false)
			node.set_physics_process(false)
	var spawner := main.get_node("EnemySpawner") as EnemySpawner
	var kinds := ["waegun_soldier", "waegun_gunner", "waegun_heavy"]
	var es: Array = []
	for i in n:
		var d: EnemyData = load("res://data/enemies/%s.tres" % kinds[i % 3])
		var e := spawner.spawn_at(d, player.global_position + Vector2(-260 + (i % 6) * 105, -520 + (i / 6) * 150))
		e.set_physics_process(false)
		es.append(e)
	for i in 20:
		for e in es:
			e._physics_process(1.0 / 60.0)
		await process_frame
	await RenderingServer.frame_post_draw
	var idle := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	for k in range(0, n, 3):  # 세 명 중 하나씩 맞은 순간
		es[k].health.damage(1)
	for e in es:
		e._physics_process(1.0 / 60.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var fl := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("DRAWSTATIC n %d idle %d flash_some %d" % [n, idle, fl])
	quit()
