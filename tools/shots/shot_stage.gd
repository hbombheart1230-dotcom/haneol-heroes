class_name ShotStage
extends RefCounted
## 장면 도구 공통: 실제 main 장면(한산, 순신)을 띄워 진짜 바닥(floor_grade·비네트·빛 웅덩이·줌)에서 찍는다.
## 원본 배경 그림을 그대로 깔면 실제보다 훨씬 밝게 찍혀 비교가 틀어진다.


## 시작 화면·이야기·안내를 건너뛰는 설정 (main 장면을 만들기 전에).
static func skip_menus(stage: StringName = &"hansan_1592", hero: StringName = &"yi_sun_sin") -> void:
	GameSettings.title_seen = true
	GameSettings.intro_seen = true
	GameSettings.seen_stories = PackedStringArray(["gwanggaeto", "sejong", "shin_saimdang", "yi_sun_sin"])
	GameSettings.stage_picked = true
	GameSettings.stage_id = stage
	GameSettings.hero_id = hero
	GameSettings.tutorial_done = true
	GameSettings.tutorial_enabled = false
	GameSettings.hero_picked = true
	GameSettings.opening_seen = true
	GameSettings.story_enabled = false


## main 장면을 붙이고 적 생성을 멈춘다 (몇 프레임 기다린 뒤 돌려준다).
static func open(tree: SceneTree, stage: StringName = &"hansan_1592", hero: StringName = &"yi_sun_sin") -> Node:
	skip_menus(stage, hero)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	for i in 10:
		await tree.process_frame
	(main.get_node("EnemySpawner") as EnemySpawner).active = false
	return main


## 영웅을 at으로 옮기고 카메라를 바로 따라 붙인다.
static func move_hero(main: Node, at: Vector2) -> void:
	var p := main.get_node("Player") as Player
	p.global_position = at
	var cam := p.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.reset_smoothing()


## 화톳불 빛 웅덩이 중심 (영웅 시작점에서 가장 가까운 것). 없으면 시작점.
static func brazier_spot(main: Node) -> Vector2:
	var arena := main.get_node("Arena") as Arena
	var from := (main.get_node("Player") as Node2D).global_position
	var best := from
	var best_d := INF
	if arena.lights and arena.lights.look:
		for p in arena.lights.pools:
			if p[2] == arena.lights.look.prop_light_color and (p[0] as Vector2).distance_to(from) < best_d:
				best_d = (p[0] as Vector2).distance_to(from)
				best = p[0]
	return best


## 빛 웅덩이에서 가장 먼 어두운 자리 (경기장 안쪽 margin px).
static func dark_spot(main: Node, margin: float = 420.0) -> Vector2:
	return _darkest(main.get_node("Arena") as Arena, margin)


## 화면 좌표(720×1280)로 그림을 늘어놓는 도구용 진짜 바닥: Arena(지도·floor_grade·빛 웅덩이·소품·비네트)를
## 무대 확대(camera_zoom)로 깔고, lit이면 화톳불 빛 웅덩이를, 아니면 가장 어두운 자리를 화면 가운데로.
## 원본 배경 그림을 그대로 까는 것보다 실제 화면과 같은 밝기로 찍힌다. root에 맨 먼저 붙인다.
static func backdrop(tree: SceneTree, stage: StageTheme, lit: bool = true, screen := Vector2(360, 640)) -> Arena:
	var arena := Arena.new()
	arena.rect = Rect2(-900, -1400, 1800, 2800)  # main.tscn 과 같게
	arena.theme = stage
	tree.root.add_child(arena)
	var spot := arena.map.rect.get_center() if arena.has_map() else Vector2.ZERO
	if arena.lights and arena.lights.look:
		var lit_pools := arena.lights.pools.filter(func(p: Array) -> bool:
			return p[2] == arena.lights.look.prop_light_color)
		if lit and not lit_pools.is_empty():
			spot = lit_pools.reduce(func(a: Array, b: Array) -> Array:
				return a if (a[0] as Vector2).length() < (b[0] as Vector2).length() else b)[0]
		elif not lit:
			spot = _darkest(arena, 700.0)
	var zoom := arena.theme.camera_zoom
	arena.scale = Vector2(zoom, zoom)
	arena.position = screen - spot * zoom
	return arena


static func _darkest(arena: Arena, margin: float) -> Vector2:
	var r := arena.rect.grow(-margin)
	var best := r.get_center()
	var best_d := -1.0
	for i in 13:
		for j in 21:
			var q := r.position + r.size * Vector2(i / 12.0, j / 20.0)
			var d := INF
			for p in (arena.lights.pools if arena.lights else []):
				d = minf(d, q.distance_to(p[0]) - float(p[1]))
			if d > best_d:
				best_d = d
				best = q
	return best
