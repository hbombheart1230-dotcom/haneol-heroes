extends "res://tools/live3d/compare_shot.gd"
## 순신 모든 동작 확인 (구운 그림 ↔ 실시간 3D 나란히): 실제 게임 입력 경로로 낸다.
## 대기(느린 대기) · 탭 연타 1→2→3→넷째 탭 마무리(해룡참) · 대시 연속 두 번(착지 멈춤) · 대시→파도격 ·
## 충전(모으는 자세 → 해일검기) · 회피→반격 · 피격 · 사망.
## compare_shot.gd와 같이 Movie Maker로 찍고 compare_video.py로 구간마다 띠를 만든다:
##   godot --path . --fixed-fps 60 --write-movie <폴더>/f.png -s res://tools/live3d/action_shot.gd -- build/preview/live3d_actions.json
##   python tools/live3d/compare_video.py <폴더> build/preview/live3d_actions.json build/preview/actions


func _sequence(player: Player, atk: AutoAttack, caster: SkillCaster, list: Array) -> void:
	_mark("idle")
	await _frames(90)
	_mark("tap_chain")
	player.facing = Vector2.DOWN
	for i in 6:  # 1·2·3타, 넷째 탭은 3타가 닿은 뒤 마무리 기술 (TapChain)
		caster.combo_tap()
		await _frames(20)
	await _frames(40)
	_mark("chain_dash")
	player.request_dash(Vector2.RIGHT)
	await _frames(14)
	player.request_dash(Vector2.LEFT)  # 연속 대시 (충전 2회)
	await _frames(50)
	_mark("dash_skill")
	player.request_dash(Vector2.RIGHT)
	await _frames(8)
	caster.cast(SkillCaster.Slot.DASH)
	await _frames(60)
	_mark("charge")
	player.facing = Vector2.DOWN
	caster.on_press(0, _now())
	await _frames(70)  # 모으는 자세 (cast_charge 첫 칸에 멈춤)
	caster.on_release(0, _now())
	await _frames(70)
	_mark("counter")
	caster.on_evade()
	caster.cast(SkillCaster.Slot.COUNTER)
	await _frames(60)
	_mark("hit")
	player.apply_hit(1)
	await _frames(55)
	_mark("death")
	player.apply_hit(99999)
	await _frames(90)


func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0
