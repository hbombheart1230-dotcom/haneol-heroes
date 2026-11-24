extends SceneTree
## 영웅 화면 키 재기 (몸 키: 머리 끝 뼈 ~ 발 뼈를 카메라로 화면에 옮긴 거리, 무기·깃털 제외)
## × sprite_scale × 무대 확대 ÷ 화면 높이 1280. 참고로 불투명 높이(무기·깃털 포함)도 구운 그림·3D 둘 다. 창 모드: godot --path . -s res://tools/live3d/hero_heights.gd [-- 확대=1.09]
## 결과: HEIGHT <영웅> baked <%> live <%> scale <sprite_scale>

const PlayerView3D := preload("res://scripts/player/player_view_3d.gd")
const Rig := preload("res://scripts/art/live3d/live3d_rig.gd")
const HEROES := ["yi_sun_sin", "gwanggaeto", "shin_saimdang", "sejong"]


func _initialize() -> void:
	_run()


func _run() -> void:
	var zoom := float(OS.get_cmdline_user_args()[0]) if not OS.get_cmdline_user_args().is_empty() else 1.09
	for id in HEROES:
		var hero: HeroData = load("res://data/heroes/%s.tres" % id)
		var sheet := hero.sprite_sheet
		var i := sheet.anim_names.find("idle")
		var img := (sheet.textures[i] as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		var cell := img.get_region(Rect2i(0, 2 * sheet.frame_size, sheet.frame_size, sheet.frame_size))
		var baked := _opaque_height(cell)
		var live := -1.0
		var body := -1.0
		var path := PlayerView3D.data_path(StringName(id))
		if ResourceLoader.exists(path):
			var r: Node = Rig.new()
			root.add_child(r)
			r.setup(load(path), PlayerView3D.durations(sheet))
			r.play_body("idle", true, 0.0, 0.0)
			for k in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			live = _opaque_height(r.viewport.get_texture().get_image())
			body = _body_px(r)
			r.queue_free()
		var k := hero.sprite_scale * zoom / 1280.0 * 100.0
		print("HEIGHT %s body %.1f%% (px %.0f) | opaque baked %.1f%% live %.1f%% | scale %.3f offset %s" % [id,
			body * k, body, baked * k, live * k, hero.sprite_scale, hero.sprite_offset])
	quit()


## 머리 끝(head_end) ~ 낮은 발(발가락) 뼈의 화면 거리 (px, 3D 화면 기준).
static func _body_px(r: Node) -> float:
	var sk := (r.get("pivot") as Node3D).find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var cam: Camera3D = (r.get("viewport") as SubViewport).get_camera_3d()
	var top: Vector2 = cam.unproject_position(sk.global_transform * sk.get_bone_global_pose(sk.find_bone("head_end")).origin)
	var low := 0.0
	for b in ["LeftToeBase", "RightToeBase", "LeftFoot", "RightFoot"]:
		low = maxf(low, cam.unproject_position(sk.global_transform * sk.get_bone_global_pose(sk.find_bone(b)).origin).y)
	return low - top.y


## 불투명 픽셀이 있는 행의 위아래 거리 (px).
static func _opaque_height(img: Image) -> float:
	img.convert(Image.FORMAT_RGBA8)
	var top := -1
	var bottom := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				if top < 0:
					top = y
				bottom = y
				break
	return float(bottom - top + 1) if top >= 0 else 0.0
