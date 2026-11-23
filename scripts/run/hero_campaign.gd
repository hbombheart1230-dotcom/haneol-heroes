class_name HeroCampaign
extends Resource
## 영웅 하나의 전장 순서 (시간 순). 앞 전장을 이겨야 다음이 열린다. 판 수는 데이터 (지금 셋, 나중에 늘림).

@export var slots: Array[CampaignSlot] = []


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for s in slots:
		out.append(s.id)
	return out


func has(id: StringName) -> bool:
	return ids().has(id)
