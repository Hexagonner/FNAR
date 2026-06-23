# MAPF(Multi-Agent Path Finding) 시스템 구조 분석 보고서

## 📋 목차
1. [시스템 개요](#시스템-개요)
2. [아키텍처](#아키텍처)
3. [주요 구조적 문제점](#주요-구조적-문제점)
4. [상세 문제 분석](#상세-문제-분석)
5. [권장 개선 사항](#권장-개선-사항)

---

## 시스템 개요

### 핵심 목적
- **모바일 환경 최적화**: 4개 이하 에이전트용 경로 탐색 시스템
- **알고리즘**: 우선순위 기반 계획(Prioritized Planning) + 예약 테이블(Reservation Table) + 시간 확장 A*
- **교착 상태 해결**: Yield(양보) 메커니즘으로 데드락 해소

### 주요 컴포넌트
- **MapfManager.gd** (705줄): 경로 계획 중추
- **animatronics.gd** (713줄): 에이전트 이동 제어
- **Movepoint.gd** (6줄): 그래프 노드 (neighbors 배열만 보유)

---

## 아키텍처

```
┌─────────────────────────────────────────┐
│         MapfPlanner (MapfManager)        │
├─────────────────────────────────────────┤
│ • _agents: {id → state}                 │
│ • _priority_order: [id1, id2, ...]      │
│ • _distance_cache: 휴리스틱 캐시        │
│ • _yield_cooldown_until: 양보 쿨타임    │
│ • _yield_attempt_count: 양보 시도 제한  │
└─────────────────────────────────────────┘
          ↓↓↓ request_path() ↓↓↓
┌─────────────────────────────────────────┐
│    animatronics (에이전트 노드)          │
├─────────────────────────────────────────┤
│ • _planned_path: Array[Movepoint]       │
│ • _path_index: 현재 경로상 위치          │
│ • _is_yielding: 양보 상태 플래그        │
└─────────────────────────────────────────┘
          ↓↓↓ neighbors ↓↓↓
┌─────────────────────────────────────────┐
│         Movepoint 그래프 노드             │
├─────────────────────────────────────────┤
│ • neighbors: Array[Movepoint]           │
│ • global_position (Marker3D에서 상속)   │
└─────────────────────────────────────────┘
```

---

## 주요 구조적 문제점

### 🔴 1. **Agent State 동기화 문제** (심각도: HIGH)

#### 문제 상황
```gdscript
# MapfManager.gd:87-99
func update_agent_position(agent: Node, pin: Movepoint, path_index: int = -1) -> void:
    var id := _agent_id(agent)
    if _agents.has(id):
        _agents[id]["node"] = pin
        # path_index 동기화가 불완전함
        if path_index >= 0:
            _agents[id]["path_index"] = path_index
        else:
            # 경로에서 pin의 위치를 찾기만 함 (비효율적)
            var path: Array = _agents[id].get("path", [])
            for i in range(path.size()):
                if path[i] == pin:
                    _agents[id]["path_index"] = i
                    break
```

**문제점:**
- `path_index`가 전달되지 않으면 **O(n) 선형 탐색** 수행
- 동일한 `Movepoint` 객체 참조가 여러 번 나타나면 **첫 번째 인덱스만 찾음**
- `path_index` 업데이트 실패 시 이후 양보 로직이 잘못된 상태에서 실행됨

#### 영향 받는 코드
1. **양보 로직** (MapfManager:390-409): `path_index`를 기반으로 금지 노드 설정
   ```gdscript
   var path_index: int = _agents[id].get("path_index", 0)
   var start: int = max(path_index, 0)
   var limit: int = mini(planned.size(), start + 3)  # 정확하지 않은 범위
   ```

2. **animatronics.gd 진행 추적** (549줄)
   ```gdscript
   mapf.update_agent_position(self, _current_pin, _path_index)
   ```
   → path_index가 MAPF에 반영되지 않을 수 있음

---

### 🔴 2. **Yield(양보) 금지 구역 설정의 과도성** (심각도: HIGH)

#### 문제 상황
```gdscript
# MapfManager.gd:369-413
func _build_forbidden_nodes_for_yield(
    blocker_id: String,
    blocked_from: Movepoint,
    blocked_to: Movepoint,
    requester_remaining: Array[Movepoint]
) -> Dictionary:
    var forbidden: Dictionary = {}
    
    # 1. 상대방의 전체 남은 경로 금지
    for node in requester_remaining:
        if node != null: forbidden[_node_id(node)] = true
    
    # 2. 다른 모든 에이전트의 미래 경로 금지
    for id in _agents.keys():
        if id == blocker_id: continue
        var current_node: Movepoint = _agents[id].get("node")
        if current_node != null: forbidden[_node_id(current_node)] = true
        var planned: Array = _agents[id].get("path", [])
        var path_index: int = _agents[id].get("path_index", 0)
        var start: int = max(path_index, 0)
        var limit: int = mini(planned.size(), start + 3)  # ← 고정 3칸!
        for i in range(start, limit):
            if planned_node is Movepoint:
                forbidden[_node_id(planned_node)] = true
    
    # 3. 양보자의 원래 경로 15칸까지 금지
    var blocker_path: Array = _agents[blocker_id].get("path", [])
    var blocker_path_index: int = _agents[blocker_id].get("path_index", 0)
    var start_idx: int = max(blocker_path_index + 1, 0)
    var limit_future: int = mini(blocker_path.size(), start_idx + 15)  # ← 고정 15칸!
    for i in range(start_idx, limit_future):
        if planned_node is Movepoint:
            forbidden[_node_id(planned_node)] = true
    
    # 4. 금지 구역 주변까지 확장
    _expand_forbidden_by_neighbors(forbidden, FORBIDDEN_BUFFER_DEPTH)
```

**문제점:**
- **3칸 + 15칙 + 버퍼 확장** = 매우 광범위한 금지 구역
- 양보 위치가 **거의 찾을 수 없음** → 양보 실패율 증가
- 좁은 맵에서는 **양보할 수 있는 영역 자체가 없을 수 있음**
- `requester_remaining` 배열이 충분히 커서 막힐 수 있음

#### 결과
```
[양보 대상 선택 실패] 검토:45개, 필터:44개, 유효:1개, 경로상:0개
→ 금지 구역이 너무 넓을 가능성 높음. 차단 해제 검토 필요
```

---

### 🔴 3. **Yield 선택 우선순위 로직의 불일치** (심각도: MEDIUM)

#### 문제 상황
```gdscript
# MapfManager.gd:317-366
# Tier 우선순위
# Tier 1: 현재 위치에서 매우 가까운 곳 (거리 1-2)
# Tier 2: 경로 상의 노드 중 가장 가까운 곳
# Tier 3: 모든 노드 중 가장 가까운 곳

var is_better := false
var current_blocker_dist: int = int(distance_from_blocker.get(_node_id(blocker_node), 999999))

if best_node == null:
    is_better = true
elif d_from_blocker <= 2:  # ← Tier 1 선택 조건
    if current_blocker_dist > 2:
        is_better = true
    elif d_from_blocker < current_blocker_dist:
        is_better = true
elif is_on_path and not best_is_on_path:  # ← Tier 2
    is_better = true
elif is_on_path == best_is_on_path and d_from_blocker < best_distance:  # ← Tier 3
    is_better = true
```

**문제점:**
- Tier 1이 선택되면 더 이상 **Tier 2/3로 교체 불가**
- Tier 1 (거리 1-2)은 **충돌 지점과 가까움**
- 충돌 해결 후 **원래 경로로 빠르게 돌아가야 하는데**, Tier 2/3이 더 낫지만 선택 불가

**예시:**
```
충돌: A가 N3 을 향해 가는데 B가 N3 에 있음
현재 A의 위치: N1
양보 옵션:
  - N2 (거리 1, Tier 1): 충돌 지점 인근, 금지됨
  - N5 (거리 3, Tier 2, 경로상): A의 원래 경로상, 더 나은 선택
  
→ Tier 1이 없어서 N5 선택 (OK)
→ 그런데 금지 구역이 충돌 지점 근처까지 포함하면 N5도 금지될 수 있음!
```

---

### 🔴 4. **재계획(Replan) 과정의 O(n) 복잡도** (심각도: MEDIUM)

#### 문제 상황
```gdscript
# MapfManager.gd:454-487
func _replan_all() -> void:
    var node_reservations: Dictionary = {}
    var edge_reservations: Dictionary = {}
    
    for id in _priority_order:  # ← 모든 에이전트 순회
        if not _agents.has(id): continue
        var state: Dictionary = _agents[id]
        var start_pin: Movepoint = state.get("node")
        var goal_pin: Movepoint = state.get("goal")
        var must_pin: Movepoint = state.get("must")
        
        # 각 에이전트마다 시간 확장 A* 실행
        path = _plan_for_agent(id, start_pin, goal_pin, must_pin, node_reservations, edge_reservations)
```

**문제점:**
- **한 에이전트의 경로 변경** → 모든 에이전트 재계획 필수
- 4명 에이전트, 각 50칸 경로 = 최대 4 × 4,096개 A* 노드 확장
- `request_path()` 호출 시마다 **_replan_all() 전체 실행**
  ```gdscript
  func request_path(...) -> Array[Movepoint]:
      # ...
      _replan_all()  # ← 항상 전체 재계획!
      return _agents[id].get("path", [])
  ```

#### 결과
- 목표 변경 시 **불필요한 모든 경로 재계산**
- yield(양보) 요청도 새 경로 계산 → **연쇄 재계획**

---

### 🔴 5. **Instance ID 기반 Agent 추적의 취약성** (심각도: MEDIUM)

#### 문제 상황
```gdscript
# MapfManager.gd:684-685, 193
func _agent_id(agent: Node) -> String:
    return str(agent.get_instance_id())  # ← Instance ID 사용

func _find_agent_at_node(node: Movepoint, except_agent: Node = null) -> Node:
    for id in _agents.keys():
        var agent_node = instance_from_id(int(id))  # ← ID → 노드 변환 시도
        if not (agent_node is Node):
            continue  # ← 변환 실패하면 건너뜀
        # ...
```

**문제점:**
1. **씬 재로드 시 Instance ID 변경**
   ```
   씬 언로드 → 노드 삭제 → Instance ID 무효화
   재로드 후 동일 노드도 다른 ID 할당
   → 이전 MAPF 데이터 완전 손실
   ```

2. **동적 생성/삭제 시 추적 불가**
   ```gdscript
   var enemy = preload("res://enemy.tscn").instantiate()
   add_child(enemy)  # ← 새로운 ID 할당
   # 기존 MAPF 데이터와 연결 불가
   ```

3. **instance_from_id() 실패 후 무시**
   ```gdscript
   var agent_node = instance_from_id(int(id))
   if not (agent_node is Node):
       continue  # ← 경고/에러 없이 침묵 실패
   ```
   - 메모리 누수 가능 (고아 딕셔너리 엔트리)

---

### 🔴 6. **경로 유효성 미검증** (심각도: MEDIUM)

#### 문제 상황
```gdscript
# MapfManager.gd:459-487
for id in _priority_order:
    var state: Dictionary = _agents[id]
    var start_pin: Movepoint = state.get("node")
    var goal_pin: Movepoint = state.get("goal")
    
    var path: Array[Movepoint] = []
    if goal_pin == null:
        path = [start_pin]
    else:
        path = _plan_for_agent(...)
        if path.is_empty():
            path = [start_pin]  # ← 경로 실패 시 [시작점]만 반환
            state["valid"] = false
    
    state["path"] = path
    _agents[id] = state
```

**문제점:**
- `state["valid"] = false`로 표시하지만 **아무데도 확인하지 않음**
  ```gdscript
  # MAPF 시스템 어디에도 valid 체크 없음!
  ```
- 경로 실패 이유 미기록 (시간 초과? 불가능한 목표? 예약 충돌?)
- animatronics에서 빈 경로 받아도 처리만 함
  ```gdscript
  if move_path.is_empty():
      _set_walking_state(false)
      printerr("[경로 실패] ...")  # ← 원인 불명확
      return
  ```

---

### 🟡 7. **거리 캐시의 불완전한 갱신** (심각도: MEDIUM)

#### 문제 상황
```gdscript
# MapfManager.gd:19, 649-654
var _distance_cache: Dictionary = {}    # 한 번 계산하면 영구 저장

func _heuristic(from_node: Movepoint, to_node: Movepoint) -> int:
    var key := "%s->%s" % [_node_id(from_node), _node_id(to_node)]
    if _distance_cache.has(key): return _distance_cache[key]
    var dist := _graph_distance(from_node, to_node)
    _distance_cache[key] = dist
    return dist
```

**문제점:**
- 그래프 구조 변경 시 캐시 갱신 불가
- 동적 맵 추가/제거 불가능 (이미 캐시된 거리 유지)
- 엣지 추가/제거 후 휴리스틱 부정확
- **캐시 메모리 누적** (clear 함수 없음)

---

### 🟡 8. **양보 시도 제한의 미흡한 추적** (심각도: MEDIUM)

#### 문제 상황
```gdscript
# MapfManager.gd:145-155
var conflict_key := "%s|%s|%s" % [_agent_id(blocked_agent), _node_id(blocked_to), _agent_id(blocker)]
var attempt_count: int = _yield_attempt_count.get(conflict_key, 0)
if attempt_count >= BLOCKED_REPLAN_MAX_TIMES:
    print("[양보 불가] ... 최대 양보 횟수(%d) 초과" % BLOCKED_REPLAN_MAX_TIMES)
    return false
_yield_attempt_count[conflict_count] = attempt_count + 1
```

**문제점:**
- conflict_key = `agent_id|node_id|blocker_id`로 고정
- **양보자가 바뀌면** 새로운 키 생성 → 제한 초기화
  ```
  T0: A 양보 (제한: 1/5)
  T1: B 양보 (제한: 1/5) ← 새로운 conflict_key!
  → 제한이 의미 없음
  ```
- **동일 지점 충돌 반복** → 양보 한도 반복 도달 가능

---

### 🟡 9. **Yield Resume Goal 로직의 불완전성** (심각도: LOW-MEDIUM)

#### 문제 상황
```gdscript
# animatronics.gd:335-374
func request_yield_to(goal_pin: Movepoint) -> bool:
    if goal_pin == null:
        return false
    
    # 목표 도달 시 그냥 대기만 함
    if _current_pin == goal_pin:
        _yield_resume_goal_pin = _main_goal_pin  # ← 원래 목표로 재설정
        _yield_wait_remaining = WAIT_STEP_SECONDS
        _is_yielding = true
        # ...
        return true
    
    # 다른 위치로 양보
    _yield_resume_goal_pin = _main_goal_pin  # ← 동일 처리
    # ...
    _move_to_internal(wait_pin_name, PinName.NONE, false)
    return true
```

**문제점:**
- 양보 완료 후 **원래 목표로만 돌아감**
- 만약 목표가 중간에 변경되었다면?
  ```
  T0: A.move_to(GOAL_A)
  T1: 충돌 감지, yield 시작
  T2: 동안 A.move_to(GOAL_B) 호출 ← _main_goal_pin 변경
  T3: 양보 완료 → A가 GOAL_B로 가야 하는데?
  → 복합한 상황에서 동작 미정의
  ```

---

### 🟡 10. **Movepoint 노드 구조의 너무 단순함** (심각도: LOW)

#### 문제 상황
```gdscript
# Movepoint.gd (6줄)
extends Marker3D
class_name Movepoint

@export var neighbors :Array[Movepoint] = []
```

**문제점:**
- **메타데이터 없음** (통행 비용, 장애물 타입, 시간대별 가용성 등)
- **동적 차단** 불가능 (오브젝트 놓임 시 해당 노드 차단)
- **방향성 그래프** 미지원 (일방통행 경로 불가)
- 확장성 제한

---

## 상세 문제 분석

### 시나리오 1: 교착 상태 반복

```
┌─────────┬─────────┐
│    A    │    B    │
│ (N1)    │ (N2)    │
└────┬────┴────┬────┘
     │ neighbors
   ┌─┴────────┬┘
   │          │
  [N1]──A→[N3]←B──[N2]
   │          │
   └──────────┘
   
시나리오:
1. A: move_to(N2) → 경로: [N1, N3, N2]
2. B: move_to(N1) → 경로: [N2, N3, N1]
3. T=1: A와 B가 동시에 N3으로 이동 시도
   → Prioritized Planning: A 우선 (ID 작음)
   → A 경로 고정, B는 회피 경로 계획
4. B 양보 시도:
   - 금지 구역: N3 (A 목표), N2, N1, ... 주변 확장
   - 금보할 위치: [N1]만 가능 → A가 이미 있음
   → 양보 실패
5. 무한 루프: B는 영원히 N2에서 대기
```

**발생 원인:**
- 금지 구역이 **양보할 모든 위치를 포함**
- A의 전체 경로가 금지됨 (requester_remaining 포함)
- 맵이 작으면 회피 경로 자체가 없을 수 있음

---

### 시나리오 2: 동적 생성 에이전트 손실

```gdscript
func spawn_enemy():
    var enemy = preload("res://enemy.tscn").instantiate()
    add_child(enemy)
    # enemy의 instance_id는 새로 할당됨
    # 기존 MAPF 데이터와 관계 없음
    # register_agent() 호출 필요하지만 자동으로 안됨

# 결과: 새 에이전트가 MAPF 시스템에 등록 안될 수 있음
```

---

### 시나리오 3: 부정확한 경로상 위치 추적

```gdscript
# _planned_path = [A, B, C, A, D] (동일 노드 반복)
# _path_index = 1 (B에서 시작)
# 이동 중...
# 어느 순간 _current_pin이 A로 돌아옴

# mapf.update_agent_position(self, A, -1) ← path_index 미전달
# MAPF 내부:
# for i in range(path.size()):
#     if path[i] == A:  # ← 첫 번째 A (인덱스 0) 찾음!
#         path_index = 0
# 실제로는 네 번째 A (인덱스 3)여야 함
# → 이후 양보 로직이 path_index=0 기준으로 작동
# → 금지 구역이 완전히 잘못됨
```

---

## 권장 개선 사항

### 🔧 우선순위 1: 긴급 수정 필요

#### 1.1 Agent State 동기화 개선
```gdscript
func update_agent_position(agent: Node, pin: Movepoint, path_index: int = -1) -> void:
    var id := _agent_id(agent)
    if _agents.has(id):
        _agents[id]["node"] = pin
        if path_index >= 0:
            _agents[id]["path_index"] = path_index
        else:
            # path_index 전달 안됨 → 경고 출력 + 기본값 사용
            push_warning("path_index not provided for %s, using 0" % agent.name)
            _agents[id]["path_index"] = 0
```

**개선 후:**
- path_index는 **반드시** animatronics에서 전달
- MAPF는 이 값을 **100% 신뢰**
- 검증 실패 시 로깅

#### 1.2 Yield 금지 구역 축소
```gdscript
const YIELD_FORBIDDEN_DEPTH := 2  # 현재 3+15+버퍼 → 2로 축소
const YIELD_LOOKAHEAD_NODES := 2  # 현재 3 → 2로 축소

func _build_forbidden_nodes_for_yield(...) -> Dictionary:
    var forbidden: Dictionary = {}
    
    # 1. 충돌 지점만 금지
    if blocked_to != null: forbidden[_node_id(blocked_to)] = true
    
    # 2. 상대방의 다음 1-2칸만 금지
    var limit: int = mini(requester_remaining.size(), YIELD_LOOKAHEAD_NODES)
    for i in range(limit):
        if requester_remaining[i] != null:
            forbidden[_node_id(requester_remaining[i])] = true
    
    # 3. 다른 에이전트의 현재 위치만 금지 (미래 경로 X)
    for id in _agents.keys():
        if id == blocker_id: continue
        var current: Movepoint = _agents[id].get("node")
        if current != null: forbidden[_node_id(current)] = true
    
    # 4. 버퍼 확장 없음 또는 최소화
    # _expand_forbidden_by_neighbors(forbidden, 0)
    
    return forbidden
```

**효과:**
- 양보 위치 선택 확률 대폭 증가
- 좁은 맵에서도 회피 경로 발견 가능

#### 1.3 Yield 선택 우선순위 재설계
```gdscript
# 현재 문제: Tier 1이 우선되어 Tier 2/3 재평가 불가

# 개선안: 3-pass 알고리즘
var candidates_tier1: Array[Movepoint] = []  # 거리 1-2 + 충돌 멀림
var candidates_tier2: Array[Movepoint] = []  # 경로상 + 충돌 멀림
var candidates_tier3: Array[Movepoint] = []  # 기타

for candidate in all_candidates:
    if is_forbidden(candidate): continue
    if not can_enter_node(blocker, candidate): continue
    
    var dist = distance_from_blocker[candidate]
    var on_path = blocker_path_ids.has(candidate)
    var conflict_dist = min(
        distance_from_blocked_to[candidate],
        distance_from_blocked_from[candidate]
    )
    
    if conflict_dist >= YIELD_MIN_CONFLICT_DISTANCE:
        if dist <= 2:
            candidates_tier1.append(candidate)
        elif on_path:
            candidates_tier2.append(candidate)
        else:
            candidates_tier3.append(candidate)

# 선택
var best: Movepoint = null
if not candidates_tier1.is_empty():
    best = candidates_tier1.min_by(func(c): return distance_from_blocker[c])
elif not candidates_tier2.is_empty():
    best = candidates_tier2.min_by(func(c): return distance_from_blocker[c])
elif not candidates_tier3.is_empty():
    best = candidates_tier3.min_by(func(c): return distance_from_blocker[c])
```

**효과:**
- 명확한 우선순위 계층
- 각 tier에서 **최적 선택** 가능
- 이해 및 디버깅 용이

### 🔧 우선순위 2: 구조적 개선

#### 2.1 Incremental Replanning
```gdscript
# 현재: request_path() 호출 시 모든 에이전트 재계획

# 개선: 영향받은 에이전트만 재계획
func request_path(...) -> Array[Movepoint]:
    var id := _agent_id(agent)
    register_agent(agent, start_pin)
    _agents[id]["node"] = start_pin
    _agents[id]["goal"] = goal_pin
    _agents[id]["must"] = must_visit_pin
    
    # 이 에이전트보다 우선순위 낮은 것들만 재계획
    _replan_from(id)
```

**효과:**
- 불필요한 재계획 제거
- 성능 O(n) → O(1) ~ O(k) (k = 낮은 우선순위 에이전트 수)

#### 2.2 Node ID 기반 추적 (Instance ID 대체)
```gdscript
# 현재: instance_id → id 변환 불안정

# 개선: Node의 고유 이름 + 경로 사용
func _agent_id(agent: Node) -> String:
    # 옵션 1: 에이전트 이름 사용 (씬 내 고유)
    if not agent.name.is_empty():
        return "agent_%s" % agent.name
    # 옵션 2: instance_id (폴백)
    return "agent_%d" % agent.get_instance_id()

# Reverse 맵 유지
func register_agent(agent: Node, start_pin: Movepoint) -> void:
    var id := _agent_id(agent)
    # ... 기존 코드 ...
    
    # ID → 약한 참조 저장 (선택사항)
    if not _agent_refs.has(id):
        _agent_refs[id] = WeakRef.new(agent)
```

**효과:**
- 씬 재로드 후에도 동일 에이전트 추적 가능
- Instance ID 변경 무관

#### 2.3 경로 유효성 상세 기록
```gdscript
enum PathStatus { VALID, TIMEOUT, UNREACHABLE, RESERVED }

func _plan_for_agent(...) -> Array[Movepoint]:
    var waypoints: Array[Movepoint] = [...]
    var merged: Array[Movepoint] = [start_pin]
    var current := start_pin
    var start_t := 0
    
    for waypoint in waypoints:
        var segment := _time_a_star(...)
        if segment.is_empty():
            # 상세 정보 기록
            state["path_status"] = PathStatus.TIMEOUT
            state["failed_at_waypoint"] = waypoint.name
            state["start_t"] = start_t
            return []
        # ...
    
    state["path_status"] = PathStatus.VALID
    return merged
```

**효과:**
- 경로 계산 실패 원인 파악 용이
- 디버깅 시간 단축

#### 2.4 동적 그래프 지원
```gdscript
# Movepoint.gd 확장
extends Marker3D
class_name Movepoint

@export var neighbors: Array[Movepoint] = []
@export var is_blocked: bool = false  # 동적 차단
@export var traversal_cost: float = 1.0  # 가중 그래프
@export var available_times: Array[int] = []  # 시간대별 가용성

var _was_blocked: bool = false

func _ready() -> void:
    _on_blocked_changed()

func set_blocked(blocked: bool) -> void:
    if is_blocked != blocked:
        is_blocked = blocked
        _on_blocked_changed()

func _on_blocked_changed() -> void:
    if is_blocked != _was_blocked:
        _was_blocked = is_blocked
        # MAPF 캐시 무효화
        var mapf = get_node_or_null("/root/MapfManager") as MapfPlanner
        if mapf != null:
            mapf.invalidate_cache()
```

**효과:**
- 동적 장애물 지원
- 확장 가능한 구조

### 🔧 우선순위 3: 안정성 개선

#### 3.1 Yield 시도 제한 개선
```gdscript
# 현재: conflict_key로 시도 횟수 제한 (불완전)

# 개선: 에이전트별 + 지점별 분리 추적
var _yield_attempt_per_agent: Dictionary = {}  # {agent_id: {node_id: count}}

func try_resolve_deadlock(...) -> bool:
    var yielder_id := ...
    var conflict_node := blocked_to
    
    if not _yield_attempt_per_agent.has(yielder_id):
        _yield_attempt_per_agent[yielder_id] = {}
    
    var node_id := _node_id(conflict_node)
    var count: int = _yield_attempt_per_agent[yielder_id].get(node_id, 0)
    
    if count >= BLOCKED_REPLAN_MAX_TIMES:
        print("[양보 불가] ... 최대 양보 횟수 초과")
        return false
    
    _yield_attempt_per_agent[yielder_id][node_id] = count + 1
    # ...
```

**효과:**
- 지점별 양보 제한 정확성 증가
- 양보자 변경 시 독립적 계산

#### 3.2 Memory Leak 방지
```gdscript
var _agents: Dictionary = {}  # ID → state
var _dead_agents: Array[String] = []  # 정리 대기 중인 ID

func unregister_agent(agent: Node) -> void:
    var id := _agent_id(agent)
    _agents.erase(id)
    _priority_order.erase(id)
    _reset_yield_attempts_for_agent(id)
    
    # 캐시도 정리
    for key in _yield_cooldown_until.keys():
        if key == id:
            _yield_cooldown_until.erase(key)
    for key in _yield_attempt_count.keys():
        if key.begins_with(id):
            _yield_attempt_count.erase(key)
    
    # 거리 캐시는 유지 (노드 구조 안정성 가정)

func _process(_delta: float) -> void:
    # 매 프레임 검증
    for id in _agents.keys():
        var agent_node = instance_from_id(int(id))
        if agent_node == null or not is_instance_valid(agent_node):
            _dead_agents.append(id)
    
    for id in _dead_agents:
        unregister_agent_by_id(id)
    _dead_agents.clear()
```

**효과:**
- 고아 레퍼런스 자동 정리
- 메모리 누수 방지

---

## 요약 테이블

| 문제 | 심각도 | 원인 | 영향 | 해결 난이도 |
|------|--------|------|------|-----------|
| Agent State 동기화 | 🔴 | path_index 미전달 | 양보 로직 오류 | 🟢 쉬움 |
| Yield 금지 구역 과도 | 🔴 | 3+15+버퍼 설정 | 양보 실패 | 🟢 쉬움 |
| Yield Tier 우선순위 | 🔴 | 재평가 불가 | 비효율 회피 | 🟡 중간 |
| O(n) 재계획 | 🔴 | 매번 전체 재계획 | 성능 저하 | 🟠 어려움 |
| Instance ID 추적 | 🟡 | ID 변경 취약 | 동적 씬 불안 | 🟡 중간 |
| 경로 유효성 미검증 | 🟡 | valid 플래그 미사용 | 원인 파악 어려움 | 🟢 쉬움 |
| 거리 캐시 미갱신 | 🟡 | clear 함수 없음 | 동적 맵 불가 | 🟡 중간 |
| Yield 제한 추적 | 🟡 | conflict_key 고정 | 제한 의미 없음 | 🟢 쉬움 |
| Yield Resume Goal | 🟡 | 고정 목표 | 복합 시나리오 실패 | 🟡 중간 |
| Movepoint 단순함 | 🟡 | 메타데이터 없음 | 확장 제한 | 🟡 중간 |

---

## 결론

**MAPF 시스템은 기본 구조는 건실하지만, 여러 구조적 문제점으로 인해 실제 게임플레이에서 불안정합니다.**

### 즉시 해결해야 할 항목:
1. ✅ Agent State 동기화 (path_index 강제)
2. ✅ Yield 금지 구역 축소 (3+15 → 2+2)
3. ✅ 경로 유효성 상세 기록
4. ✅ Instance ID → 이름 기반 추적 전환

### 중기 개선:
1. Incremental Replanning 구현
2. Yield 선택 우선순위 재설계
3. Movepoint 메타데이터 추가

### 장기 구조 개선:
1. 그래프 구조 동적화
2. Time-expanded A* 최적화
3. 병렬 처리 고려 (모바일 최적화)

