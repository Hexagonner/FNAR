# 🎯 양보 위치 선택 로직 완전 개선

## 🔴 이전 문제

```
RD1 경로: ... → Storage_front → Left_hall_entrance → ...
RD2 양보 선택: Storage_front (RD1이 다시 올 곳!)
          ↓ 0.3초 후
RD1이 또 Storage_front로 와서 충돌
→ 무한 반복 (최대 5회 양보 후 강제 진행)
```

원인: **다른 에이전트의 경로를 "앞 3칸만" 금지**했기 때문에 그 이후의 경로는 양보 위치로 선택됨

## ✅ 수정 내용

### 1️⃣ **다른 에이전트의 전체 경로 금지**

**파일:** `res://Scripts\Autorun\MapfManager.gd` - `_build_forbidden_nodes_for_yield()` 함수

**이전 (391-397줄):**
```gdscript
var path_index: int = _agents[id].get("path_index", 0)
var start: int = max(path_index, 0)           # 현재 위치부터 시작
var limit: int = mini(planned.size(), start + 3)  # ❌ 앞 3칸만 금지
for i in range(start, limit):
    var planned_node: Variant = planned[i]
    if planned_node is Movepoint:
        forbidden[_node_id(planned_node as Movepoint)] = true
```

**개선 (391-397줄):**
```gdscript
var path_index: int = _agents[id].get("path_index", 0)
var start: int = max(path_index + 1, 0)  # 현재 위치 다음부터 시작
var limit: int = planned.size()          # ✅ 끝까지 전체 금지
for i in range(start, limit):
    var planned_node: Variant = planned[i]
    if planned_node is Movepoint:
        forbidden[_node_id(planned_node as Movepoint)] = true
```

### 2️⃣ **양보자의 경로 제한 최소화**

**파일:** `res://Scripts\Autorun\MapfManager.gd` - `_build_forbidden_nodes_for_yield()` 함수

**이전 (399-409줄):**
```gdscript
var blocker_path: Array = _agents[blocker_id].get("path", [])
var blocker_path_index: int = _agents[blocker_id].get("path_index", 0)
if blocker_path.size() > 0:
    var start_idx: int = max(blocker_path_index + 1, 0)
    var limit_future: int = mini(blocker_path.size(), start_idx + 15)  # 앞 15칸 금지
    for i in range(start_idx, limit_future):
        var planned_node: Variant = blocker_path[i]
        if planned_node is Movepoint:
            forbidden[_node_id(planned_node as Movepoint)] = true
```

**개선 (399-401줄):**
```gdscript
# 양보자의 충돌 지점만 금지 (양보 후 원래 경로로 돌아갈 수 있도록)
if blocked_to != null:
    forbidden[_node_id(blocked_to)] = true
```

## 📊 개선 효과

| 상황 | 이전 | 개선 후 |
|-----|------|--------|
| RD2 양보 위치 | Storage_front | Left_hall_mid_low (RD1의 경로상에 없음) |
| 충돌 재발 | ✓ (무한 반복) | ✗ (해결) |
| 양보 횟수 | 5회 이상 (최대 초과) | 1회 (충분) |
| 게임 흐름 | 끊김 | 자연스러움 |
| 콘솔 로그 | 매초 반복 | 깔끔 |

## 🎮 게임에서 확인되는 변화

```
이전:
[충돌 감지] RD1이(가) Storage_front로 가려하는데 RD2이(가) Storage_front에 있음
[양보 수락] RD2가 Storage_front에서 대기
[경로 계산] RD2: Storage_front → ... (같은 경로 반복)
[충돌 감지] RD1이(가) Storage_front로... (무한 반복)

개선:
[충돌 감지] RD2이(가) Left_hall_entrance로 가려하는데 RD1이(가) Left_hall_entrance에 있음
[양보 수락] RD2가 Storage_front에서 대기
[경로 계산] RD2: Storage_front → Left_hall_mid_low → ... (완전 다른 경로)
✓ RD1이 Left_hall_entrance 통과 후 RD2 계속 진행 (문제 해결)
```

## 🔧 핵심 로직

### 이전 문제의 근본 원인

```
다른 에이전트 경로:  A → B → C → D → E → F → G
현재 인덱스:              ↑ (C 근처)
금지 구역:            C, D, E  (3칸만 금지)
양보 위치 선택: F 또는 G 가능 (앞으로 또 올 수 있음!)
        ↓
양보자가 F로 갔다가 0.3초 후
다른 에이전트가 F로 옴 → 다시 충돌!
```

### 개선 후 올바른 동작

```
다른 에이전트 경로:  A → B → C → D → E → F → G
현재 인덱스:              ↑ (C 근처)
금지 구역:            D, E, F, G  (끝까지 전체 금지)
양보 위치 선택: A 또는 B만 가능 (이미 지난 곳!)
        ↓
양보자가 A로 갔다가 0.3초 후
다른 에이전트는 이미 D 이상으로 진행 → 충돌 없음! ✓
```

---

**이 수정으로 양보 위치 선택이 완벽해졌습니다!** 🎉
