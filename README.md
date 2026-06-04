# 러닝 코치 (Running Coach)

VDOT 기반 마라톤 훈련 플래너. 최근 레이스 기록을 입력하면 현재 능력(VDOT)을 측정하고,
목표 대회·기록·날짜에 맞춰 시작일부터 대회일까지 주차별 훈련 스케줄을 생성합니다.

## 핵심 기능
- **VDOT 측정**: Daniels-Gilbert 공식을 직접 구현 (테이블 보간 없음)
- **거리별 예상 기록 & 훈련 페이스**: Easy / Marathon / Threshold / Interval / Repetition
- **최근 vs 역대 최고 기록**: Daniels 권장(최근 4–6주)을 기본값으로, 역대 기록 선택 시 보수 보정
- **주차별 스케줄**: 베이스 → 역치 → 특화 → 테이퍼 4단계, 회복주 자동 배치, 레이스 주 자동 구성

## 실행
```bash
npm install
npm run dev
```

## 기술 스택
React 18 + Vite

## 면책
VDOT 기반 추정치입니다. 부상 위험과 실제 컨디션을 항상 우선하세요.
