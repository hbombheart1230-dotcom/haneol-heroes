class_name HeroCampaign
extends Resource
## 영웅 하나의 전장 순서 (시간 순). 앞 전장을 이겨야 다음이 열린다. 판 수는 데이터 (지금 셋, 나중에 늘림).

@export var slots: Array[CampaignSlot] = []
## 원정(다른 영웅의 전장)이 열리려면 이겨야 할 자기 전장 수 (앞에서부터). 0 = 만든 자기 전장 모두.
## 아직 없는 무대(곧 열림)는 세지 않는다: 지금은 영웅마다 자기 전장 하나, 셋이 다 만들어지면 셋을 다 이겨야 열린다.
@export var expedition_needs: int = 0


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for s in slots:
		out.append(s.id)
	return out


func has(id: StringName) -> bool:
	return ids().has(id)
