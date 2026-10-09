# 부산·경상도 사투리 의도 판단 평가

- 문장 수: 53개 (약 질문 8 · 약 먹음 6 · 일정 6 · 시간 5 · 날씨 5 · 몸 상태 6 · 위급 5 · 다시 말하기 4 · 일상 8)
- 사투리 변환 없이: **33/53 (62%)**
- 사투리 변환 후: **48/53 (91%)**

| 어르신 말 | 기대 | 변환 없이 | 변환 후 |
|---|---|---|---|
| 오늘 약 뭐 묵어야 되노 | med_query | ✅ | ✅ |
| 약 언제 묵노 | med_query | ✅ | ✅ |
| 아침 약 뭐고 | med_query | ✅ | ✅ |
| 혈압약 묵을 시간 됐나 | med_query | ❌ chat | ✅ |
| 약 남은 거 있나 | med_query | ✅ | ✅ |
| 저녁에 무슨 약 묵노 | med_query | ✅ | ✅ |
| 약 머 묵으라 캤노 | med_query | ❌ chat | ✅ |
| 비타민 언제 묵노 | med_query | ❌ chat | ❌ chat |
| 약 묵었다 | med_taken | ❌ chat | ✅ |
| 아까 혈압약 묵었데이 | med_taken | ❌ chat | ✅ |
| 약 다 뭇다 | med_taken | ❌ chat | ✅ |
| 방금 약 챙기 묵었다 | med_taken | ❌ chat | ✅ |
| 약 무따 | med_taken | ❌ chat | ✅ |
| 아침 약 묵었심더 | med_taken | ❌ chat | ✅ |
| 내일 병원 가나 | sched_query | ✅ | ✅ |
| 복지관 언제 가노 | sched_query | ✅ | ✅ |
| 오늘 일정 있나 | sched_query | ✅ | ✅ |
| 병원 예약 언제고 | sched_query | ❌ med_query | ❌ med_query |
| 이번 주 모임 있나 | sched_query | ✅ | ✅ |
| 내일 머 하는 날이고 | sched_query | ❌ chat | ❌ chat |
| 지금 몇 시고 | time | ✅ | ✅ |
| 오늘 며칠이고 | time | ✅ | ✅ |
| 오늘 무슨 요일이고 | time | ✅ | ✅ |
| 지금 몇 시나 됐노 | time | ✅ | ✅ |
| 오늘 날짜가 우째 되노 | time | ✅ | ✅ |
| 비 오나 | weather | ❌ chat | ✅ |
| 오늘 덥나 | weather | ❌ chat | ✅ |
| 날씨 우떻노 | weather | ✅ | ✅ |
| 밖에 춥나 | weather | ❌ chat | ✅ |
| 우산 챙기야 되나 | weather | ✅ | ✅ |
| 와 이리 어지럽노 | symptom_check | ✅ | ✅ |
| 다리가 억수로 아푸다 | symptom_check | ❌ chat | ✅ |
| 머리가 쪼매 아프네 | symptom_check | ✅ | ✅ |
| 속이 안 좋다 | symptom_check | ❌ chat | ❌ chat |
| 배가 살살 아프다 | symptom_check | ✅ | ✅ |
| 기운이 하나도 없다 | symptom_check | ❌ chat | ❌ chat |
| 날 좀 살리도 | emergency | ❌ chat | ✅ |
| 자빠졌다 일어나지를 못하겠다 | emergency | ✅ | ✅ |
| 가슴이 답답하다 | emergency | ✅ | ✅ |
| 불났다 카이 | emergency | ✅ | ✅ |
| 숨이 안 쉬어진다 | emergency | ✅ | ✅ |
| 머라카노 | repeat | ❌ chat | ✅ |
| 머라 캤노 | repeat | ❌ chat | ✅ |
| 다시 말해 도 | repeat | ✅ | ✅ |
| 잘 안 들린다 | repeat | ✅ | ✅ |
| 손녀가 주말에 온다 카더라 | chat | ✅ | ✅ |
| 오늘 시장 갔다 왔데이 | chat | ✅ | ✅ |
| 텔레비전 보니까 재밌더라 | chat | ✅ | ✅ |
| 영감 생각이 많이 나네 | chat | ✅ | ✅ |
| 니는 밥 뭇나 | chat | ✅ | ✅ |
| 오늘 꽃이 억수로 이쁘게 폈더라 | chat | ✅ | ✅ |
| 이웃집 할매가 떡 갖다 줬다 | chat | ✅ | ✅ |
| 고마 심심하다 | chat | ✅ | ✅ |