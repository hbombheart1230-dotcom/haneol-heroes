class_name TelegraphPerf
extends RefCounted
## 적 예고 그리기 비용 재기 (tools/shots/telegraph_looks.gd가 HH_PERF=1일 때 부른다, HH_CROWD=1과 함께 쓰면 붐비는 판):
## 같은 장면에서 예고 없음 / (가) 지금 / (바) 먹 붓 테 + 먹 번짐을 차례로 frames 프레임씩, 매 프레임 진행을 바꿔 다시 그리게 하고
## 그리기 호출 수(RENDER_TOTAL_DRAW_CALLS_IN_FRAME)와 프레임 시간을 낸다. 끝 0.15초(치기 직전 낙관·짙은 선)도 들어간다.
## 결과 줄: TLPERF <이름> frames <n> draws <평균> frame_ms <평균> p99_ms <ms> process_ms <평균> telegraphs <n>
## godot --path . --resolution 720x1280 -s res://tools/shots/telegraph_looks.gd -- hansan_1592 x.png  (HH_PERF=1 HH_CROWD=1)

const FRAMES := 300
const CASES := [["none", []], ["look0_now", [0, 0.3, 0.7]], ["look1_brush", [1, 0.3, 0.7]]]


static func run(tool: SceneTree) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var n := 0
	for f in tool.get("foes"):
		if f[1] != null:
			n += 1
	for c in CASES:
		for i in 30:  # 바꾼 뒤 자리 잡기
			tool.call("arm", c[1], 0.5)
			await tool.process_frame
		var ms := PackedFloat32Array()
		var draws := 0.0
		var proc := 0.0
		for i in FRAMES:
			var t0 := Time.get_ticks_usec()
			tool.call("arm", c[1], fmod(float(i) / 120.0, 1.0))  # 진행 0→1을 되풀이 (끝에서 낙관)
			await tool.process_frame
			ms.append((Time.get_ticks_usec() - t0) / 1000.0)
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var sorted := ms.duplicate()
		sorted.sort()
		var avg := 0.0
		for x in ms:
			avg += x
		print("TLPERF %s frames %d draws %.1f frame_ms %.2f p99_ms %.2f process_ms %.2f telegraphs %d" % [c[0], FRAMES,
			draws / FRAMES, avg / FRAMES, sorted[int(FRAMES * 0.99)], proc / FRAMES, 0 if c[1].is_empty() else n])
