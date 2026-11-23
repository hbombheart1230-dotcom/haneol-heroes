class_name HeroContact
extends RefCounted
## 접점 시각 공통 인터페이스 (무기가 몹에 박히는 느낌): 공격 클립이 시작된 뒤 칼이 몹 몸에 처음 겹치는 시각(초, 재생 배율 1).
## 2D 구운 그림 = SheetContact (시트 맞닿는 칸 ÷ fps, 데이터 덮어쓰기), 3D 실시간 = 칼끝 뼈 위치로 (3D 영웅 그림이 채운다).
## Player.contact에 그림 쪽이 넣는다. 모르면 -1 (AutoAttack은 예전 지연을 쓴다).


func contact_time(_anim: StringName) -> float:
	return -1.0
