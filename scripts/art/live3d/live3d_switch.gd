extends Node
## 그림 방식 켜고 끄기 (실시간 3D 시험, docs/research/live3d_spike.md).
## 프로젝트 설정 hh/art/live3d = true면 장면에 들어오는 PlayerView를 PlayerView3D로 바꾼다 (기본 false = 구운 그림).
## 3D를 끈 엔진(커스텀 안드로이드 템플릿)에서는 켜도 아무것도 하지 않는다. 이 파일은 3D 클래스를 쓰지 않는다.

const SETTING := "hh/art/live3d"
const VIEW_2D := "res://scripts/player/player_view.gd"
const VIEW_3D := "res://scripts/player/player_view_3d.gd"


static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING, false)) and ClassDB.class_exists(&"Camera3D")


func _enter_tree() -> void:
	if enabled():
		get_tree().node_added.connect(_on_node_added)


## _ready 전(트리에 들어오는 순간)에 스크립트를 바꾼다. 영웅별 설정이 없으면 PlayerView3D가 구운 그림 그대로 그린다.
func _on_node_added(n: Node) -> void:
	var s := n.get_script() as Script
	if s and s.resource_path == VIEW_2D:
		n.set_script(load(VIEW_3D))
