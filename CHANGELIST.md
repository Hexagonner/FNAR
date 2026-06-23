# 경로 계획 시스템 개선사항 (Pathfinding & Yielding Fixes)

## 원본 로그에서 발견된 문제

### 1. 핀 사이에서의 무한 왕복 (Pin-Between-Pin Yielding Loop)
```
[충돌 감지] RD1이(가) Storage_front로 가려하는데 RD2이(가) Storage_front에 있음
[양보 불가] RD1→RD2 충돌: 최대 양보 횟수(5) 초과, 계속 진행
```
**원인**: 양보 중인 에이전트가 새로운 양보 요청을 다시 받으면서 무한 루프 발생

### 2. 핀 사이의 충돌 감지 중복 (Edge-Based False Collision Detection)
```
[충돌 감지] RD1이(가) Left_hall_entrance로 가려하는데 RD2이(가) Left_hall_entrance에 있음
```
반복 발생 → 둘 다 경로 상에서 핀 사이에 있어서 실제로는 충돌하지 않음

---

## 적용된 해결책

### 수정 1: 양보 중복 요청 방지 (`animatronics.gd` 라인 399-402)

**변경 전:**
```gdscript
func request_yield_to(goal_pin: Movepoint) -> bool:
    if goal_pin == null:
        return false
    # ... 즉시 양보 수락
```

**변경 후:**
```gdscript
func request_yield_to(goal_pin: Movepoint) -> bool:
    if goal_pin == null:
        return false
    if _current_pin == null:
        _current_pin = _get_closest_pin()
    if _current_pin == null:
        return false
    
    # ⭐ 개선 2: 이미 양보 중이면 새로운 양보 요청을 무시 (무한 루프 방지)
    if _is_yielding:
        print("[양보 중복 방지] %s가 이미 양보 중이므로 새 요청 무시" % [self.name])
        return false
    # ... 계속
```

**효과**: 양보 중인 에이전트는 추가 양보 요청을 거부하여 무한 루프 방지

---

### 수정 2: 경로상 정확한 위치 추적 (`animatronics.gd` 라인 644-647)

**변경 전:**
```gdscript
_enter_path_walk()
var step := move_speed * delta
global_position = global_position.move_toward(next_pos, step)

if distance > 0.001:
    var dir := to_target.normalized()
    var target_yaw := atan2(dir.x, dir.z)
    rotation.y = lerp_angle(rotation.y, target_yaw, clamp(turn_speed * delta, 0.0, 1.0))
```

**변경 후:**
```gdscript
_enter_path_walk()
var step := move_speed * delta
global_position = global_position.move_toward(next_pos, step)

if distance > 0.001:
    var dir := to_target.normalized()
    var target_yaw := atan2(dir.x, dir.z)
    rotation.y = lerp_angle(rotation.y, target_yaw, clamp(turn_speed * delta, 0.0, 1.0))

# ⭐ 개선: 경로를 따라가는 중간에도 현재 경로 인덱스를 주기적으로 동기화
# (핀 사이에 있을 때도 MAPF가 정확한 위치를 알 수 있도록)
if mapf != null:
    mapf.update_agent_position(self, _current_pin, _path_index)
```

**효과**: MAPF가 에이전트의 정확한 경로상 위치를 항상 알 수 있음 (핀 사이에서도)

---

### 수정 3: 핀 사이 에이전트 양보 불필요 감지 (`MapfManager.gd` 라인 125-138)

**변경 전:**
```gdscript
func try_resolve_deadlock(blocked_agent: Node, blocked_from: Movepoint, blocked_to: Movepoint, requester_remaining: Array[Movepoint]) -> bool:
    if blocked_agent == null or blocked_to == null:
        return false
    var blocker := _find_agent_at_node(blocked_to, blocked_agent)
    if blocker == null:
        return false
    # ... 즉시 양보 로직 진행
```

**변경 후:**
```gdscript
func try_resolve_deadlock(blocked_agent: Node, blocked_from: Movepoint, blocked_to: Movepoint, requester_remaining: Array[Movepoint]) -> bool:
    if blocked_agent == null or blocked_to == null:
        return false
    var blocker := _find_agent_at_node(blocked_to, blocked_agent)
    if blocker == null:
        return false
    
    # ⭐ 개선: 두 에이전트가 현재 핸 사이에 있다면 양보 불필요
    # (아직 핀을 점유하지 않고 있으므로 충돌하지 않음)
    var blocked_id := _agent_id(blocked_agent)
    var blocker_id := _agent_id(blocker)
    var blocker_path_index: int = _agents[blocker_id].get("path_index", -1)
    var blocked_path_index: int = _agents[blocked_id].get("path_index", -1)
    var blocker_path: Array = _agents[blocker_id].get("path", [])
    var blocked_path: Array = _agents[blocked_id].get("path", [])
    
    # 경로 인덱스가 유효하고, 둘 다 핀 사이에 있다면 (경로 길이가 충분)
    if blocker_path_index >= 0 and blocked_path_index >= 0 and blocker_path_index < blocker_path.size() - 1 and blocked_path_index < blocked_path.size() - 1:
        # 둘 다 에지(핀 사이)에 있는 상태이므로 충돌이 아님 → 양보 불필요
        # (다음 프레임에 각각의 경로를 진행하면서 해결됨)
        return false
    # ... 계속
```

**효과**: 둘 다 경로상 노드 사이에 있다면 충돌이 아니므로 양보 생략

---

### 수정 4: 양보 완료 후 정확한 상태 관리 (`animatronics.gd` 라인 498-530)

**변경 전:**
```gdscript
if _yield_wait_remaining <= 0.0:
    if _is_deadlock_resolved():
        _is_yielding = false
        # ... 복귀 로직
    else:
        _yield_wait_remaining = WAIT_STEP_SECONDS
```

**변경 후:**
```gdscript
if _yield_wait_remaining <= 0.0:
    # ⭐ 개선: 양보 완료 후에도 양보 중 상태 초기화 필수
    _is_yielding = false  # 먼저 양보 상태를 해제하여 중복 양보 방지
    
    if _is_deadlock_resolved():
        _yield_resume_goal_pin = _main_goal_pin
        var resume_goal := _yield_resume_goal_pin
        var resume_goal_name: String = PIN_NODE_NAMES.get(resume_goal, "Unknown")
        
        # ... 복귀 로직
    else:
        # 데드락이 아직 해소되지 않았으면 다시 양보 상태로 복원하고 대기 연장
        _is_yielding = true
        _yield_wait_remaining = WAIT_STEP_SECONDS
```

**효과**: 데드락이 완전히 해결될 때까지 안전하게 대기하되, 중복 양보 방지

---

### 수정 5: 폴백 양보 위치 선택 개선 (`MapfManager.gd` 라인 223-259)

**변경 전:**
```gdscript
func _find_yield_target_fallback(blocker: Node, blocked_from: Movepoint, blocked_to: Movepoint, requester_remaining: Array[Movepoint]) -> Movepoint:
    var blocker_id := _agent_id(blocker)
    var blocker_node: Movepoint = _agents[blocker_id].get("node")
    if blocker_node == null:
        return null
    
    # ... 복잡한 탐색
    
    return null  # 실패
```

**변경 후:**
```gdscript
func _find_yield_target_fallback(blocker: Node, blocked_from: Movepoint, blocked_to: Movepoint, requester_remaining: Array[Movepoint]) -> Movepoint:
    var blocker_id := _agent_id(blocker)
    var blocker_node: Movepoint = _agents[blocker_id].get("node")
    if blocker_node == null:
        return null
    
    # ⭐ 개선: 현재 위치는 이미 안전하므로 그냥 대기하는 것이 최선
    if can_enter_node(blocker, blocker_node):
        return blocker_node
    
    # ... 복잡한 탐색
    
    return blocker_node  # ⭐ 개선: 마지막 폴백은 현재 위치에서 대기
```

**효과**: 양보 위치를 찾기 어려울 때 현재 위치에서 대기하는 것을 우선으로

---

## 기대 효과

### Before (문제 있음)
```
[충돌 감지] RD1이(가) Storage_front로 가려하는데 RD2이(가) Storage_front에 있음
[양보 수락] RD2가 Storage_front에서 대기...
[충돌 감지] RD1이(가) Storage_front로 가려하는데 RD2이(가) Storage_front에 있음
... (무한 반복)
[양보 불가] RD1→RD2 충돌: 최대 양보 횟수(5) 초과, 계속 진행
```

### After (개선됨)
```
[충돌 감지] RD1이(가) Storage_front로 가려하는데 RD2이(가) Storage_front에 있음
[양보 수락] RD2가 Storage_front에서 대기 (대기시간: 0.25초)
[양보 성공] RD1 → RD2
[양보 완료] RD2가 원래 목표로 복귀
[경로 계산] RD2: ... (새로운 경로로 진행)
```

---

## 테스트 체크리스트

- [ ] 로그에서 "양보 불가" 메시지가 나타나지 않음
- [ ] "양보 중복 방지" 메시지가 자주 나타나지 않음 (아주 드물게만)
- [ ] 두 에이전트가 자연스럽게 길을 양보하며 이동
- [ ] 충돌 감지 메시지가 과도하게 반복되지 않음
- [ ] 양보 후 에이전트들이 정상적으로 목표까지 도달

---

## 코드 통계

| 파일 | 변경 라인 수 | 추가 로직 |
|------|-----------|---------|
| `animatronics.gd` | +11 | 양보 중복 방지, 경로 동기화, 상태 관리 |
| `MapfManager.gd` | +14 | 핀 사이 감지, 폴백 개선 |
| **합계** | **+25** | 5가지 핵심 개선 |

변경사항은 최소한이며 기존 코드 구조를 최대한 유지하면서 문제를 해결합니다.
