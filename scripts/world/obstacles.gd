class_name Obstacles
extends Node2D
## 막히는 장애물: 원 모양 StaticBody2D들 (물리 5번 "obstacle" 층). 영웅·적이 부딪혀 미끄러져 돈다.
## 무대마다 다시 만든다: 지도에 그려진 것(StageTheme.map_blockers) + 흩뿌린 큰 소품(StageTheme.solid_props).

const LAYER := 16  # 5번 층
const GROUP := &"obstacle"

## 지금 놓인 원들 (x, y, 반지름) — 테스트·다른 배치(물건 놓기)가 피할 때 쓴다.
var circles: PackedVector3Array = PackedVector3Array()


func build(list: PackedVector3Array) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	circles = list
	for c in list:
		var body := StaticBody2D.new()
		body.collision_layer = LAYER
		body.collision_mask = 0
		body.position = Vector2(c.x, c.y)
		body.add_to_group(GROUP)
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = c.z
		shape.shape = circle
		body.add_child(shape)
		add_child(body)


## 흩뿌린 소품 중 막히는 것의 발밑 원. items = StageProps.scatter 결과 [위치, 종류, 배율, 그림 번호].
static func from_props(items: Array, t: StageTheme) -> PackedVector3Array:
	var out := PackedVector3Array()
	for it in items:
		if it[1] != 2:
			continue
		var tex: Texture2D = t.prop_textures[it[3]]
		if tex == null or not t.solid_props.has(tex.resource_path.get_file().get_basename()):
			continue
		var size: Vector2 = tex.get_size() * float(it[2])
		var p: Vector2 = it[0]
		out.append(Vector3(p.x, p.y - size.y * 0.06, size.x * 0.3))
	return out


## 장애물에 막힌 추격 방향을 가장자리를 따라 돌게 바꾼다: 벽 법선의 접선 쪽(목표에 가까운 방향)으로.
## side는 정면으로 막혀 좌우가 같을 때 고를 쪽 (+1/-1, 적마다 고정).
static func steer_around(chase: Vector2, normal: Vector2, side: float) -> Vector2:
	if chase.length_squared() < 0.0001 or normal.length_squared() < 0.0001:
		return chase
	var tangent := normal.orthogonal()
	var along := tangent.dot(chase)
	if absf(along) < chase.length() * 0.05:
		along = side
	if along < 0.0:
		tangent = -tangent
	var away := maxf(chase.normalized().dot(-normal), 0.0)  # 벽 쪽으로 얼마나 밀고 있었나
	return (chase.normalized() * (1.0 - away) + tangent * (0.4 + away)).normalized() * chase.length()


func blocks(p: Vector2, margin: float = 0.0) -> bool:
	for c in circles:
		if p.distance_to(Vector2(c.x, c.y)) < c.z + margin:
			return true
	return false
