# Deadlock 문제 해결 보고서

## 문제 분석

### 문제점 1: Deadlock 루프 (양보 중 경로 재계산)
**증상**:
```
[양보 수락] RD2가 Storage_front에서 대기
[양보 성공] RD2 → RD1
[경로 계산] RD2: Storage_front → Left_hall_mid_low → ...  ← 바로 새 경로 계산!
[충돌 감지] RD2이(가) Storage_front로 가려하는데 RD1이(가) Storage_front에 있음
```

**원인**: 양보를 수락한 직후 `_yield_wait_remaining`이 설정되지만, 다음 프레임에서 경로 재계산이 일어남.

**해결책**:
1. `request_yield_to()`: 양보 수락 시 `_planned_path.clear()` 및 `_set_walking_state(false)` 추가
2. `advance_along_path()`: 양보 상태(`_is_yielding == true`)에서는 즉시 return하여 다른 처리 차단

---

### 문제점 2: 위치 동기화 불일치
**증상**:
```
[경로 계산] RD2: Storage_front → Left_hall_mid_low → ...
[충돌 감지] RD2이(가) Storage_front로 가려하는데 RD1이(가) Storage_front에 있음
```

RD2가 이미 이동 중인데 MAPF는 이전 위치에 등록되어 있음.

**원인**:
1. 새 경로가 계산된 후 MAPF에 즉시 업데이트되지 않음
2. 양보 중인 agent도 같은 로직으로 충돌 판정되어 불필요한 양보 유발

**해결책**:
1. `_move_to_internal()`: 경로 계산 직후 `mapf.update_agent_position()` 호출 (Line 327)
2. `advance_along_path()`: 이동 중에도 주기적 MAPF 업데이트 (Line 619)
3. `can_enter_node()`: `is_yielding_now()` 체크로 양보 중인 agent 제외

---

## 적용된 수정사항

### 1. animatronics.gd

#### 1.1 공개 함수 추가
```gdscript
func is_yielding_now() -> bool:
	return _is_yielding
```

#### 1.2 경로 계산 직후 MAPF 업데이트 (Line ~327)
```gdscript
# ⭐ 핵심 수정: 경로 계산 직후 MAPF에 새로운 경로 정보 반영
if mapf != null:
	mapf.update_agent_position(self, _current_pin, _path_index)
```

#### 1.3 양보 상태 명확화 (Line 345~)
- 변수 중복 제거
- 양보 시 즉시 경로 초기화: `_planned_path.clear()`
- 양보 시 걷기 중지: `_set_walking_state(false)`
- 양보 중 MAPF 위치 등록: `mapf.update_agent_position(self, _current_pin, -1)`

#### 1.4 양보 해제 전 MAPF 업데이트 (Line ~505)
```gdscript
var mapf := _get_mapf_manager()
if mapf != null:
	mapf.update_agent_position(self, _current_pin, -1)
```

#### 1.5 이동 중 MAPF 업데이트 (Line ~619)
```gdscript
if mapf != null:
	mapf.update_agent_position(self, current_node, _path_index)
```

---

### 2. MapfManager.gd

#### 2.1 양보 중인 agent 제외 (Line 111~116)
```gdscript
# ⭐ 핵심 수정: 양보 중인 agent는 충돌 판정에서 제외
var agent_node = instance_from_id(int(id))
if agent_node is Node and agent_node.has_method("is_yielding_now"):
	if agent_node.is_yielding_now():
		continue  # 양보 중인 agent는 무시
```

#### 2.2 양보 요청자 추적 추가 (Line 21, 185~193)
```gdscript
var _yield_requester: Dictionary = {}  # NEW: 양보 요청자 정보 추적

# try_resolve_deadlock에서:
if accepted:
	_yield_requester[yielder_id] = {
		"blocked_agent": blocked_agent,
		"blocked_to": blocked_to,
		"yield_target": yield_target
	}
```

---

## 예상 개선 효과

### Before (문제 상황)
```
[양보 수락] RD2가 Storage_front에서 대기
[경로 계산] RD2: Storage_front → ... (바로 재계산!)
[충돌 감지] ... (계속 반복)
```

### After (개선됨)
```
[양보 수락] RD2가 Storage_front에서 대기
[양보 대기중] RD2가 양보 핀에서 계속 대기 (양보자 대기시간: 0.30초)
[양보 완료] RD2가 원래 목표로 복귀
[경로 계산] RD2: Storage_front → ...
```

---

## 테스트 방법

1. 게임 실행
2. 두 agent가 충돌할 때까지 이동
3. 로그에서 다음 확인:
   - `[양보 수락]` 후 `[경로 계산]`이 바로 나타나지 않음
   - `[양보 대기중]` 메시지가 주기적으로 나타남
   - `[양보 완료]` 메시지 후 정상 이동

---

## 주의사항

- `WAIT_STEP_SECONDS = 0.25`: 양보 대기 시간 (필요시 조정)
- `BLOCKED_REPLAN_MAX_TIMES = 5`: 최대 양보 시도 횟수 (초과 시 강제 통과)
- `YIELD_COOLDOWN_MS = 300`: 양보 요청 쿨타임 (단축됨)
