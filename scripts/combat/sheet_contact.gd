class_name SheetContact
extends HeroContact
## 2D 구운 그림의 접점 시각: BladeBiteData.clip_contact에 있으면 그 값, 없으면 시트 맞닿는 칸(strike_frames) ÷ fps.

var sheet: SpriteSheetSet
var overrides: Dictionary = {}


func _init(p_sheet: SpriteSheetSet = null, p_overrides: Dictionary = {}) -> void:
	sheet = p_sheet
	overrides = p_overrides


func contact_time(anim: StringName) -> float:
	if overrides.has(anim):
		return float(overrides[anim])
	if sheet == null or not sheet.has_anim(String(anim)):
		return -1.0
	var i := sheet.anim_names.find(String(anim))
	return sheet.strike_frame(String(anim)) / maxf(sheet.fps[i], 1.0)
