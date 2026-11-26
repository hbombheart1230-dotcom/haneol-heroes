class_name FormationData
extends Resource
## 대형 한 묶음 (FormationBrain): 같은 적 count명이 모양(shape)대로 서서 함께 움직이고, 같은 순간 겨눠 같은 순간 쏜다.
## 물결에 넣기: WaveData.formations + formation_after. 전장별 대형은 data/formations/*.tres.
## 사격 주기: 움직임(move_time 또는 stop_range에 닿을 때까지) → 멈춤(halt_time) → 겨눔(구성원 공격의 windup, 모두 같은 순간)
## → 발사 → 장전(reload_time, 빈틈) → 다시 움직임.

enum Shape { LINE, ARC, RING, SCATTER }
enum Move { ADVANCE, KITE, HOLD, HOP }

## 구성원 (모두 같은 적). 공격은 이 적의 공격(behaviour.attack 포함)을 그대로 쓴다.
@export var member: EnemyData
@export var count: int = 8
@export var shape: Shape = Shape.LINE
## 구성원 사이 간격(px): LINE·SCATTER는 옆 사람과, ARC·RING은 호를 따라.
@export var spacing: float = 72.0
## ARC·RING 반지름(px). ARC는 영웅 쪽으로 오목한 호 (학익진), RING은 영웅을 둘러싼 원.
@export var radius: float = 320.0
## ARC 호의 크기(도). 0이면 spacing과 radius로 정한다.
@export var arc_deg: float = 0.0
@export var move: Move = Move.ADVANCE

@export_group("나오기")
## 대형 가운데가 영웅에게서 이 거리(px)에 선다 (RING은 영웅 둘레 radius). 걸을 수 있는 곳 밖 자리는 안으로 당긴다.
@export var spawn_dist: float = 520.0
## 대형 방향을 정할 때 화면 안쪽을 고를지 (false면 아무 방향).
@export var face_player: bool = true

@export_group("움직임")
## 대형 가운데가 움직이는 빠르기 = 구성원 move_speed × 이 배율 (줄이 흩어지지 않게 느리게).
@export var speed_mult: float = 0.6
## 움직이는 시간(초) 최대. ADVANCE는 영웅과 stop_range까지 오면 일찍 멈춘다.
@export var move_time: float = 2.4
## ADVANCE: 대형 가운데가 영웅에게서 이 거리까지 오면 멈춘다. KITE: 이 거리를 지키려 물러난다.
@export var stop_range: float = 380.0
## KITE: 영웅과의 거리가 stop_range ± 이 폭 안이면 서고, 더 멀면 다가오고 더 가까우면 물러난다.
@export var kite_band: float = 70.0
## 구성원이 자기 자리에서 이만큼(px) 안이면 자리에 선 것으로 본다.
@export var slot_tolerance: float = 24.0
## 누가 쓰러지면 빈자리를 두는지(false) 좁히는지(true).
@export var close_ranks: bool = false

@export_group("사격 주기")
## 멈춘 뒤 겨누기까지(초).
@export var halt_time: float = 0.35
## 쏜 뒤 다음 움직임까지 장전(초): 대형의 빈틈.
@export var reload_time: float = 2.2
## 처음 다 나온 뒤 첫 움직임까지(초).
@export var form_time: float = 0.5
## 처음 모이기를 이만큼(초) 넘게 기다리면 모인 사람으로 시작한다 (예고 중 막힌 자리 등).
@export var form_timeout: float = 2.5
## 겨눔 차례에 일부가 아직 못 겨누면 (회복·경직 중) 이만큼(초)까지 모두를 기다렸다 같이 시작한다 (일제 사격).
@export var aim_gather: float = 0.6
## 겨눔 차례에 아무도 못 겨누면 (모두 경직·기절) 이만큼(초) 다시 시도하다 장전으로.
@export var aim_retry: float = 1.2

@export_group("자리 찾기")
## 구성원이 자기 자리에서 이 거리(px) 안이면 줄여 걷는다 (자리를 지나치지 않게).
@export var steer_slow_dist: float = 80.0
## 줄여 걸을 때 가장 느린 배율 (move_speed ×).
@export var steer_min_mult: float = 0.35
## HOP 구성원의 한 번 뛰는 거리(px): 구성원 behaviour에 hop_distance가 없을 때.
@export var hop_reach: float = 220.0
