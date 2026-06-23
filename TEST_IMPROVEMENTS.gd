## 양보 및 경로 계산 개선 테스트 스크립트
## 이 스크립트는 MapfManager와 animatronics 개선 사항을 검증합니다.
## 
## 실행 방법:
## 1. 게임을 플레이하면서 아래 항목들을 확인하세요:
## 2. 콘솔 로그를 확인하여 개선 사항이 적용되었는지 검증하세요

extends Node

class_name TestImprovements

## 테스트 1: 양보 쿨타임 단축 확인
## 예상: 양보 요청이 이전보다 더 빠르게 발생 (1200ms → 300ms)
func test_yield_cooldown_reduction() -> void:
	var expected_cooldown_ms: int = 300
	print("[TEST 1] 양보 쿨타임 단축 확인")
	print("  예상: %dms 쿨타임" % expected_cooldown_ms)
	print("  검증: MapfManager.YIELD_COOLDOWN_MS를 확인하세요")
	print("  결과: 같은 충돌에서 재요청이 빠르게 일어나면 ✓")

## 테스트 2: 양보 시도 횟수 제한 확인
## 예상: 같은 충돌에서 최대 5회만 양보 시도 후 강제 진행
func test_yield_attempt_limit() -> void:
	print("\n[TEST 2] 양보 시도 횟수 제한 확인")
	print("  예상: 최대 5회 양보 시도")
	print("  검증: 콘솔에서 '[양보 불가] 최대 양보 횟수 초과' 메시지 찾기")
	print("  결과: 무한 루프 없이 강제 진행되면 ✓")

## 테스트 3: 금지 구역 설정 개선 확인
## 예상: 양보자의 원래 경로도 금지 구역에 포함되어 반복 충돌 방지
func test_forbidden_area_improvement() -> void:
	print("\n[TEST 3] 금지 구역 설정 개선 확인")
	print("  예상: 양보자가 원래 경로로 돌아가지 않음")
	print("  검증: RD2가 양보 후 먼 곳으로 도망치지 않는지 확인")
	print("  결과: 합리적인 위치로 양보하면 ✓")

## 테스트 4: 폴백 전략 확인
## 예상: 양보 위치를 찾을 수 없을 때 현재 위치 인근에서 회피 경로 찾음
func test_fallback_strategy() -> void:
	print("\n[TEST 4] 폴백 전략 (Fallback) 확인")
	print("  예상: '[양보 폴백] 표준 양보 위치 선택 실패' 로그 출현")
	print("  검증: 매우 좁은 통로에서도 막히지 않는지 확인")
	print("  결과: 좁은 곳에서도 회피하면 ✓")

## 테스트 5: 경로 실패 디버깅 메시지 확인
## 예상: 경로 찾기 실패 시 상세한 오류 메시지 출력
func test_pathfinding_debug_messages() -> void:
	print("\n[TEST 5] 경로 찾기 실패 디버깅")
	print("  예상: '[경로 실패] ...' 메시지가 출력됨")
	print("  검증: 경로 계산 실패 원인을 파악할 수 있는지 확인")
	print("  결과: 명확한 오류 메시지가 출력되면 ✓")

## 테스트 6: 양보 거부 시 재요청 대기
## 예상: 양보가 거부되면 더 긴 대기 시간 설정 (쿨타임 * 1.5)
func test_yield_rejection_cooldown() -> void:
	print("\n[TEST 6] 양보 거부 시 대기시간")
	print("  예상: 양보 거부 후 더 긴 대기 (450ms)")
	print("  검증: 양보 거부 후 바로 재요청하지 않는지 확인")
	print("  결과: 적절한 대기 후 재요청하면 ✓")

## 테스트 7: 경로 계산 효율성
## 예상: 중복 경로 계산 감소 (프레임 드롭 없음)
func test_computation_efficiency() -> void:
	print("\n[TEST 7] 계산 효율성 확인")
	print("  예상: FPS 60 유지, 라그 없음")
	print("  검증: 게임을 플레이하면서 FPS 모니터링")
	print("  결과: 일정한 FPS 유지하면 ✓")

## 테스트 8: 콘솔 로그 과다 방지
## 예상: 1-2초에 10개 이상의 로그 없음
func test_log_spam_prevention() -> void:
	print("\n[TEST 8] 콘솔 로그 과다 방지")
	print("  예상: 불필요한 반복 로그 없음")
	print("  검증: 콘솔의 로그 빈도 확인")
	print("  결과: 정상적인 간격으로 로그 출력되면 ✓")

## 종합 테스트 실행
func run_all_tests() -> void:
	var line: String = ""
	for i in range(60):
		line += "="
	print(line)
	print("양보 및 경로 계산 개선 검증 테스트")
	print(line)
	
	test_yield_cooldown_reduction()
	test_yield_attempt_limit()
	test_forbidden_area_improvement()
	test_fallback_strategy()
	test_pathfinding_debug_messages()
	test_yield_rejection_cooldown()
	test_computation_efficiency()
	test_log_spam_prevention()
	
	print("\n" + line)
	print("모든 테스트 항목 검증 완료")
	print("각 항목별로 ✓ 표시되면 개선 사항이 정상 적용된 것입니다")
	print(line)

func _ready() -> void:
	run_all_tests()
