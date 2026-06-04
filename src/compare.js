/* ============================================================
   계획 vs 실제 비교 계산 — 순수 함수 (React 무관, 테스트 대상)
   입력: weeks (buildWeeklySchedule 결과), records (RunRecord[]), plan
   ============================================================ */

export const DAY_ORDER = ["월", "화", "수", "목", "금", "토", "일"];

/* 로컬 기준 YYYY-MM-DD */
export function toISODate(d) {
  const dt = d instanceof Date ? d : new Date(d);
  const y = dt.getFullYear();
  const m = String(dt.getMonth() + 1).padStart(2, "0");
  const day = String(dt.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

/* 기록의 페이스(초/km) — 거리 0 가드 */
export function recordPace(r) {
  if (!r || !(r.distanceKm > 0)) return null;
  return r.durationSec / r.distanceKm;
}

/* (plan, 주차, 요일) → 실제 달력 날짜.
   레이스는 마지막 주 '일'(일요일)에 배치된다는 전제.
   weekSunday = raceDate - (weeksLeft-week)*7,  각 요일 = weekSunday + (dayIdx-6) */
export function planDateFor(plan, week, dayLabel) {
  const wkInRace = plan.weeksLeft - week;
  const sunday = new Date(plan.targetDate);
  sunday.setDate(sunday.getDate() - wkInRace * 7);
  const di = DAY_ORDER.indexOf(dayLabel); // 0..6
  const d = new Date(sunday);
  d.setDate(sunday.getDate() + (di - 6));
  return d;
}

/* 특정 훈련일(week, day)에 매칭되는 기록들.
   1차: 명시적 link(완료 기록 버튼). 2차: 같은 날짜의 자유 기록. */
export function recordsForDay(records, plan, week, day) {
  const linked = records.filter(r =>
    r.link && r.link.planId === plan.id && r.link.week === week && r.link.day === day);
  if (linked.length) return linked;
  const iso = toISODate(planDateFor(plan, week, day));
  return records.filter(r => !r.link && r.date === iso);
}

/* 매칭된 기록들을 하나로 합산: 총거리·평균페이스(총시간/총거리) */
function aggregate(recs) {
  if (!recs.length) return null;
  const distanceKm = recs.reduce((a, r) => a + (r.distanceKm || 0), 0);
  const durationSec = recs.reduce((a, r) => a + (r.durationSec || 0), 0);
  if (!(distanceKm > 0)) return null;
  return { distanceKm, durationSec, pace: durationSec / distanceKm, count: recs.length };
}

/* 이행도 상태: none / good / partial */
function statusOf(distRatio, paceDelta) {
  if (distRatio == null) return "none";
  const paceOk = paceDelta == null || Math.abs(paceDelta) <= 15; // ±15초/km 이내
  if (distRatio >= 0.9 && paceOk) return "good";
  return "partial";
}

/* ===== 뷰 (a) 훈련별 계획 vs 실제 ===== */
export function perWorkout(weeks, records, plan) {
  const rows = [];
  for (const wk of weeks) {
    for (const day of wk.days) {
      if (day.kind === "rest" || !(day.k > 0)) continue;
      const agg = aggregate(recordsForDay(records, plan, wk.w, day.d));
      const plannedKm = day.k;
      const plannedPace = day.paceSec ?? null;
      const actualKm = agg ? agg.distanceKm : null;
      const actualPace = agg ? agg.pace : null;
      const distRatio = agg ? actualKm / plannedKm : null;
      const paceDelta = (agg && plannedPace != null) ? actualPace - plannedPace : null;
      rows.push({
        week: wk.w, phase: wk.phase, day: day.d, kind: day.kind, t: day.t,
        dateISO: toISODate(planDateFor(plan, wk.w, day.d)),
        plannedKm, plannedPace, actualKm, actualPace, distRatio, paceDelta,
        status: statusOf(distRatio, paceDelta),
      });
    }
  }
  return rows;
}

/* ===== 뷰 (b) 주간 총량 달성률 · 완료율 ===== */
export function weeklyVolume(weeks, records, plan) {
  return weeks.map(wk => {
    const planSessions = wk.days.filter(d => d.kind !== "rest" && d.k > 0);
    let actualVol = 0;
    let completed = 0;
    for (const day of planSessions) {
      const agg = aggregate(recordsForDay(records, plan, wk.w, day.d));
      if (agg) { actualVol += agg.distanceKm; completed += 1; }
    }
    const plannedVol = wk.vol;
    return {
      week: wk.w, phase: wk.phase, isRaceWeek: wk.isRaceWeek, dateLabel: wk.dateLabel,
      plannedVol, actualVol: Math.round(actualVol * 10) / 10,
      volumeRate: plannedVol > 0 ? actualVol / plannedVol : 0,
      plannedSessions: planSessions.length, completedSessions: completed,
      completionPct: planSessions.length ? completed / planSessions.length : 0,
    };
  });
}

/* ===== 뷰 (c) 페이스 추세 (전 기록, 자유+연결) ===== */
export function paceTrend(records) {
  const pts = records
    .filter(r => r.distanceKm > 0 && r.durationSec > 0 && r.date)
    .map(r => ({
      date: r.date, pace: recordPace(r), distanceKm: r.distanceKm,
      kind: r.link ? r.link.kind : null,
    }))
    .sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0));

  // 3점 이동평균
  const trend = pts.map((p, i) => {
    const lo = Math.max(0, i - 1), hi = Math.min(pts.length - 1, i + 1);
    let sum = 0, n = 0;
    for (let j = lo; j <= hi; j++) { sum += pts[j].pace; n++; }
    return sum / n;
  });
  const paces = pts.map(p => p.pace);
  return {
    points: pts, trend,
    min: paces.length ? Math.min(...paces) : null,
    max: paces.length ? Math.max(...paces) : null,
    avg: paces.length ? paces.reduce((a, b) => a + b, 0) / paces.length : null,
  };
}

/* ===== 뷰 (d) 플랜 이행률 · 연속 기록(streak) ===== */
export function adherence(weeks, records, plan, today = new Date()) {
  const todayISO = toISODate(today);
  // 마감(오늘까지)인 계획 세션을 날짜순으로 수집
  const due = [];
  for (const wk of weeks) {
    for (const day of wk.days) {
      if (day.kind === "rest" || !(day.k > 0)) continue;
      const iso = toISODate(planDateFor(plan, wk.w, day.d));
      if (iso > todayISO) continue; // 미래는 제외
      const done = aggregate(recordsForDay(records, plan, wk.w, day.d)) != null;
      due.push({ iso, done });
    }
  }
  due.sort((a, b) => (a.iso < b.iso ? -1 : a.iso > b.iso ? 1 : 0));

  const dueSessions = due.length;
  const completedSessions = due.filter(d => d.done).length;

  // 최장 연속
  let longestStreak = 0, run = 0;
  for (const d of due) {
    if (d.done) { run++; longestStreak = Math.max(longestStreak, run); }
    else run = 0;
  }
  // 현재 연속 (가장 최근 마감 세션부터 역순)
  let currentStreak = 0;
  for (let i = due.length - 1; i >= 0; i--) {
    if (due[i].done) currentStreak++;
    else break;
  }
  return {
    dueSessions, completedSessions,
    adherenceRate: dueSessions ? completedSessions / dueSessions : 0,
    currentStreak, longestStreak,
  };
}

/* 현재 플랜에 속하지 않는(이전 플랜) 기록 수 — 안내용 */
export function staleRecordCount(records, plan) {
  if (!plan) return 0;
  return records.filter(r => r.link && r.link.planId !== plan.id).length;
}
