class_name SynergyDef
extends Resource
## 강화 패 짝 (맞물림): needs의 패를 모두 가지면 effect가 켜진다 (그 판 동안). 영웅의 UpgradePool.synergies에 둔다.
## 효과 수치는 effect 데이터에. 영웅·짝이 늘어도 데이터만 더한다 (docs/research/upgrade_synergies.md).

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
## 둘 다(모두) 가져야 하는 패 (UpgradeDef.id).
@export var needs: Array[StringName] = []
@export var effect: SynergyEffect


## 고른 패(id → 횟수)로 짝이 맞았는지.
func met(stacks: Dictionary) -> bool:
	if needs.is_empty() or effect == null:
		return false
	for n in needs:
		if int(stacks.get(n, 0)) <= 0:
			return false
	return true
