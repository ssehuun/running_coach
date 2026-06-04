import { useState } from "react";

/* ============================================================
   VDOT 러닝 코치 앱 — Daniels-Gilbert 공식 직접 구현 버전
   ============================================================ */

const DIST_M = { k5: 5000, k10: 10000, half: 21097.5, full: 42195 };

/* ---- Daniels-Gilbert 공식 ----
   velocity v (m/min) = dist / time(min)
   VO2 = -4.60 + 0.182258*v + 0.000104*v^2
   pct = 0.8 + 0.1894393*e^(-0.012778*t) + 0.2989558*e^(-0.1932605*t)   (t in min)
   VDOT = VO2 / pct
*/
function timeToVDOT(distM, totalSec) {
  const tMin = totalSec / 60;
  const v = distM / tMin;
  const vo2 = -4.60 + 0.182258 * v + 0.000104 * v * v;
  const pct = 0.8 + 0.1894393 * Math.exp(-0.012778 * tMin)
    + 0.2989558 * Math.exp(-0.1932605 * tMin);
  return vo2 / pct;
}

/* VDOT + 거리 → 예상 기록(초). 속도를 역산 (이분법) */
function vdotToTime(vdot, distM) {
  // 주어진 vdot에서 distM를 달리는 시간을 찾는다
  let lo = 60, hi = 60 * 600; // 1분 ~ 10시간(초)
  for (let i = 0; i < 60; i++) {
    const mid = (lo + hi) / 2;
    const est = timeToVDOT(distM, mid);
    if (est > vdot) lo = mid; else hi = mid;
  }
  return (lo + hi) / 2;
}

/* VDOT → vVO2max 속도(m/min) 근사: VO2 = vdot 일 때의 v */
function vdotToVelocity(vdot) {
  // -4.60 + 0.182258 v + 0.000104 v^2 = vdot  → 근의 공식
  const a = 0.000104, b = 0.182258, c = -4.60 - vdot;
  return (-b + Math.sqrt(b * b - 4 * a * c)) / (2 * a); // m/min
}

/* 훈련 페이스(초/km) — Daniels %vVO2max 기준 */
function trainingPaces(vdot) {
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

function timeToSec(h, m, s) {
  return (parseInt(h || 0) * 3600) + (parseInt(m || 0) * 60) + parseInt(s || 0);
}
function fmtTime(sec) {
  sec = Math.round(sec);
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const s = sec % 60;
  if (h > 0) return `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
  return `${m}:${String(s).padStart(2, "0")}`;
}
function fmtPace(secPerKm) {
  const m = Math.floor(secPerKm / 60);
  const s = Math.round(secPerKm % 60);
  return `${m}:${String(s).padStart(2, "0")}`;
}
function addPace(secPerKm, delta) { return secPerKm + delta; }

const DIST_OPTIONS = [
  { key: "k5", label: "5K", emoji: "⚡" },
  { key: "k10", label: "10K", emoji: "🏃" },
  { key: "half", label: "하프", emoji: "🎽" },
  { key: "full", label: "풀코스", emoji: "🏅" },
];
const TARGET_OPTIONS = [
  { key: "k10", label: "10K", dist: "10km", weeks: 12 },
  { key: "half", label: "하프", dist: "21.1km", weeks: 16 },
  { key: "full", label: "풀코스", dist: "42.2km", weeks: 21 },
];

const ACCENT = "#22d3ee";
const BG = "#0a0e17";

/* ====================== 주차별 스케줄 생성기 ====================== */
function buildWeeklySchedule({ targetDist, vdot, paces, weeksLeft, startKm, raceDate }) {
  const peakKm = targetDist === "full" ? 65 : targetDist === "half" ? 50 : 40;
  const longMax = targetDist === "full" ? 32 : targetDist === "half" ? 24 : 18;

  // 페이즈 경계 (비율)
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
    // 주간 거리: 베이스에서 점진 증가, 특화에서 피크, 테이퍼에서 급감
    let vol;
    if (ph.idx === 0) {
      vol = startKm + (peakKm - startKm) * (w / Math.max(1, pBase)) * 0.55;
    } else if (ph.idx === 1) {
      const t = (w - pBase) / Math.max(1, pThresh);
      vol = startKm + (peakKm - startKm) * (0.55 + 0.30 * t);
    } else if (ph.idx === 2) {
      vol = peakKm * (0.95 + 0.05 * Math.sin(w)); // 피크 부근 변동
    } else {
      const t = (w - (pBase + pThresh + pSpec)) / Math.max(1, pTaper);
      vol = peakKm * (0.7 - 0.45 * t);
    }
    // 회복주(4주마다) 살짝 감량
    if (ph.idx < 2 && w % 4 === 0) vol *= 0.8;
    vol = Math.round(vol);

    // 롱런 거리
    let longRun;
    if (ph.idx === 0) longRun = Math.min(longMax - 6, 14 + w);
    else if (ph.idx === 1) longRun = Math.min(longMax - 2, 18 + (w - pBase));
    else if (ph.idx === 2) longRun = longMax;
    else longRun = Math.max(8, Math.round(longMax * 0.5));
    if (w === weeksLeft) longRun = DIST_M[targetDist] / 1000; // 레이스 주

    const isRaceWeek = w === weeksLeft;
    const isRecovery = ph.idx < 2 && w % 4 === 0;

    // 요일 구성
    let days;
    if (isRaceWeek) {
      days = [
        { d: "월", t: "휴식", k: 0, kind: "rest" },
        { d: "화", t: `짧은 인터벌 ${fmtPace(paces.interval)} · 1km×2`, k: 6, kind: "speed" },
        { d: "수", t: `이지 ${fmtPace(paces.easy)}`, k: 5, kind: "easy" },
        { d: "목", t: `레이스 페이스 확인 ${fmtPace(paces.marathon)} · 3km`, k: 6, kind: "tempo" },
        { d: "금", t: "완전 휴식", k: 0, kind: "rest" },
        { d: "토", t: "D-1 가벼운 조깅 3km", k: 3, kind: "easy" },
        { d: "일", t: `🏁 레이스 ${TARGET_OPTIONS.find(t => t.key === targetDist).label}`, k: Math.round(DIST_M[targetDist] / 1000), kind: "race" },
      ];
    } else {
      // 페이즈별 핵심 훈련
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
      const longDetail = ph.idx >= 1
        ? `롱런 ${longRun}km (후반 ${Math.round(longRun * 0.3)}km @ ${fmtPace(paces.marathon)})`
        : `롱런 ${longRun}km @ ${fmtPace(addPace(paces.marathon, 35))}`;

      days = [
        { d: "월", t: isRecovery ? "휴식 (회복주)" : "휴식 / 코어", k: 0, kind: "rest" },
        { d: "화", t: speedWork, k: ph.idx === 0 ? 9 : 11, kind: "speed", time: "저녁" },
        { d: "수", t: `이지 ${fmtPace(paces.easy)}`, k: ph.idx === 0 ? 7 : 8, kind: "easy", time: "자유" },
        { d: "목", t: tempoWork, k: ph.idx === 0 ? 7 : 13, kind: ph.idx === 0 ? "easy" : "tempo", time: "저녁" },
        { d: "금", t: "휴식", k: 0, kind: "rest" },
        { d: "토", t: longDetail, k: longRun, kind: "long", time: "새벽" },
        { d: "일", t: `리커버리 ${fmtPace(addPace(paces.easy, 30))}`, k: ph.idx === 0 ? 6 : 7, kind: "easy", time: "자유" },
      ];
    }

    // 날짜 라벨
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

const kindStyle = {
  rest: { c: "#64748b", bg: "rgba(100,116,139,0.12)" },
  easy: { c: "#60a5fa", bg: "rgba(96,165,250,0.1)" },
  speed: { c: "#facc15", bg: "rgba(250,204,21,0.1)" },
  tempo: { c: "#fb923c", bg: "rgba(251,146,60,0.1)" },
  long: { c: "#f43f5e", bg: "rgba(244,63,94,0.1)" },
  race: { c: "#22d3ee", bg: "rgba(34,211,238,0.15)" },
};

const inputStyle = {
  width: "100%", textAlign: "center", padding: "16px 0",
  background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)",
  borderRadius: 12, color: "#fff", fontSize: 24, fontWeight: 800,
  fontVariantNumeric: "tabular-nums", outline: "none",
};
const colonStyle = { fontSize: 22, fontWeight: 800, color: "#475569" };
const labelStyle = {
  display: "block", fontSize: 12, fontWeight: 700, color: "#64748b",
  marginBottom: 10, letterSpacing: "0.02em",
};

/* 안정적인 참조를 위해 컴포넌트는 모듈 스코프에 정의
   (App 내부에 정의하면 매 렌더마다 새 함수가 되어 input이 리마운트되고 상태가 사라짐) */
function Phone({ children }) {
  return (
    <div style={{
      maxWidth: 390, margin: "0 auto", minHeight: "100vh", background: BG, color: "#e2e8f0",
      fontFamily: "'Noto Sans KR', 'Apple SD Gothic Neo', sans-serif", position: "relative",
    }}>{children}</div>
  );
}
function StatusBar({ title, onBack }) {
  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 12, padding: "18px 20px 14px",
      borderBottom: "1px solid rgba(255,255,255,0.05)", position: "sticky", top: 0,
      background: BG, zIndex: 10,
    }}>
      {onBack && <button onClick={onBack} style={{
        background: "rgba(255,255,255,0.06)", border: "none", color: "#94a3b8",
        width: 32, height: 32, borderRadius: 10, cursor: "pointer", fontSize: 16,
      }}>←</button>}
      <span style={{ fontSize: 16, fontWeight: 800 }}>{title}</span>
    </div>
  );
}

export default function App() {
  const [screen, setScreen] = useState("input");
  const [recordDist, setRecordDist] = useState("k10");
  const [h, setH] = useState("");
  const [m, setM] = useState("");
  const [s, setS] = useState("");
  const [weeklyKm, setWeeklyKm] = useState("");
  const [isRecent, setIsRecent] = useState(true);
  const [vdot, setVdot] = useState(null);

  const [targetDist, setTargetDist] = useState("full");
  const [targetH, setTargetH] = useState("");
  const [targetM, setTargetM] = useState("");
  const [targetDate, setTargetDate] = useState("");
  const [expandedWeek, setExpandedWeek] = useState(1);

  function runAssessment() {
    const sec = timeToSec(h, m, s);
    if (sec <= 0) return;
    setVdot(timeToVDOT(DIST_M[recordDist], sec));
    setScreen("result");
  }

  /* ---------- SCREEN 1: 기록 입력 ---------- */
  if (screen === "input") {
    const sec = timeToSec(h, m, s);
    return (
      <Phone>
        <div style={{ padding: "44px 20px 14px" }}>
          <div style={{
            display: "inline-block", background: `${ACCENT}22`, color: ACCENT, fontSize: 11,
            fontWeight: 700, padding: "4px 12px", borderRadius: 100, letterSpacing: "0.1em", marginBottom: 16,
          }}>STEP 1 / 3</div>
          <h1 style={{ fontSize: 26, fontWeight: 900, margin: "0 0 8px", letterSpacing: "-0.03em" }}>
            현재 기록을<br />입력하세요
          </h1>
          <p style={{ color: "#64748b", fontSize: 13, margin: 0, lineHeight: 1.6 }}>
            가장 정확한 측정을 위해 <strong style={{ color: "#94a3b8" }}>최근 4–6주 내 전력 기록</strong>을 사용하세요.
          </p>
        </div>

        <div style={{ padding: "8px 20px" }}>
          <label style={labelStyle}>기록 종목</label>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 8, marginBottom: 22 }}>
            {DIST_OPTIONS.map(d => (
              <button key={d.key} onClick={() => setRecordDist(d.key)} style={{
                padding: "14px 4px", borderRadius: 14, cursor: "pointer",
                border: `1px solid ${recordDist === d.key ? ACCENT : "rgba(255,255,255,0.1)"}`,
                background: recordDist === d.key ? `${ACCENT}1a` : "rgba(255,255,255,0.03)",
                color: recordDist === d.key ? ACCENT : "#94a3b8",
              }}>
                <div style={{ fontSize: 18, marginBottom: 4 }}>{d.emoji}</div>
                <div style={{ fontSize: 12, fontWeight: 700 }}>{d.label}</div>
              </button>
            ))}
          </div>

          <label style={labelStyle}>기록 (시 : 분 : 초)</label>
          <div style={{ display: "flex", gap: 8, alignItems: "center", marginBottom: 22 }}>
            <input value={h} onChange={e => setH(e.target.value.replace(/\D/g, ""))} placeholder="0" maxLength={1} inputMode="numeric" style={inputStyle} />
            <span style={colonStyle}>:</span>
            <input value={m} onChange={e => setM(e.target.value.replace(/\D/g, ""))} placeholder="00" maxLength={2} inputMode="numeric" style={inputStyle} />
            <span style={colonStyle}>:</span>
            <input value={s} onChange={e => setS(e.target.value.replace(/\D/g, ""))} placeholder="00" maxLength={2} inputMode="numeric" style={inputStyle} />
          </div>

          {/* 최근 vs 역대최고 선택 + 안내 */}
          <label style={labelStyle}>이 기록은?</label>
          <div style={{ display: "flex", gap: 8, marginBottom: 10 }}>
            <button onClick={() => setIsRecent(true)} style={{
              flex: 1, padding: "12px", borderRadius: 12, cursor: "pointer",
              border: `1px solid ${isRecent ? ACCENT : "rgba(255,255,255,0.1)"}`,
              background: isRecent ? `${ACCENT}1a` : "rgba(255,255,255,0.03)",
              color: isRecent ? ACCENT : "#94a3b8", fontSize: 13, fontWeight: 700,
            }}>최근 4–6주 기록</button>
            <button onClick={() => setIsRecent(false)} style={{
              flex: 1, padding: "12px", borderRadius: 12, cursor: "pointer",
              border: `1px solid ${!isRecent ? "#fb923c" : "rgba(255,255,255,0.1)"}`,
              background: !isRecent ? "rgba(251,146,60,0.12)" : "rgba(255,255,255,0.03)",
              color: !isRecent ? "#fb923c" : "#94a3b8", fontSize: 13, fontWeight: 700,
            }}>역대 최고 기록</button>
          </div>
          <div style={{
            padding: "11px 14px", borderRadius: 12, marginBottom: 22, fontSize: 12, lineHeight: 1.6,
            background: isRecent ? "rgba(34,211,238,0.08)" : "rgba(251,146,60,0.08)",
            border: `1px solid ${isRecent ? "rgba(34,211,238,0.2)" : "rgba(251,146,60,0.25)"}`,
            color: "#94a3b8",
          }}>
            {isRecent
              ? "✅ Daniels 권장 방식입니다. 현재 체력을 정확히 반영해 안전한 훈련 페이스가 나옵니다."
              : "⚠️ 역대 최고 기록은 과거 체력입니다. 현재보다 빠른 페이스가 나와 부상·오버트레이닝 위험이 커집니다. 측정 시 VDOT를 보수적으로 낮춰 적용합니다."}
          </div>

          <label style={labelStyle}>주간 평균 거리 (km) — 선택</label>
          <input value={weeklyKm} onChange={e => setWeeklyKm(e.target.value.replace(/\D/g, ""))} placeholder="예: 25" inputMode="numeric" style={{ ...inputStyle, fontSize: 18, marginBottom: 28 }} />

          <button onClick={runAssessment} disabled={sec <= 0} style={{
            width: "100%", padding: 18, borderRadius: 16, border: "none",
            cursor: sec > 0 ? "pointer" : "not-allowed",
            background: sec > 0 ? `linear-gradient(135deg, ${ACCENT}, #0891b2)` : "rgba(255,255,255,0.08)",
            color: sec > 0 ? "#06141a" : "#475569", fontSize: 16, fontWeight: 800,
            boxShadow: sec > 0 ? `0 8px 24px ${ACCENT}44` : "none", marginBottom: 30,
          }}>현재 능력 측정하기 →</button>
        </div>
      </Phone>
    );
  }

  /* ---------- SCREEN 2: 측정 결과 ---------- */
  if (screen === "result") {
    // 역대최고면 보수적으로 -1.5 보정
    const effVdot = isRecent ? vdot : vdot - 1.5;
    const paces = trainingPaces(effVdot);
    const preds = DIST_OPTIONS.map(d => ({ label: d.label, time: fmtTime(vdotToTime(effVdot, DIST_M[d.key])) }));
    const level = effVdot >= 54 ? "상급" : effVdot >= 48 ? "중상급" : effVdot >= 42 ? "중급" : "입문";

    return (
      <Phone>
        <StatusBar title="능력 측정 결과" onBack={() => setScreen("input")} />
        <div style={{ padding: "24px 20px 8px", textAlign: "center" }}>
          <div style={{ fontSize: 12, color: "#64748b", marginBottom: 6 }}>당신의 VDOT</div>
          <div style={{
            fontSize: 64, fontWeight: 900, letterSpacing: "-0.04em", lineHeight: 1,
            background: `linear-gradient(135deg, ${ACCENT}, #818cf8)`,
            WebkitBackgroundClip: "text", WebkitTextFillColor: "transparent",
          }}>{effVdot.toFixed(1)}</div>
          <div style={{
            display: "inline-block", marginTop: 10, background: `${ACCENT}1a`, color: ACCENT,
            fontSize: 12, fontWeight: 700, padding: "4px 14px", borderRadius: 100,
          }}>{level} 러너</div>
          {!isRecent && <div style={{ marginTop: 8, fontSize: 11, color: "#fb923c" }}>역대 기록 기준 보수 보정 적용됨</div>}
        </div>

        <div style={{ padding: "20px" }}>
          <div style={{ fontSize: 13, fontWeight: 700, color: "#64748b", marginBottom: 10 }}>거리별 예상 기록</div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(2, 1fr)", gap: 8, marginBottom: 24 }}>
            {preds.map(p => (
              <div key={p.label} style={{
                background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.07)",
                borderRadius: 14, padding: "14px 16px", display: "flex", justifyContent: "space-between", alignItems: "center",
              }}>
                <span style={{ fontSize: 13, color: "#94a3b8" }}>{p.label}</span>
                <span style={{ fontSize: 16, fontWeight: 800, fontVariantNumeric: "tabular-nums" }}>{p.time}</span>
              </div>
            ))}
          </div>

          <div style={{ fontSize: 13, fontWeight: 700, color: "#64748b", marginBottom: 10 }}>맞춤 훈련 페이스 (/km)</div>
          <div style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.07)", borderRadius: 14, overflow: "hidden", marginBottom: 28 }}>
            {[
              { n: "Easy (이지)", p: paces.easy, c: "#60a5fa" },
              { n: "Marathon (마라톤)", p: paces.marathon, c: "#f43f5e" },
              { n: "Threshold (템포)", p: paces.threshold, c: "#fb923c" },
              { n: "Interval (인터벌)", p: paces.interval, c: "#facc15" },
              { n: "Repetition (레프)", p: paces.rep, c: "#a78bfa" },
            ].map((row, i, a) => (
              <div key={row.n} style={{
                display: "flex", justifyContent: "space-between", alignItems: "center", padding: "13px 16px",
                borderBottom: i < a.length - 1 ? "1px solid rgba(255,255,255,0.04)" : "none",
              }}>
                <span style={{ fontSize: 13, color: "#cbd5e1" }}>{row.n}</span>
                <span style={{ fontSize: 16, fontWeight: 800, color: row.c, fontVariantNumeric: "tabular-nums" }}>{fmtPace(row.p)}</span>
              </div>
            ))}
          </div>

          <button onClick={() => setScreen("target")} style={{
            width: "100%", padding: 18, borderRadius: 16, border: "none", cursor: "pointer",
            background: `linear-gradient(135deg, ${ACCENT}, #0891b2)`, color: "#06141a",
            fontSize: 16, fontWeight: 800, boxShadow: `0 8px 24px ${ACCENT}44`, marginBottom: 30,
          }}>목표 대회 설정하기 →</button>
        </div>
      </Phone>
    );
  }

  /* ---------- SCREEN 3: 목표 입력 ---------- */
  if (screen === "target") {
    const effVdot = isRecent ? vdot : vdot - 1.5;
    const goalSec = timeToSec(targetH, targetM, 0);
    let needVdot = goalSec > 0 ? timeToVDOT(DIST_M[targetDist], goalSec) : null;
    const gap = needVdot ? needVdot - effVdot : null;
    const canProceed = goalSec > 0 && targetDate;

    return (
      <Phone>
        <StatusBar title="목표 대회 설정" onBack={() => setScreen("result")} />
        <div style={{ padding: "20px" }}>
          <div style={{
            display: "inline-block", background: `${ACCENT}22`, color: ACCENT, fontSize: 11,
            fontWeight: 700, padding: "4px 12px", borderRadius: 100, letterSpacing: "0.1em", marginBottom: 16,
          }}>STEP 3 / 3</div>

          <label style={labelStyle}>대회 부문</label>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 8, marginBottom: 24 }}>
            {TARGET_OPTIONS.map(t => (
              <button key={t.key} onClick={() => setTargetDist(t.key)} style={{
                padding: "16px 4px", borderRadius: 14, cursor: "pointer",
                border: `1px solid ${targetDist === t.key ? ACCENT : "rgba(255,255,255,0.1)"}`,
                background: targetDist === t.key ? `${ACCENT}1a` : "rgba(255,255,255,0.03)",
                color: targetDist === t.key ? ACCENT : "#94a3b8",
              }}>
                <div style={{ fontSize: 15, fontWeight: 800 }}>{t.label}</div>
                <div style={{ fontSize: 10, color: "#475569", marginTop: 3 }}>{t.dist}</div>
              </button>
            ))}
          </div>

          <label style={labelStyle}>목표 기록 (시 : 분)</label>
          <div style={{ display: "flex", gap: 8, alignItems: "center", marginBottom: 24 }}>
            <input value={targetH} onChange={e => setTargetH(e.target.value.replace(/\D/g, ""))} placeholder="3" maxLength={1} inputMode="numeric" style={inputStyle} />
            <span style={colonStyle}>시간</span>
            <input value={targetM} onChange={e => setTargetM(e.target.value.replace(/\D/g, ""))} placeholder="30" maxLength={2} inputMode="numeric" style={inputStyle} />
            <span style={colonStyle}>분</span>
          </div>

          <label style={labelStyle}>대회 날짜</label>
          <input type="date" value={targetDate} onChange={e => setTargetDate(e.target.value)} style={{ ...inputStyle, fontSize: 16, marginBottom: 20, colorScheme: "dark", padding: "16px" }} />

          {gap !== null && (
            <div style={{
              padding: "14px 16px", borderRadius: 14, marginBottom: 20,
              background: gap > 6 ? "rgba(244,63,94,0.1)" : gap > 0 ? "rgba(251,146,60,0.1)" : "rgba(52,211,153,0.1)",
              border: `1px solid ${gap > 6 ? "rgba(244,63,94,0.3)" : gap > 0 ? "rgba(251,146,60,0.3)" : "rgba(52,211,153,0.3)"}`,
            }}>
              <div style={{ fontSize: 13, fontWeight: 700, marginBottom: 4, color: gap > 6 ? "#f43f5e" : gap > 0 ? "#fb923c" : "#34d399" }}>
                {gap > 6 ? "⚠️ 매우 도전적인 목표" : gap > 0 ? "🎯 충분히 도전 가능" : "✅ 현재 능력으로 달성 가능"}
              </div>
              <div style={{ fontSize: 12, color: "#94a3b8", lineHeight: 1.6 }}>
                {gap > 0
                  ? `필요 VDOT ${needVdot.toFixed(1)} — 현재보다 ${gap.toFixed(1)} 향상이 필요합니다.`
                  : `현재 VDOT ${effVdot.toFixed(1)}은 이미 목표 수준입니다. 컨디션 관리에 집중하세요.`}
              </div>
            </div>
          )}

          <button onClick={() => { setExpandedWeek(1); setScreen("schedule"); }} disabled={!canProceed} style={{
            width: "100%", padding: 18, borderRadius: 16, border: "none",
            cursor: canProceed ? "pointer" : "not-allowed",
            background: canProceed ? `linear-gradient(135deg, ${ACCENT}, #0891b2)` : "rgba(255,255,255,0.08)",
            color: canProceed ? "#06141a" : "#475569", fontSize: 16, fontWeight: 800,
            boxShadow: canProceed ? `0 8px 24px ${ACCENT}44` : "none", marginBottom: 30,
          }}>주차별 스케줄 생성 →</button>
        </div>
      </Phone>
    );
  }

  /* ---------- SCREEN 4: 주차별 전체 스케줄 ---------- */
  if (screen === "schedule") {
    const effVdot = isRecent ? vdot : vdot - 1.5;
    const goalSec = timeToSec(targetH, targetM, 0);
    const needVdot = timeToVDOT(DIST_M[targetDist], goalSec);
    // 훈련 페이스는 목표와 현재의 중간 지점에서 시작해 목표로 수렴 (간단히 목표 기준)
    const paces = trainingPaces(needVdot);
    const targetLabel = TARGET_OPTIONS.find(t => t.key === targetDist).label;

    const raceDate = new Date(targetDate);
    const today = new Date();
    const daysLeft = Math.ceil((raceDate - today) / (1000 * 60 * 60 * 24));
    const weeksLeft = Math.max(4, Math.ceil(daysLeft / 7));
    const startKm = parseInt(weeklyKm) || 25;

    // useMemo는 조건부(early return 이후)에서 호출하면 Hooks 규칙 위반이므로 일반 호출로 계산
    const { weeks } = buildWeeklySchedule({ targetDist, vdot: needVdot, paces, weeksLeft, startKm, raceDate });

    return (
      <Phone>
        <StatusBar title={`${targetLabel} 훈련 스케줄`} onBack={() => setScreen("target")} />

        {/* 요약 헤더 */}
        <div style={{
          margin: "14px 16px", background: `linear-gradient(135deg, ${ACCENT}18, transparent)`,
          border: `1px solid ${ACCENT}33`, borderRadius: 18, padding: 16,
        }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 }}>
            <div>
              <div style={{ fontSize: 11, color: "#64748b" }}>목표</div>
              <div style={{ fontSize: 19, fontWeight: 900 }}>{targetLabel} {targetH}:{String(targetM).padStart(2, "0")}</div>
            </div>
            <div style={{ textAlign: "right" }}>
              <div style={{ fontSize: 11, color: "#64748b" }}>대회까지</div>
              <div style={{ fontSize: 19, fontWeight: 900, color: ACCENT }}>D-{daysLeft > 0 ? daysLeft : 0}</div>
            </div>
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 8 }}>
            {[
              { v: `${weeksLeft}주`, l: "총 기간" },
              { v: needVdot.toFixed(1), l: "목표 VDOT" },
              { v: fmtPace(paces.marathon), l: "레이스 페이스" },
            ].map(x => (
              <div key={x.l} style={{ background: "rgba(0,0,0,0.3)", borderRadius: 10, padding: "8px 6px", textAlign: "center" }}>
                <div style={{ fontSize: 14, fontWeight: 800, color: ACCENT }}>{x.v}</div>
                <div style={{ fontSize: 9, color: "#475569", marginTop: 2 }}>{x.l}</div>
              </div>
            ))}
          </div>
        </div>

        {/* 페이즈 범례 */}
        <div style={{ display: "flex", gap: 6, padding: "0 16px 10px", flexWrap: "wrap" }}>
          {[
            { n: "베이스", c: "#34d399" }, { n: "역치", c: "#fb923c" },
            { n: "특화", c: "#f43f5e" }, { n: "테이퍼", c: "#818cf8" },
          ].map(p => (
            <div key={p.n} style={{ display: "flex", alignItems: "center", gap: 5, fontSize: 11, color: "#94a3b8" }}>
              <span style={{ width: 8, height: 8, borderRadius: 2, background: p.c }} />{p.n}
            </div>
          ))}
        </div>

        {/* 주차별 아코디언 */}
        <div style={{ padding: "0 16px 32px" }}>
          {weeks.map((wk) => {
            const open = expandedWeek === wk.w;
            return (
              <div key={wk.w} style={{
                marginBottom: 8, borderRadius: 14, overflow: "hidden",
                border: `1px solid ${open ? wk.phase.c + "55" : "rgba(255,255,255,0.06)"}`,
                background: wk.isRaceWeek ? "rgba(34,211,238,0.06)" : "rgba(255,255,255,0.02)",
              }}>
                {/* 주차 헤더 */}
                <button onClick={() => setExpandedWeek(open ? -1 : wk.w)} style={{
                  width: "100%", display: "flex", alignItems: "center", gap: 10,
                  padding: "13px 14px", background: "transparent", border: "none", cursor: "pointer",
                  textAlign: "left",
                }}>
                  <span style={{ width: 4, height: 32, borderRadius: 4, background: wk.phase.c, flexShrink: 0 }} />
                  <div style={{ flex: 1 }}>
                    <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                      <span style={{ fontSize: 14, fontWeight: 800, color: "#e2e8f0" }}>
                        {wk.isRaceWeek ? "🏁 레이스 주" : `${wk.w}주차`}
                      </span>
                      <span style={{
                        fontSize: 10, fontWeight: 700, color: wk.phase.c,
                        background: `${wk.phase.c}1a`, padding: "2px 8px", borderRadius: 100,
                      }}>{wk.phase.name}</span>
                      {wk.isRecovery && <span style={{ fontSize: 10, color: "#64748b" }}>회복주</span>}
                    </div>
                    <div style={{ fontSize: 11, color: "#64748b", marginTop: 3 }}>
                      {wk.dateLabel} 주 · 주간 {wk.vol}km · 롱런 {wk.longRun}km
                    </div>
                  </div>
                  <span style={{ color: "#475569", fontSize: 14, transform: open ? "rotate(180deg)" : "none", transition: "transform 0.2s" }}>▾</span>
                </button>

                {/* 펼친 내용: 요일별 */}
                {open && (
                  <div style={{ padding: "0 14px 12px" }}>
                    {wk.days.map((day, i) => {
                      const ks = kindStyle[day.kind];
                      return (
                        <div key={i} style={{
                          display: "grid", gridTemplateColumns: "26px 1fr auto", gap: 10, alignItems: "center",
                          padding: "9px 12px", marginTop: 6, borderRadius: 10,
                          background: ks.bg, border: `1px solid ${ks.c}22`,
                        }}>
                          <span style={{ fontSize: 12, fontWeight: 800, color: "#475569" }}>{day.d}</span>
                          <div>
                            <div style={{ fontSize: 12.5, fontWeight: 600, color: ks.c, lineHeight: 1.4 }}>{day.t}</div>
                            {day.time && <div style={{ fontSize: 10, color: "#475569", marginTop: 1 }}>{day.time}</div>}
                          </div>
                          <span style={{ fontSize: 12, fontWeight: 800, color: day.k > 0 ? ks.c : "#334155", whiteSpace: "nowrap" }}>
                            {day.k > 0 ? `${day.k}km` : "휴식"}
                          </span>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            );
          })}

          <button onClick={() => { setScreen("input"); setVdot(null); }} style={{
            width: "100%", padding: 16, borderRadius: 16, marginTop: 8,
            border: "1px solid rgba(255,255,255,0.1)", cursor: "pointer",
            background: "rgba(255,255,255,0.04)", color: "#94a3b8", fontSize: 14, fontWeight: 700,
          }}>↺ 처음부터 다시 측정</button>
          <p style={{ textAlign: "center", color: "#1e293b", fontSize: 10, marginTop: 14, lineHeight: 1.6 }}>
            Daniels-Gilbert 공식 기반 추정 · 부상 위험과 실제 컨디션을 항상 우선하세요
          </p>
        </div>
      </Phone>
    );
  }

  return null;
}
