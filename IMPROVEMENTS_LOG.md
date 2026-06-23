# MAPF Deadlock Resolution Improvements

## 문제 분석

### 문제 1: 핀 사이에서의 무한 왕복 (Pin-Between-Pin Loop)
**증상**: RD1과 RD2가 Storage_front와 Left_hall_entrance 사이에서 무한정 왕복
- RD1이 Storage_front로 이동 → RD2가 양보하며 대기
- RD2가 다른 목표로 이동 시도 → RD1이 막혀있으면 또 양보
- 이 과정이 반복되며 양보 횟수가 5회 초과 후에도 계속 발생

**원인**:
1. 양보를 수락하는 과정에서 새로운 경로 계산 (`_move_to_internal`)
2. 이미 양보 중인 상태에서 다시 양보 요청을 받으면 추가 경로 계산
3. 둘 사이의 핀이 좁아서 계속 충돌 감지

### 문제 2: 핀 사이에 있는데도 양보 요청 (Edge-Between-Nodes Collision)
**증상**: 두 에이전트가 경로상 다른 핀으로 이동 중인데도 충돌 감지
- "RD2이(가) Storage_front로 가려하는데..." 메시지가 반복
- 실제로는 둘 다 핀 **사이**에 있어서 충돌하지 않음

**원인**:
- `can_enter_node()`는 다른 에이전트가 **현재 점유 중**인 핀만 확인
- 에이전트가 핀 사이를 이동 중일 때는 경로상 현재 위치(path_index)가 고려되지 않음
- 결과: 다음 핀에 도착하기 전부터 충돌이라고 판단

## 해결책

### 1. 양보 중복 방지 (animatronics.gd)
```gdscript
# request_yield_to()에 추가
if _is_yielding:
    print("[양보 중복 방지] %s가 이미 양보 중이므로 새 요청 무시" % [self.name])
    return false
```
**효과**: 이미 양보 중인 에이전트는 새로운 양보 요청을 무시하여 무한 루프 방지

### 2. 경로상 현재 위치 추적 (animatronics.gd)
```gdscript
# advance_along_path()에서 경로 진행 중에도 주기적으로 동기화
if mapf != null:
    mapf.update_agent_position(self, _current_pin, _path_index)
```
**효과**: MAPF 매니저가 에이전트의 정확한 경로상 위치를 항상 알 수 있음

### 3. 핀 사이 에이전트 감지 (MapfManager.gd)
```gdscript
# try_resolve_deadlock()에 추가
if blocker_path_index >= 0 and blocked_path_index >= 0 and 
   blocker_path_index < blocker_path.size() - 1 and 
   blocked_path_index < blocked_path.size() - 1:
    # 둘 다 에지(핀 사이)에 있으므로 충돌 아님
    return false
```
**효과**: 두 에이전트가 모두 핀 사이에 있다면 양보 요청 생략

### 4. 양보 완료 후 정확한 상태 관리 (animatronics.gd)
```gdscript
# advance_along_path()의 양보 완료 로직
_is_yielding = false  # 먼저 상태 해제
if _is_deadlock_resolved():
    # 실제로 해결되었다면 계속 진행
else:
    _is_yielding = true  # 아직 막혀있다면 다시 양보 상태로
    _yield_wait_remaining = WAIT_STEP_SECONDS
```
**효과**: 데드락이 진정 해결될 때까지 대기를 반복하되, 중복 양보 방지

### 5. 폴백 전략 개선 (MapfManager.gd)
```gdscript
# _find_yield_target_fallback()에서
if can_enter_node(blocker, blocker_node):
    return blocker_node  # 현재 위치에서 대기가 최고의 선택
```
**효과**: 양보 위치를 찾을 수 없으면 현재 위치에서 대기하도록 단순화

## 예상 결과

### 이전 로그 문제점
```
[양보 수락] RD2가 Storage_front에서 대기
[충돌 감지] RD1이(가) Storage_front로 가려하는데 RD2이(가) Storage_front에 있음
[양보 불가] RD1→RD2 충돌: 최대 양보 횟수(5) 초과, 계속 진행
```

### 예상 개선된 로그
- 먼저 한 에이전트가 양보 완료될 때까지 기다림
- 핀 사이 충돌은 감지하지 않음
- 양보 횟수 5회를 초과하지 않음
- 더 자연스러운 길 양보 동작

## 테스트 방법

1. **무한 루프 확인**: startMove 후 RD1, RD2 충돌 시나리오에서 양보 횟수가 5회 이상 나오지 않아야 함
2. **핀 사이 충돌 확인**: "RD_가 핀A로 가려하는데 RD_가 핀A에 있음" 메시지가 반복되지 않아야 함  
3. **정상 양보**: 충돌 시 한 에이전트가 양보하고, 대기 후 계속 진행하는 패턴이 반복되어야 함

## 변경 사항 요약

| 파일 | 함수 | 변경 내용 |
|------|------|---------|
| animatronics.gd | request_yield_to() | 양보 중복 방지 체크 추가 |
| animatronics.gd | advance_along_path() | 경로 진행 중 path_index 동기화 |
| animatronics.gd | advance_along_path() | 양보 완료 후 상태 정확히 관리 |
| MapfManager.gd | try_resolve_deadlock() | 핀 사이 에이전트 감지 로직 |
| MapfManager.gd | _find_yield_target_fallback() | 현재 위치 대기를 우선 전략으로 변경 |
