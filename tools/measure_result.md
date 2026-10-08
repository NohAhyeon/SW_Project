# 대화 엔진 측정 결과

- 측정 시각: 2026-10-08 20:54
- 의도 판단 정확도: **18/18 (100%)**

| 처리 방식 | 횟수 | 평균 응답 | 최대 |
|---|---|---|---|
| 외부 API | 2 | 322ms | 343ms |
| 클라우드 AI | 5 | 6318ms | 26487ms |
| DB | 6 | 30ms | 117ms |
| 규칙 | 5 | 5ms | 14ms |

| 어르신 말 | 기대 | 결과 | 방식 | 시간 |
|---|---|---|---|---|
| 오늘 약 뭐 먹어야 돼? | med_query | ✅ | db | 117ms |
| 혈압약 언제 먹더라 | med_query | ✅ | db | 18ms |
| 약 남은 거 있어? | med_query | ✅ | db | 5ms |
| 오늘 병원 가는 날이야? | sched_query | ✅ | db | 25ms |
| 내일 일정 있나 | sched_query | ✅ | db | 8ms |
| 복지관 언제 가지 | sched_query | ✅ | db | 4ms |
| 지금 몇 시야 | time | ✅ | rule | 4ms |
| 오늘 무슨 요일이야 | time | ✅ | rule | 3ms |
| 오늘 날씨 어때 | weather | ✅ | api | 343ms |
| 비 와? | weather | ✅ | api | 301ms |
| 아이고 머리가 어지러워 | symptom_check | ✅ | rule | 3ms |
| 배가 좀 아프네 | symptom_check | ✅ | rule | 3ms |
| 음 | unclear | ✅ | rule | 14ms |
| 요즘 혼자 있으니까 외롭네 | chat | ✅ | cloud | 26487ms |
| 손녀가 주말에 온대 | chat | ✅ | cloud | 1128ms |
| 오늘 트로트 프로그램 재밌더라 | chat | ✅ | cloud | 1178ms |
| 점심에 국수 먹었어 | chat | ✅ | cloud | 1329ms |
| 우리 아파트 앞에 꽃이 폈어 | chat | ✅ | cloud | 1467ms |