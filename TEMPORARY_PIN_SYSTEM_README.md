# Agent 실시간 임시 핀(Temporary Pin) 시스템

## 개요

이 시스템은 게임 내 Agent들이 핀과 핀 사이를 이동할 때, **실시간으로 현재 위치에 임시 핸들(Pin)을 생성**하고, **경로를 동적으로 재정의**하는 기능을 제공합니다.

### 기본 개념

```
[이전 핀] ─→ [임시 핀 (현재 위치)] ─→ [다음 핀] ─→ ... ─→ [목표]
```

Agent가 이동하는 동안:
- ✅ 매 프레임마다 현재 위치에 **임시 핀** 생성
- ✅ 임시 핀을 통해 경로를 **실시간 갱신**
- ✅ 경로: `이전 핀 → 임시 핀 → 다음 핀 → 목표` 로 재정의
- ✅ 다음 핀에 도착하면 자동으로 임시 핀 정리

---

## 구현 세부사항

### 1. 추가된 변수 (animatronics.gd)

```gdscript
var _temporary_pin: Movepoint = null       # 현재 이동 중인 위치의 임시 핀
var _temp_pin_parent: Node3D = null        # 임시 핀들을 관리할 부모 노드
var _previous_pin: Movepoint = null        # 이전 핀 (왔던 곳)
var _next_pin: Movepoint = null            # 다음 핀 (가려는 곳)
```

### 2. 핵심 함수들

#### `_update_temporary_pin()`
- **목적**: 매 프레임마다 임시 핀 생성 및 위치 업데이트
- **호출 시점**: `advance_along_path()` 내 이동 중일 때
- **로직**:
  1. 경로 중간 상태 확인
  2. 이전 핀/다음 핀 설정
  3. 임시 핀이 없으면 생성, 있으면 위치 업데이트

```gdscript
func _update_temporary_pin() -> void:
	if _path_index < 0 or _path_index >= _planned_path.size() - 1:
		_cleanup_temporary_pin()
		return
	
	_previous_pin = _planned_path[_path_index]
	_next_pin = _planned_path[_path_index + 1]
	
	if _previous_pin == null or _next_pin == null:
		_cleanup_temporary_pin()
		return
	
	if _temporary_pin == null:
		_create_temporary_pin()
	
	if _temporary_pin != null:
		_temporary_pin.global_position = global_position
```

#### `_create_temporary_pin()`
- **목적**: 실제 임시 핸들 노드 생성
- **기능**:
  - 임시 핀 부모 노드 생성 (최초 1회)
  - Movepoint 인스턴스 생성
  - 이전 핀과 다음 핀을 `neighbors`로 연결
  - 씬 트리에 추가

```gdscript
func _create_temporary_pin() -> void:
	if _temp_pin_parent == null:
		_temp_pin_parent = Node3D.new()
		_temp_pin_parent.name = "%s_TemporaryPins" % self.name
		var movepoint_node: Node = movepoint
		if movepoint_node != null:
			movepoint_node.add_child(_temp_pin_parent)
	
	_temporary_pin = Movepoint.new()
	_temporary_pin.name = "%s_TempPin_%d" % [self.name, randi()]
	_temporary_pin.global_position = global_position
	_temporary_pin.neighbors = [_previous_pin, _next_pin]
	
	if _temp_pin_parent != null:
		_temp_pin_parent.add_child(_temporary_pin)
```

#### `_cleanup_temporary_pin()`
- **목적**: 임시 핀 정리 (다음 핀 도착 시 또는 종료 시)
- **호출 시점**:
  - 경로 끝에 도달했을 때
  - Agent가 씬에서 제거될 때

#### `_recalculate_path_with_temporary_pin()`
- **목적**: 임시 핀을 포함한 경로 실시간 재계산
- **경로 구조**:
  ```
  [이전 핀] → [임시 핀] → [다음 핀] → [목표]
  ```

### 3. 호출 흐름

```
advance_along_path() 호출
  ↓
이동 중 거리 계산 및 위치 업데이트
  ↓
_update_temporary_pin()  ← 임시 핀 생성/업데이트
  ↓
_recalculate_path_with_temporary_pin()  ← 경로 재계산
  ↓
다음 프레임으로 (반복)
```

---

## 사용 예시

### 기본 Agent 동작

```gdscript
# RD 에이전트가 RIGHT_HALL_ENTRANCE에서 STORAGE로 이동
move_to(PinName.RIGHT_HALL_ENTRANCE, PinName.STORAGE)

# 이동 중:
# [RIGHT_HALL_ENTRANCE] → [임시 핀 (현재 위치)] → [STORAGE] → ... → [목표]
```

### 정보 접근

```gdscript
# 현재 임시 핀 조회
var temp_pin: Movepoint = agent.get_temporary_pin()

# 이전/다음 핀 조회
var prev_pin: Movepoint = agent.get_previous_pin()
var next_pin: Movepoint = agent.get_next_pin()

# 현재 경로 조회
var path: Array[Movepoint] = agent.get_current_path()

# 경로상 현재 인덱스
var idx: int = agent.get_path_index()
```

---

## 시각화 및 디버깅

### Debug Visualizer (TemporaryPinDebugVisualizer.gd)

**기능**: 0.5초마다 모든 Agent의 임시 핀 정보를 콘솔에 출력

```
[TempPin] RD - Pin: RD_TempPin_12345 (Prev: Right_hall_entrance, Next: Storage) Path: 2/5
```

**사용 방법**:
1. 씬에 Node 추가
2. 스크립트 `res://Scripts/TemporaryPinDebugVisualizer.gd` 할당
3. 실행 시작 → 콘솔에서 임시 핀 정보 확인

---

## 시스템 특징

### ✅ 장점

1. **실시간 경로 정의**: 이동 중 항상 정확한 경로 반영
2. **부드러운 이동**: 임시 핀을 통해 거리 기반 이동 정확화
3. **경로 재계산 자동화**: 별도의 호출 없이 자동으로 경로 업데이트
4. **메모리 효율**: 임시 핀을 queue_free()로 정리
5. **이웃 관계 자동 관리**: 임시 핀이 자동으로 이전/다음 핀과 연결

### 🔍 주의사항

1. **경로 중간에만 활성화**: 경로 시작/끝에서는 임시 핀 미생성
2. **실시간 처리**: 매 프레임마다 위치 업데이트로 약간의 성능 영향
3. **MAPF와의 상호작용**: 다중 에이전트 충돌 방지 시스템과 협력

---

## 코드 변경사항 정리

### 수정된 파일

#### 1. `res://Scripts/Class/animatronics.gd`

**추가:**
- 임시 핀 관련 변수 4개
- `_update_temporary_pin()` 함수
- `_create_temporary_pin()`함수
- `_cleanup_temporary_pin()` 함수
- `_recalculate_path_with_temporary_pin()` 함수
- Getter 함수들 5개

**수정:**
- `advance_along_path()`: 이동 마지막 부분에 `_update_temporary_pin()` 호출 추가
- `advance_along_path()`: `_recalculate_path_with_temporary_pin()` 호출 추가
- `_exit_tree()`: 정리 시 `_cleanup_temporary_pin()` 호출 추가

### 새 파일

#### 1. `res://Scripts/TemporaryPinDebugVisualizer.gd`
- 임시 핀 디버그 정보 출력 스크립트

---

## 테스트 방법

### 콘솔 로그 확인

```
[TempPin] RD_TempPin_12345 created at position, connecting Right_hall_entrance <-> Storage
[TempPin] RD - Pin: RD_TempPin_12345 (Prev: Right_hall_entrance, Next: Storage) Path: 2/5
[경로 재계산] RD: 임시 핀 포함 경로 업데이트 (총 4칸)
```

### 콘솔 로그 의미

- `[TempPin] ... created`: 새 임시 핀 생성
- `[TempPin] ... (Prev, Next)`: 현재 이동 상태 표시
- `[경로 재계산]`: 경로가 임시 핀 포함으로 재계산됨

---

## 성능 최적화 팁

1. **Debug Visualizer 비활성화**: 배포 빌드에서는 DebugVisualizer 제거
2. **update_path3d 호출 최소화**: 임시 핀 생성 시마다 경로 그리기는 선택적으로
3. **Queue 정리 확인**: `queue_free()` 호출 후 다음 프레임에서 실제 정리됨

---

## 향후 확장

1. **Visual Debug Mode**: 3D 화면에서 임시 핀 시각화
2. **경로 부드러움 개선**: Catmull-Rom 스플라인 적용
3. **MultiAgent 임시 핀**: 여러 에이전트 간 임시 핀 충돌 방지
4. **경로 예측**: 다음 움직임 미리 계산

---

## 트러블슈팅

### 문제: 임시 핀이 생성되지 않음
**원인**: 경로 길이가 1 이하일 수 있음
**해결**: `_path_index >= _planned_path.size() - 1` 조건 확인

### 문제: 임시 핀 위치가 갱신되지 않음
**원인**: `advance_along_path()`가 호출되지 않을 수 있음
**해결**: RD.gd의 `_process()`에서 `advance_along_path(delta)` 호출 확인

### 문제: 메모리 누수 의심
**원인**: 임시 핀이 정리되지 않음
**해결**: `_cleanup_temporary_pin()` 호출 확인, `queue_free()` 동작 확인

---

## 라이선스 및 문서화

이 시스템은 FNAR 프로젝트의 일부입니다.
작성일: 2024
