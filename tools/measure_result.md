# 대화 엔진 측정 결과

- 측정 시각: 2026-10-09 15:53
- 의도 판단 정확도: **26/26 (100%)**

| 처리 방식 | 횟수 | 평균 응답 | 최대 |
|---|---|---|---|
| 외부 API | 3 | 559ms | 971ms |
| 클라우드 AI | 5 | 1234ms | 1466ms |
| DB | 10 | 7ms | 27ms |
| 규칙 | 8 | 4ms | 9ms |

| 어르신 말 | 기대 | 결과 | 방식 | 시간 |
|---|---|---|---|---|
| 오늘 약 뭐 먹어야 돼? | med_query | ✅ | db | 27ms |
| 혈압약 언제 먹더라 | med_query | ✅ | db | 4ms |
| 약 남은 거 있어? | med_query | ✅ | db | 5ms |
| 오늘 병원 가는 날이야? | sched_query | ✅ | db | 7ms |
| 내일 일정 있나 | sched_query | ✅ | db | 3ms |
| 복지관 언제 가지 | sched_query | ✅ | db | 3ms |
| 지금 몇 시야 | time | ✅ | rule | 4ms |
| 오늘 무슨 요일이야 | time | ✅ | rule | 2ms |
| 오늘 날씨 어때 | weather | ✅ | api | 358ms |
| 비 와? | weather | ✅ | api | 971ms |
| 아이고 머리가 어지러워 | symptom_check | ✅ | rule | 3ms |
| 배가 좀 아프네 | symptom_check | ✅ | rule | 2ms |
| 음 | unclear | ✅ | rule | 9ms |
| 요즘 혼자 있으니까 외롭네 | chat | ✅ | cloud | 1199ms |
| 손녀가 주말에 온대 | chat | ✅ | cloud | 1466ms |
| 오늘 트로트 프로그램 재밌더라 | chat | ✅ | cloud | 1167ms |
| 점심에 국수 먹었어 | chat | ✅ | cloud | 1025ms |
| 우리 아파트 앞에 꽃이 폈어 | chat | ✅ | cloud | 1311ms |
| 약 뭐 묵노 | med_query | ✅ | db | 14ms |
| 오늘 약 머 묵어야 되노 | med_query | ✅ | db | 3ms |
| 내일 병원 가나 | sched_query | ✅ | db | 4ms |
| 복지관 언제 가노 | sched_query | ✅ | db | 4ms |
| 지금 몇 시고 | time | ✅ | rule | 3ms |
| 비 오나 | weather | ✅ | api | 347ms |
| 와 이리 어지럽노 | symptom_check | ✅ | rule | 6ms |
| 다리가 억수로 아푸다 | symptom_check | ✅ | rule | 4ms |
## 사투리 변환 효과 (부산·경상도 사투리 8문장)

| | 의도 판단 정확도 |
|---|---|
| 사투리 변환 없이 | 5/8 |
| 사투리 변환 후 (dialect.py) | **8/8** |

변환 없이 틀린 말: "오늘 약 머 묵어야 되노"(→ 일반 대화), "비 오나"(→ 일반 대화), "다리가 억수로 아푸다"(→ 일반 대화)
