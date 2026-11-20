extends SceneTree
## 영웅 넷의 궁극기 모으기 발밑 표시를 충전 0.3 / 1.0(다 찬 순간 번쩍)으로 찍는다.
## godot --path . --resolution 720x1280 -s res://tools/shots/charge_shot.gd -- <출력 png>

const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]


class Pane extends Node2D:
	var marker: ChargeMarker
	var charge: float = 0.0

	func _draw() -> void:
		marker.draw(self, true, charge)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var bg := ColorRect.new()
	bg.color = Color(0.82, 0.74, 0.6)
	bg.size = Vector2(720, 1280)
	root.add_child(bg)
	for i in HEROES.size():
		var h: HeroData = load("res://data/heroes/%s.tres" % HEROES[i])
		for row in 2:
			var p := Pane.new()
			p.marker = ChargeMarker.new(h.charge_marker)
			p.charge = 0.3 if row == 0 else 1.0
			p.marker._age = 0.7
			if row == 1:
				p.marker._flash_left = h.charge_marker.full_flash_time * 0.5
			p.position = Vector2(180 + (i % 2) * 360, 170 + (i / 2) * 640 + row * 300)
			root.add_child(p)
	for f in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
