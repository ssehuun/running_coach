import { describe, it, expect } from "vitest";
import {
  timeToVDOT, vdotToTime, trainingPaces, timeToSec, fmtTime, fmtPace,
  buildWeeklySchedule, DIST_M,
} from "./calc.js";

describe("VDOT 핵심 계산", () => {
  it("timeToVDOT ↔ vdotToTime 라운드트립", () => {
    const v = timeToVDOT(10000, 40 * 60); // 10K 40:00
    const t = vdotToTime(v, 10000);
    expect(t).toBeCloseTo(40 * 60, 0); // 40분으로 복원
    expect(timeToVDOT(10000, t)).toBeCloseTo(v, 4);
  });

  it("더 빠른 기록일수록 VDOT가 높다", () => {
    expect(timeToVDOT(10000, 38 * 60)).toBeGreaterThan(timeToVDOT(10000, 42 * 60));
  });

  it("trainingPaces는 강도가 높을수록 빠르다(초/km 작다)", () => {
    const p = trainingPaces(50);
    expect(p.easy).toBeGreaterThan(p.threshold);
    expect(p.threshold).toBeGreaterThan(p.interval);
    expect(p.interval).toBeGreaterThan(p.rep);
  });
});

describe("포맷 유틸", () => {
  it("timeToSec / fmtTime / fmtPace", () => {
    expect(timeToSec("1", "30", "0")).toBe(5400);
    expect(fmtTime(5400)).toBe("1:30:00");
    expect(fmtTime(330)).toBe("5:30");
    expect(fmtPace(330)).toBe("5:30");
  });
});

describe("buildWeeklySchedule", () => {
  const paces = trainingPaces(50);
  const sched = buildWeeklySchedule({
    targetDist: "full", vdot: 50, paces, weeksLeft: 12,
    startKm: 25, raceDate: new Date("2026-09-06"), runDays: 5,
  });

  it("weeksLeft 만큼 주차를 만들고 마지막이 레이스 주", () => {
    expect(sched.weeks).toHaveLength(12);
    expect(sched.weeks[11].isRaceWeek).toBe(true);
    expect(sched.weeks[0].isRaceWeek).toBe(false);
  });

  it("비휴식일에는 paceSec가 채워진다", () => {
    for (const wk of sched.weeks) {
      for (const day of wk.days) {
        if (day.kind !== "rest" && day.k > 0) {
          expect(typeof day.paceSec).toBe("number");
          expect(day.paceSec).toBeGreaterThan(0);
        } else {
          expect(day.paceSec).toBeNull();
        }
      }
    }
  });

  it("레이스 주 일요일 거리는 목표 거리와 일치", () => {
    const raceDay = sched.weeks[11].days.find(d => d.kind === "race");
    expect(raceDay.k).toBe(Math.round(DIST_M.full / 1000));
  });
});
