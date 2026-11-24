extends SceneTree
## 단순 도형 훑기 2차 확인용: 바꾼 도형의 이전(위, 엔진 기본 호·원) / 이후(아래, 붓 결)를 어두운·밝은 바닥에서 나란히.
## godot --path . -s res://tools/shots/shapes2_shot.gd -- <출력 png>

class Board:
	extends Node2D
	var after := false
	var base := Color(0.1, 0.16, 0.24)

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 900, 300), base)
		var gold := Color(0.94, 0.74, 0.28)
		var cy := 150.0
		# 기절 고리 · 모으기 호 · 웅덩이 호
		if after:
			InkPaint.arc(self, Vector2(90, cy), 40.0, 0.5, 0.5 + PI * 1.3, 7.0, Color(1.0, 0.9, 0.3, 0.95))
			InkPaint.arc(self, Vector2(240, cy), 56.0, -PI / 2, -PI / 2 + TAU * 0.7, 9.0, Color(0.4, 0.8, 1.0, 0.9), 24)
			InkPaint.arc(self, Vector2(400, cy), 70.0, 0.3, 0.3 + PI * 0.9, 14.0, Color(0.4, 0.9, 0.5, 0.6))
			InkPaint.ring(self, Vector2(540, cy), 50.0, Color(gold, 0.8))
			for i in 4:  # 모으기 마디
				var at := Vector2(650 + i * 36, cy)
				if i < 2:
					InkPaint.wash(self, at, 11.0, Color(0.95, 0.85, 0.5))
				else:
					InkPaint.ring(self, at, 11.0, Color(0.9, 0.85, 0.7, 0.8))
			InkPaint.wash(self, Vector2(820, cy), 55.0, Color(0.55, 0.9, 0.5, 0.4))
		else:
			draw_arc(Vector2(90, cy), 40.0, 0.5, 0.5 + PI * 1.3, 12, Color(1.0, 0.9, 0.3, 0.9), 3.0)
			draw_arc(Vector2(240, cy), 56.0, -PI / 2, -PI / 2 + TAU * 0.7, 32, Color(0.4, 0.8, 1.0, 0.9), 5.0)
			draw_arc(Vector2(400, cy), 70.0, 0.3, 0.3 + PI * 0.9, 24, Color(0.4, 0.9, 0.5, 0.55), 6.0)
			draw_arc(Vector2(540, cy), 50.0, 0.0, TAU, 40, Color(gold, 0.8), 5.0)
			for i in 4:
				var at := Vector2(650 + i * 36, cy)
				draw_circle(at, 13.0, Color(0.09, 0.09, 0.11, 0.6))
				if i < 2:
					draw_circle(at, 11.0, Color(0.95, 0.85, 0.5))
				else:
					draw_arc(at, 10.0, 0.0, TAU, 12, Color(0.9, 0.85, 0.7, 0.8), 2.0)
			draw_circle(Vector2(820, cy), 55.0, Color(0.55, 0.9, 0.5, 0.28))


func _initialize() -> void:
	_run()


func _run() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(900, 1200)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var k := 0
	for after in [false, true]:
		for base in [Color(0.1, 0.16, 0.24), Color(0.86, 0.74, 0.55)]:
			var b := Board.new()
			b.after = after
			b.base = base
			b.position = Vector2(0, 300 * k)
			sv.add_child(b)
			k += 1
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	sv.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
