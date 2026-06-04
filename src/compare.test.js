import { describe, it, expect } from "vitest";
import {
  toISODate, planDateFor, recordPace, recordsForDay,
  perWorkout, weeklyVolume, paceTrend, adherence, staleRecordCount,
} from "./compare.js";

/* ---- 합성 플랜 & 주차 ----
   targetDate=2026-07-05(레이스), weeksLeft=2 → week2=레이스주, week1=베이스 */
const plan = { id: "P1", targetDate: "2026-07-05", weeksLeft: 2 };

const weeks = [
  {
    w: 1, phase: { name: "베이스", c: "#34d399", idx: 0 }, vol: 30, longRun: 14,
    isRaceWeek: false, isRecovery: false, dateLabel: "6/22",
    days: [
      { d: "월", k: 0, kind: "rest", paceSec: null },
      { d: "화", k: 10, kind: "speed", paceSec: 300, t: "인터벌" },
      { d: "토", k: 14, kind: "long", paceSec: 360, t: "롱런" },
    ],
  },
  {
    w: 2, phase: { name: "테이퍼", c: "#818cf8", idx: 3 }, vol: 20, longRun: 42,
    isRaceWeek: true, isRecovery: false, dateLabel: "6/29",
    days: [
      { d: "화", k: 6, kind: "speed", paceSec: 280, t: "짧은 인터벌" },
      { d: "일", k: 42, kind: "race", paceSec: 300, t: "레이스" },
    ],
  },
];

/* 날짜 확인용 */
const D_W1_HWA = toISODate(planDateFor(plan, 1, "화")); // 2026-06-23
const D_W1_TO = toISODate(planDateFor(plan, 1, "토"));  // 2026-06-27
const D_W2_IL = toISODate(planDateFor(plan, 2, "일"));  // 2026-07-05

const records = [
  // week1 화 — 명시적 연결, 계획대로 (10km @ 5:00)
  { id: "r1", date: D_W1_HWA, distanceKm: 10, durationSec: 3000, link: { planId: "P1", week: 1, day: "화", kind: "speed" } },
  // week1 토 — 자유 기록이 날짜로 매칭 (12km, 계획 14km보다 적음)
  { id: "r2", date: D_W1_TO, distanceKm: 12, durationSec: 4500, link: null },
  // week2 일 레이스 — 연결, 거의 계획대로
  { id: "r3", date: D_W2_IL, distanceKm: 42, durationSec: 13000, link: { planId: "P1", week: 2, day: "일", kind: "race" } },
  // 휴식일(월)에 찍힌 자유 러닝 — 계획 세션엔 매칭 안 됨, 추세에만 반영
  { id: "r4", date: toISODate(planDateFor(plan, 1, "월")), distanceKm: 5, durationSec: 1800, link: null },
];

describe("날짜 매핑", () => {
  it("레이스는 마지막 주 일요일 = targetDate", () => {
    expect(D_W2_IL).toBe("2026-07-05");
  });
  it("recordsForDay: 명시적 link 우선, 없으면 날짜 매칭", () => {
    expect(recordsForDay(records, plan, 1, "화").map(r => r.id)).toEqual(["r1"]);
    expect(recordsForDay(records, plan, 1, "토").map(r => r.id)).toEqual(["r2"]);
    expect(recordsForDay(records, plan, 2, "화")).toHaveLength(0); // 기록 없음
  });
});

describe("recordPace", () => {
  it("거리 0이면 null (0 나눗셈 가드)", () => {
    expect(recordPace({ distanceKm: 0, durationSec: 100 })).toBeNull();
    expect(recordPace({ distanceKm: 10, durationSec: 3000 })).toBe(300);
  });
});

describe("뷰 (a) perWorkout", () => {
  const rows = perWorkout(weeks, records, plan);
  it("휴식일 제외, 모든 훈련일 행 생성", () => {
    expect(rows).toHaveLength(4); // 화/토 + 화/일
  });
  it("계획대로면 good, 부족하면 partial, 없으면 none", () => {
    const wa = rows.find(r => r.week === 1 && r.day === "화");
    expect(wa.distRatio).toBeCloseTo(1, 5);
    expect(wa.paceDelta).toBeCloseTo(0, 5);
    expect(wa.status).toBe("good");

    const to = rows.find(r => r.week === 1 && r.day === "토");
    expect(to.distRatio).toBeCloseTo(12 / 14, 5);
    expect(to.status).toBe("partial");

    const w2hwa = rows.find(r => r.week === 2 && r.day === "화");
    expect(w2hwa.actualKm).toBeNull();
    expect(w2hwa.status).toBe("none");
  });
});

describe("뷰 (b) weeklyVolume", () => {
  const data = weeklyVolume(weeks, records, plan);
  it("주간 실제 거리 합과 완료율", () => {
    const w1 = data[0];
    expect(w1.actualVol).toBeCloseTo(22, 5);   // 10 + 12
    expect(w1.completedSessions).toBe(2);
    expect(w1.completionPct).toBe(1);

    const w2 = data[1];
    expect(w2.actualVol).toBeCloseTo(42, 5);   // 일만
    expect(w2.completedSessions).toBe(1);
    expect(w2.completionPct).toBe(0.5);
  });
});

describe("뷰 (c) paceTrend", () => {
  it("날짜순 정렬 + 이동평균, 모든 거리>0 기록 포함", () => {
    const { points, trend, min } = paceTrend(records);
    expect(points).toHaveLength(4); // 휴식일 자유 러닝(r4)도 포함
    // 날짜 오름차순
    const dates = points.map(p => p.date);
    expect([...dates].sort()).toEqual(dates);
    expect(trend).toHaveLength(points.length);
    expect(min).toBe(300); // r1=300이 최고(가장 빠름)
  });
});

describe("뷰 (d) adherence", () => {
  it("마감 세션 이행률 + 연속 기록", () => {
    const a = adherence(weeks, records, plan, new Date("2026-07-10"));
    expect(a.dueSessions).toBe(4);       // 화/토/화/일
    expect(a.completedSessions).toBe(3); // week2 화만 누락
    expect(a.adherenceRate).toBeCloseTo(0.75, 5);
    expect(a.longestStreak).toBe(2);     // 06-23, 06-27 연속
    expect(a.currentStreak).toBe(1);     // 07-05만 (06-30 누락으로 끊김)
  });

  it("미래 세션은 마감에서 제외", () => {
    const a = adherence(weeks, records, plan, new Date("2026-06-24"));
    expect(a.dueSessions).toBe(1); // 06-23 화만 마감
    expect(a.completedSessions).toBe(1);
  });
});

describe("staleRecordCount", () => {
  it("다른 planId에 연결된 기록 수", () => {
    const withStale = [...records, { id: "x", date: "2025-01-01", distanceKm: 5, durationSec: 1500, link: { planId: "OLD", week: 1, day: "화", kind: "easy" } }];
    expect(staleRecordCount(withStale, plan)).toBe(1);
  });
});
