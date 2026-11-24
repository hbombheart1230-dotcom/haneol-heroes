extends SceneTree
## 타격 줄기 전/후 확인용: 실제 바닥 위에 1타(왼쪽)·3타(오른쪽) 충격을 한 순간(약 0.06초) 멈춰 찍는다.
## godot --path . --resolution 1080x2400 -s res://tools/shots/hit_streaks_shot.gd -- <hansan|manchuria|gyeongbok|chochung> <출력 png>

const CASES := {
	"hansan": ["hansan_1592", "yi_sun_sin", 1],
	"manchuria": ["manchuria_395", "gwanggaeto", 2],
	"gyeongbok": ["gyeongbokgung_1433", "sejong", 3],
	"chochung": ["chochungdo", "shin_saimdang", 4],
}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var c: Array = CASES[args[0]]
	var st: StageTheme = load("res://data/stages/%s.tres" % c[0])
	var sv := SubViewport.new()  # 창이 화면보다 커지지 않게 별도 1080×2400 화면에 그린다
	sv.size = Vector2i(1080, 2400)
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var arena := ShotStage.backdrop(self, st, true, Vector2(540, 1200))
	arena.reparent(sv, false)
	var hero: HeroData = load("res://data/heroes/%s.tres" % c[1])
	var layer := HitImpactLayer.new()
	sv.add_child(layer)
	seed(7)
	var col := hero.attack.swing_color
	col.a = 1.0
	layer.add(Vector2(300, 1100), Vector2(0.8, -0.6), 1, col)
	layer.add(Vector2(300, 1500), Vector2(0.9, 0.3), 2, col)
	layer.add(Vector2(780, 1200), Vector2(-0.8, -0.5), 3, col, hero.impact_style)
	layer.set_process(false)  # 프레임 시간이 길어 저절로 사라지지 않게 직접 나이를 먹인다
	layer._process(0.06)
	for k in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(args[1])
	quit()
