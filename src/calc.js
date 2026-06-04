/* ============================================================
   순수 계산 로직 — VDOT(Daniels-Gilbert) · 훈련 페이스 · 스케줄 생성
   React 무관. 비교 로직(compare.js)과 테스트에서 import 한다.
   ============================================================ */

export const DIST_M = { k5: 5000, k10: 10000, half: 21097.5, full: 42195 };

/* ---- Daniels-Gilbert 공식 ----
   velocity v (m/min) = dist / time(min)
   VO2 = -4.60 + 0.182258*v + 0.000104*v^2
   pct = 0.8 + 0.1894393*e^(-0.012778*t) + 0.2989558*e^(-0.1932605*t)   (t in min)
   VDOT = VO2 / pct
*/
export function timeToVDOT(distM, totalSec) {
  const tMin = totalSec / 60;
  const v = distM / tMin;
  const vo2 = -4.60 + 0.182258 * v + 0.000104 * v * v;
  const pct = 0.8 + 0.1894393 * Math.exp(-0.012778 * tMin)
    + 0.2989558 * Math.exp(-0.1932605 * tMin);
  return vo2 / pct;
}

/* VDOT + 거리 → 예상 기록(초). 속도를 역산 (이분법) */
export function vdotToTime(vdot, distM) {
  let lo = 60, hi = 60 * 600; // 1분 ~ 10시간(초)
  for (let i = 0; i < 60; i++) {
    const mid = (lo + hi) / 2;
    const est = timeToVDOT(distM, mid);
    if (est > vdot) lo = mid; else hi = mid;
  }
  return (lo + hi) / 2;
}

/* VDOT → vVO2max 속도(m/min) 근사: VO2 = vdot 일 때의 v */
export function vdotToVelocity(vdot) {
  const a = 0.000104, b = 0.182258, c = -4.60 - vdot;
  return (-b + Math.sqrt(b * b - 4 * a * c)) / (2 * a); // m/min
}

/* 훈련 페이스(초/km) — Daniels %vVO2max 기준 */
export function trainingPaces(vdot) {
  const vv = vdotToVelocity(vdot); // m/min @ 100% vVO2max
  const paceFromPct = (pct) => {
    const v = vv * pct;          // m/min
    return 1000 / v * 60;        // sec per km
  };
  return {
    easy: paceFromPct(0.68),       // E: 59-74%, 대표 ~68%
    marathon: vdotToTime(vdot, 42195) / 42.195, // M: 풀 예상페이스
    threshold: paceFromPct(0.88),  // T: ~88%
    interval: paceFromPct(0.975),  // I: ~97.5-100%
    rep: paceFromPct(1.05),        // R: 105%+
  };
}

export function timeToSec(h, m, s) {
  return (parseInt(h || 0) * 3600) + (parseInt(m || 0) * 60) + parseInt(s || 0);
}
export function fmtTime(sec) {
  sec = Math.round(sec);
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const s = sec % 60;
  if (h > 0) return `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
  return `${m}:${String(s).padStart(2, "0")}`;
}
export function fmtPace(secPerKm) {
  const m = Math.floor(secPerKm / 60);
  const s = Math.round(secPerKm % 60);
  return `${m}:${String(s).padStart(2, "0")}`;
}
export function addPace(secPerKm, delta) { return secPerKm + delta; }

export const DIST_OPTIONS = [
  { key: "k5", label: "5K", emoji: "⚡" },
  { key: "k10", label: "10K", emoji: "🏃" },
  { key: "half", label: "하프", emoji: "🎽" },
  { key: "full", label: "풀코스", emoji: "🏅" },
];
export const TARGET_OPTIONS = [
  { key: "k10", label: "10K", dist: "10km", weeks: 12 },
  { key: "half", label: "하프", dist: "21.1km", weeks: 16 },
  { key: "full", label: "풀코스", dist: "42.2km", weeks: 21 },
];

/* ====================== VDOT 등급 밴드 (앱 자체 기준) ====================== */
export const LEVELS = [
  { key: "beginner", name: "입문", min: 0, max: 42, c: "#60a5fa" },
  { key: "inter", name: "중급", min: 42, max: 48, c: "#34d399" },
  { key: "upper", name: "중상급", min: 48, max: 54, c: "#fb923c" },
  { key: "adv", name: "상급", min: 54, max: 999, c: "#f43f5e" },
];
export const GAUGE_MIN = 30, GAUGE_MAX = 66;

export function levelOf(vdot) {
  return LEVELS.find(l => vdot >= l.min && vdot < l.max) || LEVELS[LEVELS.length - 1];
}
export function levelRangeLabel(l) {
  if (l.min === 0) return `< ${l.max}`;
  if (l.max >= 999) return `${l.min}+`;
  return `${l.min}–${l.max}`;
}
export function levelRaceLabel(l, distM = 10000) {
  const fast = l.max < 999 ? fmtTime(vdotToTime(l.max, distM)) : null;
  const slow = l.min > 0 ? fmtTime(vdotToTime(l.min, distM)) : null;
  if (!slow) return `10K ${fast} 이내`;
  if (!fast) return `10K ${slow}+`;
  return `10K ${fast}–${slow}`;
}

/* ====================== 훈련 페이스 메타데이터 ====================== */
export const PACE_META = [
  {
    key: "easy", n: "Easy 이지", c: "#60a5fa", range: "59–74%",
    purpose: "유산소 기반·모세혈관·미토콘드리아 발달, 회복 촉진",
    feel: "옆사람과 편하게 대화할 수 있는 강도",
    when: "회복일·롱런 등 주간 주행량의 대부분",
  },
  {
    key: "marathon", n: "Marathon 마라톤", c: "#f43f5e", range: null,
    purpose: "글리코겐 효율·레이스 페이스 적응",
    feel: "편안하지만 집중이 필요한 강도",
    when: "특화기 롱런 후반·마라톤 페이스 주법",
  },
  {
    key: "threshold", n: "Threshold 템포", c: "#fb923c", range: "~88%",
    purpose: "젖산역치 향상 — 빠른 페이스를 더 오래 유지",
    feel: "짧은 문장만 겨우 나오는 '편안하게 힘든' 강도",
    when: "주 1회 템포런·크루즈 인터벌",
  },
  {
    key: "interval", n: "Interval 인터벌", c: "#facc15", range: "97–100%",
    purpose: "VO₂max 자극 — 최대 산소섭취 능력 향상",
    feel: "말하기 거의 불가, 3–5분 반복 후 휴식",
    when: "특화기 주 1회 (예: 1km 반복)",
  },
  {
    key: "rep", n: "Repetition 레프", c: "#a78bfa", range: "105%+",
    purpose: "무산소 파워·러닝 이코노미·스피드/폼 개선",
    feel: "전력에 가까움, 짧고 충분한 휴식",
    when: "스피드 보강 (예: 200–400m 반복)",
  },
];

/* ====================== 주차별 스케줄 생성기 ======================
   각 day에 paceSec(계획 목표 페이스, 초/km)을 함께 담아
   계획 vs 실제 비교(compare.js)가 문자열 파싱 없이 바로 읽게 한다. */
export function buildWeeklySchedule({ targetDist, vdot, paces, weeksLeft, startKm, raceDate, runDays = 5 }) {
  const peakKm = targetDist === "full" ? 65 : targetDist === "half" ? 50 : 40;
  const longMax = targetDist === "full" ? 32 : targetDist === "half" ? 24 : 18;

  const pBase = Math.round(weeksLeft * 0.30);
  const pThresh = Math.round(weeksLeft * 0.30);
  const pSpec = Math.round(weeksLeft * 0.25);
  const pTaper = weeksLeft - pBase - pThresh - pSpec;

  const phaseOf = (w) => {
    if (w <= pBase) return { name: "베이스", c: "#34d399", idx: 0 };
    if (w <= pBase + pThresh) return { name: "역치", c: "#fb923c", idx: 1 };
    if (w <= pBase + pThresh + pSpec) return { name: "특화", c: "#f43f5e", idx: 2 };
    return { name: "테이퍼", c: "#818cf8", idx: 3 };
  };

  const weeks = [];
  for (let w = 1; w <= weeksLeft; w++) {
    const ph = phaseOf(w);
    const wkInRace = weeksLeft - w; // 남은 주
    let vol;
    if (ph.idx === 0) {
      vol = startKm + (peakKm - startKm) * (w / Math.max(1, pBase)) * 0.55;
    } else if (ph.idx === 1) {
      const t = (w - pBase) / Math.max(1, pThresh);
      vol = startKm + (peakKm - startKm) * (0.55 + 0.30 * t);
    } else if (ph.idx === 2) {
      vol = peakKm * (0.95 + 0.05 * Math.sin(w));
    } else {
      const t = (w - (pBase + pThresh + pSpec)) / Math.max(1, pTaper);
      vol = peakKm * (0.7 - 0.45 * t);
    }
    if (ph.idx < 2 && w % 4 === 0) vol *= 0.8;
    vol = Math.round(vol * runDays / 5);

    let longRun;
    if (ph.idx === 0) longRun = Math.min(longMax - 6, 14 + w);
    else if (ph.idx === 1) longRun = Math.min(longMax - 2, 18 + (w - pBase));
    else if (ph.idx === 2) longRun = longMax;
    else longRun = Math.max(8, Math.round(longMax * 0.5));
    if (w === weeksLeft) longRun = DIST_M[targetDist] / 1000;

    const isRaceWeek = w === weeksLeft;
    const isRecovery = ph.idx < 2 && w % 4 === 0;

    // 계획 롱런 목표 페이스 (전체 평균 기준): 베이스는 이지에 가깝게, 이후 마라톤페이스를 섞은 중간값
    const longPace = ph.idx >= 1 ? addPace(paces.marathon, 20) : addPace(paces.marathon, 35);

    let days;
    if (isRaceWeek) {
      days = [
        { d: "월", t: "휴식", k: 0, kind: "rest", paceSec: null },
        { d: "화", t: `짧은 인터벌 ${fmtPace(paces.interval)} · 1km×2`, k: 6, kind: "speed", paceSec: paces.interval },
        { d: "수", t: `이지 ${fmtPace(paces.easy)}`, k: 5, kind: "easy", paceSec: paces.easy },
        { d: "목", t: `레이스 페이스 확인 ${fmtPace(paces.marathon)} · 3km`, k: 6, kind: "tempo", paceSec: paces.marathon },
        { d: "금", t: "완전 휴식", k: 0, kind: "rest", paceSec: null },
        { d: "토", t: "D-1 가벼운 조깅 3km", k: 3, kind: "easy", paceSec: addPace(paces.easy, 30) },
        { d: "일", t: `🏁 레이스 ${TARGET_OPTIONS.find(t => t.key === targetDist).label}`, k: Math.round(DIST_M[targetDist] / 1000), kind: "race", paceSec: paces.marathon },
      ];
    } else {
      const speedWork = ph.idx === 0
        ? `인터벌 ${fmtPace(paces.interval)} · 1km×${4 + Math.min(2, w)}`
        : ph.idx === 1
        ? `인터벌 ${fmtPace(paces.interval)} · 1.2km×6`
        : `VO₂ 인터벌 ${fmtPace(paces.interval)} · 1.2km×${ph.idx === 2 ? 6 : 5}`;
      const tempoWork = ph.idx === 0
        ? `이지 ${fmtPace(paces.easy)}`
        : ph.idx === 1
        ? `템포 ${fmtPace(paces.threshold)} · ${6 + (w - pBase)}km`
        : `마라톤페이스 ${fmtPace(paces.marathon)} · ${10}km`;
      const tempoPace = ph.idx === 0 ? paces.easy : ph.idx === 1 ? paces.threshold : paces.marathon;
      const longDetail = ph.idx >= 1
        ? `롱런 ${longRun}km (후반 ${Math.round(longRun * 0.3)}km @ ${fmtPace(paces.marathon)})`
        : `롱런 ${longRun}km @ ${fmtPace(addPace(paces.marathon, 35))}`;

      days = [
        { d: "월", t: isRecovery ? "휴식 (회복주)" : "휴식 / 코어", k: 0, kind: "rest", paceSec: null },
        { d: "화", t: speedWork, k: ph.idx === 0 ? 9 : 11, kind: "speed", time: "저녁", paceSec: paces.interval },
        { d: "수", t: `이지 ${fmtPace(paces.easy)}`, k: ph.idx === 0 ? 7 : 8, kind: "easy", time: "자유", paceSec: paces.easy },
        { d: "목", t: tempoWork, k: ph.idx === 0 ? 7 : 13, kind: ph.idx === 0 ? "easy" : "tempo", time: "저녁", paceSec: tempoPace },
        { d: "금", t: "휴식", k: 0, kind: "rest", paceSec: null },
        { d: "토", t: longDetail, k: longRun, kind: "long", time: "새벽", paceSec: longPace },
        { d: "일", t: `리커버리 ${fmtPace(addPace(paces.easy, 30))}`, k: ph.idx === 0 ? 6 : 7, kind: "easy", time: "자유", paceSec: addPace(paces.easy, 30) },
      ];
    }

    if (!isRaceWeek) {
      const activePlan = {
        3: ["화", "목", "토"],
        4: ["화", "수", "목", "토"],
        5: ["화", "수", "목", "토", "일"],
        6: ["화", "수", "목", "금", "토", "일"],
      }[runDays] || ["화", "수", "목", "토", "일"];
      const active = new Set(activePlan);
      days = days.map(day => {
        if (day.d === "금" && active.has("금"))
          return { d: "금", t: `이지 ${fmtPace(paces.easy)}`, k: 6, kind: "easy", time: "자유", paceSec: paces.easy };
        if (day.k > 0 && !active.has(day.d))
          return { d: day.d, t: isRecovery ? "휴식 (회복주)" : "휴식", k: 0, kind: "rest", paceSec: null };
        return day;
      });
    }

    let dateLabel = "";
    if (raceDate) {
      const d = new Date(raceDate);
      d.setDate(d.getDate() - wkInRace * 7);
      dateLabel = `${d.getMonth() + 1}/${d.getDate()}`;
    }

    weeks.push({ w, phase: ph, vol, longRun, days, isRaceWeek, isRecovery, dateLabel, dMinus: wkInRace });
  }
  return { weeks, phases: { pBase, pThresh, pSpec, pTaper, peakKm } };
}
