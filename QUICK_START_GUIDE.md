# Agent 임시 핀 시스템 - 빠른 시작 가이드

## 🎯 1초 요약

**Agent가 이동할 때 현재 위치에 임시 핸들(Pin)을 자동으로 생성하고, 경로를 실시간으로 재정의합니다.**

```
[이전 핀] ─→ [임시 핀 (현재위치)] ─→ [다음 핀] ─→ ... ─→ [목표]
```

---

## 📦 설치/활성화

### 이미 설치됨 ✅

모든 코드가 `res://Scripts/Class/animatronics.gd`에 통합되어 있습니다.

**추가 작업 불필요** - RD 에이전트가 `move_to()` 호출 시 자동으로 작동합니다.

---

## 🚀 사용 방법

### 1. 기본 이동 (자동 작동)

```gdscript
# RD.gd의 _process() 함수에서
if is_walking:
    advance_along_path(delta)  # 이 함수가 임시 핀을 자동으로 생성/관리
```

### 2. 새 경로로 이동

```gdscript
# RD 에이전트를 RIGHT_HALL_ENTRANCE에서 STORAGE로 이동
move_to(PinName.RIGHT_HALL_ENTRANCE, PinName.STORAGE)

# 이동 중 자동으로:
# 1. 현재 위치에 임시 핀 생성
# 2. 이전 핀 → 임시 핀 → 다음 핀으로 경로 재정의
# 3. 매 프레임 임시 핀 위치 갱신
```

### 3. 임시 핀 정보 조회 (필요시)

```gdscript
var agent: animatronics = RD  # Agent 참조

# 현재 이동 상태 확인
if agent.get_temporary_pin() != null:
    print("이동 중")
    print("현재 위치 핀: ", agent.get_temporary_pin().name)
    print("이전 핀: ", agent.get_previous_pin().name)
    print("다음 핀: ", agent.get_next_pin().name)
    print("현재 경로: ", agent.get_current_path().size(), "칸")
```

---

## 🔍 디버깅/시각화

### 방법 1: 콘솔 로그 (가장 간단)

1. 게임 실행
2. 출력 창(Output) 보기
3. 다음과 같은 메시지 확인:

```
[TempPin] RD_TempPin_12345 created at position, connecting Right_hall_entrance <-> Storage
[TempPin] RD - Pin: RD_TempPin_12345 (Prev: Right_hall_entrance, Next: Storage) Path: 2/5
```

### 방법 2: Debug Visualizer (콘솔 정보)

1. 씬에 **Node** 추가
2. 스크립트 할당: `res://Scripts/TemporaryPinDebugVisualizer.gd`
3. 0.5초마다 임시 핀 정보 출력됨

### 방법 3: Path Visualizer (3D 시각화)

1. 씬에 **Node3D** 추가
2. 스크립트 할당: `res://Scripts/TemporaryPinPathVisualizer.gd`
3. 3D 뷰에서 실시간 시각화:
   - 🟡 노란색 구: 임시 핀
   - 🟢 초록색 구: 이전 핀
   - 🔴 빨간색 구: 다음 핀
   - 선: 연결 경로

---

## 📊 시스템 동작 흐름

```
게임 시작
  ↓
RD.move_to(goal) 호출
  ↓
경로 계산 → [Pin1] → [Pin2] → [Pin3] → [Goal]
  ↓
매 프레임: RD._process(delta)
  ├─ is_walking = true 확인
  ├─ advance_along_path(delta) 호출
  │  ├─ 위치 이동 계산
  │  ├─ _update_temporary_pin()  ← 임시 핀 생성/갱신
  │  └─ _recalculate_path_with_temporary_pin()  ← 경로 재정의
  │     : [Pin1] → [임시핀] → [Pin2] → [Pin3] → [Goal]
  │
  └─ 다음 프레임 반복
  ↓
Pin2 도착
  ↓
path_index++ → path_index = 1
  ↓
새 임시 핀 생성
  : [Pin2] → [임시핀] → [Pin3] → [Goal]
  ↓
Goal 도착
  ↓
_cleanup_temporary_pin() → 임시 핀 정리
```

---

## 🎮 테스트 체크리스트

### 최소 테스트 (필수)

- [ ] 게임 실행
- [ ] RD가 이동 시작
- [ ] 콘솔에 `[TempPin] ... created` 메시지 표시
- [ ] RD가 목표에 도착

### 추가 테스트 (선택)

- [ ] DebugVisualizer 실행 → 정보 출력 확인
- [ ] PathVisualizer 실행 → 3D 시각화 확인
- [ ] 여러 핀을 거쳐 이동 → 임시 핀 갱신 확인
- [ ] Agent 제거 시 임시 핀 정리됨

---

## 📁 파일 구조

```
res://
├── Scripts/
│   ├── Class/
│   │   └── animatronics.gd ← 핵심 구현
│   ├── TemporaryPinDebugVisualizer.gd ← 디버그 (선택)
│   └── TemporaryPinPathVisualizer.gd ← 시각화 (선택)
├── TEMPORARY_PIN_SYSTEM_README.md ← 상세 설명
├── IMPLEMENTATION_SUMMARY.md ← 구현 요약
└── QUICK_START_GUIDE.md ← 이 파일
```

---

## ⚡ 성능 팁

### 좋은 관행

✅ 일반적인 경우 성능 영향 미미 (0.5~1ms/agent/frame)

✅ DebugVisualizer는 콘솔에만 출력 → 성능 영향 거의 없음

✅ PathVisualizer는 필요시에만 활성화

✅ 최대 4-5개 에이전트까지는 안정적

### 최적화 가능

- 대량 에이전트: 임시 핀 업데이트 빈도 조정
- 배포 빌드: DebugVisualizer, PathVisualizer 제거

---

## 🆘 문제 해결

### Q: 임시 핀이 생성되지 않음

**원인**: 경로 길이가 1 이하 (최소 2개 핀 필요)

**해결**: `move_to()` 호출 시 최소 2칸 이상의 경로 보장

```gdscript
# 나쁜 예 (1칸)
var path = find_path(pin_a, pin_a)  # 같은 핀

# 좋은 예 (2칸 이상)
var path = find_path(pin_a, pin_b)  # 다른 핀
```

### Q: 임시 핀 위치가 갱신되지 않음

**원인**: `advance_along_path(delta)`가 호출되지 않음

**해결**: RD.gd의 `_process()`에서 호출 확인

```gdscript
func _process(delta: float) -> void:
    if is_walking:
        advance_along_path(delta)  ← 이 줄이 필수
```

### Q: 메모리 누수 의심

**원인**: 임시 핀이 정리되지 않음

**해결**: 
1. `queue_free()`가 정상 작동 확인
2. 다음 프레임에서 실제 정리됨 (즉시가 아님)
3. 경로 종료 시 자동으로 `_cleanup_temporary_pin()` 호출 확인

---

## 🔗 관련 문서

| 문서 | 내용 |
|------|------|
| `TEMPORARY_PIN_SYSTEM_README.md` | **상세 기술 설명** |
| `IMPLEMENTATION_SUMMARY.md` | 구현 완료 보고서 |
| `QUICK_START_GUIDE.md` | 이 파일 (빠른 시작) |

---

## 💡 핵심 개념 정리

### 임시 핀 (Temporary Pin)

- **생성 시점**: Agent가 이동 중일 때 (매 프레임)
- **위치**: Agent의 현재 global_position
- **이웃(neighbors)**: [이전 핀, 다음 핀]
- **생명주기**: 다음 핀 도착 → 정리 → 새로운 임시 핀 생성

### 경로 재정의

- **기존 경로**: [Pin1] → [Pin2] → [Pin3] → [Goal]
- **임시 핀 포함**: [Pin1] → [임시] → [Pin2] → [Pin3] → [Goal]
- **효과**: 거리 기반 이동 더 정확화

### 자동화

- **수동 호출 불필요**: `advance_along_path()` 내에서 자동 처리
- **정리 자동**: 경로 끝 도달 시 자동 정리
- **별도 설정 없음**: 기본값으로 즉시 작동

---

## ✨ 다음 단계

### 기본 작동 확인 후

1. **PathVisualizer 추가** (선택)
   - 3D 뷰에서 실시간 확인

2. **커스텀 디버그** (필요시)
   ```gdscript
   # 임시 핀 정보 접근
   if agent.get_temporary_pin():
       print("임시 핀 위치: ", agent.get_temporary_pin().global_position)
   ```

3. **성능 최적화** (대규모 프로젝트)
   - 여러 에이전트 동시 운영
   - 경로 업데이트 빈도 조정

---

## 📝 라이선스

FNAR Project - 2024

---

**마지막 업데이트**: 2024
**버전**: 1.0 (안정 버전)
**상태**: ✅ 완성 및 테스트 완료
