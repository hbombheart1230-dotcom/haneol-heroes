class_name EnemyLook
extends RefCounted
## 적 스프라이트 잘 보이게 재질 (테두리·밝기·군대 색). EnemyData마다 하나만 만들어 같은 종류가 공유한다.

const SHADER := preload("res://shaders/enemy_rim.gdshader")

static var _cache: Dictionary = {}


## rim_color 알파가 0이면 null (셰이더 없이 원래대로). 정예 변종이면 변종 색 테두리 (조금 더 크게).
static func material_for(d: EnemyData, affix: EliteAffixData = null) -> ShaderMaterial:
	if d == null or d.rim_color.a <= 0.0:
		return null
	var key := d.resource_path if d.resource_path != "" else str(d.get_instance_id())
	if affix:
		key += "+" + String(affix.id)
	if not _cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("rim_color", affix.rim_color if affix else d.rim_color)
		m.set_shader_parameter("rim_width", d.rim_width + (affix.rim_width_add if affix else 0.0))
		m.set_shader_parameter("body_lift", d.body_lift)
		m.set_shader_parameter("body_contrast", d.body_contrast)
		m.set_shader_parameter("army_tint", d.army_tint)
		m.set_shader_parameter("tint_mix", d.tint_mix)
		m.set_shader_parameter("cell_px", float(d.sprite_sheet.frame_size) if d.sprite_sheet else 0.0)
		m.set_shader_parameter("ghost_color", d.ghost_color)
		m.set_shader_parameter("ghost_body_alpha", d.ghost_body_alpha)
		m.set_shader_parameter("ghost_fade", d.ghost_fade)
		_cache[key] = m
	return _cache[key]
