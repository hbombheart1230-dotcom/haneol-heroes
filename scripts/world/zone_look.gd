class_name ZoneLook
extends RefCounted
## 구역 바닥 입히기 (ZoneHop, 한산 판옥선 → 중형선 → 대장선): 구역마다 다른 배 그림, 소품 켜고 끄기, 막는 것, 빛 웅덩이.
## 같은 전장 영역(StageTheme.background_rect)에 그린 배 그림을 바꿔 끼운다 (바닥 결·먹선은 무대 StageLook 그대로).


static func apply(arena: Arena, z: ZoneData, st: StageTheme) -> void:
	if arena == null or z == null or st == null:
		return
	var path := z.background_path if z.background_path != "" else st.background_path
	if arena.map and path != "" and ResourceLoader.exists(path):
		arena.map.texture = load(path) as Texture2D
		arena.map.queue_redraw()
	if arena.props:
		arena.props.visible = z.props
	var items: Array = arena.props.items if arena.props and z.props else []
	if arena.obstacles:
		var list := (st.map_blockers if z.background_path == "" else z.blockers).duplicate()
		if z.props and arena.props:
			list.append_array(Obstacles.from_props(arena.props.items, st))
		arena.obstacles.build(list)
	if arena.lights and arena.map:
		arena.lights.setup(st.look, arena.map.rect, items, st.prop_textures, st.seed)
