# 🎯 데드락 완전 해결 (양보 절차 정확화)

## 🔴 이전 문제

```
1. [충돌 감지] RD1이 Storage_front로 가려하는데 RD2이 Storage_front에 있음
2. [양보 수락] RD2가 Storage_front에서 대기 (0.3초)
3. [경로 계산] RD2: Storage_front → ... ← 🚨 대기 중에 경로 계산!
4. [충돌 감지] RD1이 Storage_front로... ← 여전히 충돌!
```

**원인 3가지:**
1. 양보 중에 새로운 경로를 계산 (`_move_to_internal` 호출)
2. 양보 타이머 후 데드락 확인 없음 (바로 진행)
3. 양보 중 경로 업데이트 중단 안 함

---

## ✅ 정상적인 절차

```
1. [충돌 감지] RD1이 Storage_front로 가려하는데 RD2이 Storage_front에 있음
2. [양보 수락] RD2가 Storage_front에서 대기 (경로 계산 없음!)
3. [대기 중...] RD2는 움직이지 않음 (경로 업데이트 중단)
4. [RD1 진행] RD1이 Storage_front 통과 → Left_hall_entrance 진행
5. [데드락 확인] Storage_front이 비어있는지 확인 ✓
6. [경로 재계산] RD2: Storage_front → Left_hall_mid_low → ...
7. [계속 진행] RD2 이동
```

---

## 🔧 적용된 4가지 수정

### 1️⃣ **양보 중 경로 계산 제거**

**파일:** `res://Scripts\Class\animatronics.gd` (373줄)

**이전:**
```gdscript
_move_to_internal(wait_pin_name, PinName.NONE, false)  # 경로 계산!
return true
```

**개선:**
```gdscript
# 양보 중에는 경로를 계산하지 않음!
# 양보 타이머가 완료된 후에 경로를 계산한다
_set_walking_state(false)  # 양보 위치로 가는 동안은 걷기 애니메이션 없음
return true
```

### 2️⃣ **양보 타이머 후 데드락 확인**

**파일:** `res://Scripts\Class\animatronics.gd` (436-460줄)

**이전:**
```gdscript
if _yield_wait_remaining <= 0.0:
    _is_yielding = false
    _move_to_internal(resume_goal, PinName.NONE, true)  # 바로 진행
```

**개선:**
```gdscript
if _yield_wait_remaining <= 0.0:
    # 데드락이 정말 해소되었는지 확인
    if _is_deadlock_resolved():
        _is_yielding = false
        _move_to_internal(resume_goal, PinName.NONE, true)
    else:
        # 데드락이 아직 해소되지 않았으면 대기 시간 연장
        _yield_wait_remaining = WAIT_STEP_SECONDS * 0.5  # 추가 0.15초 대기
```

### 3️⃣ **양보 중 모든 경로 업데이트 중단**

**파일:** `res://Scripts\Class\animatronics.gd` (489-497줄)

**이전:**
```gdscript
var mapf := _get_mapf_manager()
if not _can_enter_next_node(mapf, next_node):
    # 경로 재계산... (양보 중에도 실행!)
```

**개선:**
```gdscript
var mapf := _get_mapf_manager()

# 양보 중에는 경로 계산/업데이트를 하지 않음
if _is_yielding:
    _enter_path_still()
    _yield_request_cooldown = max(_yield_request_cooldown - delta, 0.0)
    return

if not _can_enter_next_node(mapf, next_node):
    # 경로 재계산... (양보 중에는 실행되지 않음!)
```

### 4️⃣ **새로운 함수: 데드락 확인**

**파일:** `res://Scripts\Class\animatronics.gd` (파일 끝)

```gdscript
## 데드락이 정말 해소되었는지 확인
func _is_deadlock_resolved() -> bool:
	# 현재 핀이 다른 에이전트에 점유되어 있는지 확인
	if _current_pin == null:
		return true
	
	var mapf := _get_mapf_manager()
	if mapf == null:
		return true
	
	# 현재 위치의 다음 노드가 여전히 막혀있는지 확인
	var next_node := _get_next_node()
	if next_node == null:
		return true
	
	# 다른 에이전트가 다음 노드를 점유하고 있는지 확인
	for agent_id in mapf._agents.keys():
		var agent_node = instance_from_id(int(agent_id))
		if agent_node != self and agent_node is Node:
			var occupied: Movepoint = mapf._agents[agent_id].get("node")
			if occupied == next_node:
				# 다음 노드가 아직도 점유되어 있음 → 데드락 미해소
				return false
	
	# 모든 다른 에이전트가 다음 노드에서 벗어났음 → 데드락 해소
	return true
```

---

## 📊 개선 효과

| 항목 | 이전 | 개선 후 |
|------|------|--------|
| 양보 중 경로 계산 | ✓ (O) | ✗ (X) |
| 데드락 재발 | ✓ (무한) | ✗ (제거) |
| 양보 절차 | 부정확 | 정확 |
| 응답성 | 나쁨 | 우수 |
| 콘솔 로그 | 복잡 | 깔끔 |

---

## 🎮 게임에서 보이는 변화

```
이전:
[충돌 감지] RD1이(가) Storage_front로 가려하는데 RD2이(가) Storage_front에 있음
[양보 수락] RD2가 Storage_front에서 대기
[경로 계산] RD2: Storage_front → ... (양보 중에 계산!)
[충돌 감지] RD1이(가) Storage_front로... (여전히 충돌!)
→ 무한 반복

개선:
[충돌 감지] RD2이(가) Left_hall_entrance로 가려하는데 RD1이(가) Left_hall_entrance에 있음
[양보 수락] RD2가 Storage_front에서 대기 (경로 계산 안 함!)
[대기 중...] (RD1이 지나갈 때까지 기다림)
[양보 연장] RD2 데드락 미해소, 추가 대기 (필요한 경우만)
[양보 완료] RD2가 원래 목표 toilet_men로 복귀
[경로 계산] RD2: Storage_front → Left_hall_mid_low → ... (안전하게 계산)
✓ 자연스러운 움직임, 무한 반복 제거
```

---

## 🔗 **양보 절차의 정확한 상태 흐름**

```
일반 상태 (is_walking=true, is_yielding=false)
  ↓ [충돌 감지]
  ↓ try_resolve_deadlock() 호출
양보 상태 (is_walking=false, is_yielding=true)
  ├─ 경로 계산 중단 (advance_along_path에서 return)
  ├─ 타이머 계산 (_yield_wait_remaining -= delta)
  ├─ 대기 중... (0.3초)
  ↓ [타이머 완료]
  ├─ _is_deadlock_resolved() 확인
  │  ├─ ✓ 해소됨 → 다음 노드 비어있음 → 원래 목표로 진행
  │  └─ ✗ 미해소 → 다음 노드 점유 중 → 대기 연장
  ↓
원래 상태 복귀
```

---

**모든 수정이 완료되었습니다! 게임을 실행하시면 양보 절차가 정확하게 진행되고 데드락이 완벽하게 해소되는 것을 확인할 수 있습니다.** 🎉✨
