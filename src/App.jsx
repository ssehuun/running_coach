import { useState, useEffect } from "react";
import {
  DIST_M, timeToVDOT, vdotToTime, vdotToVelocity, trainingPaces,
  timeToSec, fmtTime, fmtPace, DIST_OPTIONS, TARGET_OPTIONS,
  LEVELS, levelOf, levelRangeLabel, levelRaceLabel, PACE_META, buildWeeklySchedule,
} from "./calc.js";
import {
  Phone, StatusBar, VdotGauge, ACCENT, kindStyle, inputStyle, colonStyle, labelStyle,
} from "./ui.jsx";
import { useLocalState } from "./useLocalState.js";
import { KEYS, loadPlan, savePlan, clearPlan, newId } from "./storage.js";
import { recordsForDay, planDateFor, toISODate } from "./compare.js";
import { LogScreen, HistoryScreen, CompareScreen } from "./screens.jsx";

/* ============================================================
   VDOT 러닝 코치 앱 — Daniels-Gilbert 공식 기반
   계산/저장/비교/신규 화면은 별도 모듈로 분리(calc·storage·compare·screens)
   ============================================================ */

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
  const [levelInfoOpen, setLevelInfoOpen] = useState(false);
  const [paceHowOpen, setPaceHowOpen] = useState(false);
  const [expandedPace, setExpandedPace] = useState(null);
  const [runDays, setRunDays] = useState(5);

  // 영속 상태: 생성된 플랜 + 러닝 기록
  const [plan, setPlan] = useState(null);
  const [records, setRecords] = useLocalState(KEYS.records, []);
  const [logPrefill, setLogPrefill] = useState(null);
  const [logReturn, setLogReturn] = useState("schedule");

  // 마운트 시 저장된 플랜을 복원하고 스케줄 화면으로 진입
  useEffect(() => {
    const p = loadPlan();
    if (p) {
      setPlan(p);
      setRecordDist(p.recordDist ?? "k10");
      setH(p.h ?? ""); setM(p.m ?? ""); setS(p.s ?? "");
      setWeeklyKm(p.weeklyKm ?? "");
      setIsRecent(p.isRecent ?? true);
      setVdot(p.vdot ?? null);
      setTargetDist(p.targetDist ?? "full");
      setTargetH(p.targetH ?? ""); setTargetM(p.targetM ?? "");
      setTargetDate(p.targetDate ?? "");
      setRunDays(p.runDays ?? 5);
      setScreen("schedule");
    }
  }, []);

  function runAssessment() {
    const sec = timeToSec(h, m, s);
    if (sec <= 0) return;
    setVdot(timeToVDOT(DIST_M[recordDist], sec));
    setScreen("result");
  }

  // 스케줄 생성 + 플랜 영속화 (weeksLeft를 고정해 날짜·비교가 흔들리지 않게 함)
  function generateSchedule() {
    const raceDate = new Date(targetDate);
    const today = new Date();
    const daysLeft = Math.ceil((raceDate - today) / (1000 * 60 * 60 * 24));
    const weeksLeft = Math.max(4, Math.ceil(daysLeft / 7));
    const newPlan = {
      id: newId(), createdAt: new Date().toISOString(),
      targetDist, targetH, targetM, targetDate, runDays, weeklyKm,
      vdot, isRecent, recordDist, h, m, s, weeksLeft,
    };
    setPlan(newPlan);
    savePlan(newPlan);
    setExpandedWeek(1);
    setScreen("schedule");
  }

  function resetAll() {
    clearPlan();          // 플랜만 삭제 — 기록은 보존
    setPlan(null);
    setVdot(null);
    setScreen("input");
  }

  function openLog(prefill, returnScreen) {
    setLogPrefill(prefill || null);
    setLogReturn(returnScreen || "schedule");
    setScreen("log");
  }

  /* ---------- SCREEN: 기록 입력 / 편집 ---------- */
  if (screen === "log") {
    return (
      <LogScreen
        prefill={logPrefill}
        records={records}
        setRecords={setRecords}
        onDone={() => setScreen(logReturn)}
      />
    );
  }

  /* ---------- SCREEN: 히스토리 ---------- */
  if (screen === "history") {
    return (
      <HistoryScreen
        records={records}
        plan={plan}
        onAdd={() => openLog({ date: toISODate(new Date()) }, "history")}
        onEdit={(r) => openLog({ id: r.id, date: r.date, distanceKm: r.distanceKm, durationSec: r.durationSec, notes: r.notes, link: r.link }, "history")}
        onDelete={(id) => setRecords(prev => prev.filter(x => x.id !== id))}
        onBack={() => setScreen(plan ? "schedule" : "input")}
      />
    );
  }

  /* ---------- SCREEN: 계획 vs 실제 비교 ---------- */
  if (screen === "compare" && plan) {
    const { weeks } = buildScheduleFromPlan(plan);
    return (
      <CompareScreen
        weeks={weeks}
        records={records}
        plan={plan}
        onBack={() => setScreen("schedule")}
        onOpenHistory={() => setScreen("history")}
      />
    );
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
            boxShadow: sec > 0 ? `0 8px 24px ${ACCENT}44` : "none", marginBottom: 12,
          }}>현재 능력 측정하기 →</button>

          {records.length > 0 && (
            <button onClick={() => setScreen("history")} style={{
              width: "100%", padding: 14, borderRadius: 14, marginBottom: 24,
              border: "1px solid rgba(255,255,255,0.1)", cursor: "pointer",
              background: "rgba(255,255,255,0.04)", color: "#94a3b8", fontSize: 13, fontWeight: 700,
            }}>📒 내 러닝 히스토리 ({records.length}회)</button>
          )}
        </div>
      </Phone>
    );
  }

  /* ---------- SCREEN 2: 측정 결과 ---------- */
  if (screen === "result") {
    const effVdot = isRecent ? vdot : vdot - 1.5;
    const paces = trainingPaces(effVdot);
    const preds = DIST_OPTIONS.map(d => ({ label: d.label, time: fmtTime(vdotToTime(effVdot, DIST_M[d.key])) }));
    const cur = levelOf(effVdot);

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
          <button onClick={() => setLevelInfoOpen(o => !o)} style={{
            display: "inline-flex", alignItems: "center", gap: 5, marginTop: 10, cursor: "pointer",
            background: `${cur.c}1a`, color: cur.c, border: `1px solid ${cur.c}44`,
            fontSize: 12, fontWeight: 700, padding: "5px 14px", borderRadius: 100,
          }}>{cur.name} 러너 <span style={{ fontSize: 11, opacity: 0.8 }}>ⓘ</span></button>
          {!isRecent && <div style={{ marginTop: 8, fontSize: 11, color: "#fb923c" }}>역대 기록 기준 보수 보정 적용됨</div>}
        </div>

        <VdotGauge vdot={effVdot} />

        {levelInfoOpen && (
          <div style={{
            margin: "12px 20px 0", background: "rgba(255,255,255,0.04)",
            border: "1px solid rgba(255,255,255,0.08)", borderRadius: 14, overflow: "hidden",
          }}>
            <div style={{ padding: "12px 16px 8px", fontSize: 12, fontWeight: 700, color: "#94a3b8" }}>
              이 등급은 어떻게 나뉘나요?
            </div>
            {LEVELS.map((l) => {
              const active = cur.key === l.key;
              return (
                <div key={l.key} style={{
                  display: "flex", alignItems: "center", gap: 10, padding: "10px 16px",
                  background: active ? `${l.c}12` : "transparent",
                  borderTop: "1px solid rgba(255,255,255,0.04)",
                }}>
                  <span style={{ width: 7, height: 7, borderRadius: 2, background: l.c, flexShrink: 0 }} />
                  <span style={{ fontSize: 13, fontWeight: active ? 800 : 600, color: active ? l.c : "#cbd5e1", width: 48 }}>{l.name}</span>
                  <span style={{ fontSize: 12, color: "#64748b", width: 64, fontVariantNumeric: "tabular-nums" }}>VDOT {levelRangeLabel(l)}</span>
                  <span style={{ fontSize: 12, color: "#94a3b8", flex: 1, textAlign: "right", fontVariantNumeric: "tabular-nums" }}>{levelRaceLabel(l)}</span>
                  {active && <span style={{ fontSize: 11, color: l.c, marginLeft: 6 }}>← 당신</span>}
                </div>
              );
            })}
            <div style={{ padding: "10px 16px", fontSize: 11, lineHeight: 1.6, color: "#475569", borderTop: "1px solid rgba(255,255,255,0.04)" }}>
              ※ 본 앱 자체 기준입니다. VDOT는 기록으로 추정한 현재 체력 지표이며, 경계는 참고용입니다.
            </div>
          </div>
        )}

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

          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 10 }}>
            <span style={{ fontSize: 13, fontWeight: 700, color: "#64748b" }}>맞춤 훈련 페이스 (/km)</span>
            <button onClick={() => setPaceHowOpen(o => !o)} style={{
              background: "transparent", border: "none", cursor: "pointer", color: ACCENT,
              fontSize: 12, fontWeight: 700, padding: 0,
            }}>어떻게 계산되나요? {paceHowOpen ? "▴" : "▾"}</button>
          </div>
          {paceHowOpen && (
            <div style={{
              padding: "12px 14px", borderRadius: 12, marginBottom: 12, fontSize: 12, lineHeight: 1.6,
              background: `${ACCENT}0d`, border: `1px solid ${ACCENT}22`, color: "#94a3b8",
            }}>
              각 페이스는 당신의 VDOT로 역산한 <strong style={{ color: "#cbd5e1" }}>최대 능력 속도(vVO₂max)의 비율(%)</strong>로 정해집니다.
              강도가 낮을수록 느리고 길게, 높을수록 빠르고 짧게 달려 서로 다른 능력을 단련합니다. 각 행을 탭하면 목적·느낌을 볼 수 있어요.
            </div>
          )}
          <div style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.07)", borderRadius: 14, overflow: "hidden", marginBottom: 28 }}>
            {PACE_META.map((meta, i, a) => {
              const paceSec = paces[meta.key];
              const vv = vdotToVelocity(effVdot);
              const pct = (60000 / paceSec) / vv;
              const open = expandedPace === meta.key;
              return (
                <div key={meta.key} style={{ borderBottom: i < a.length - 1 ? "1px solid rgba(255,255,255,0.04)" : "none" }}>
                  <button onClick={() => setExpandedPace(open ? null : meta.key)} style={{
                    width: "100%", display: "flex", alignItems: "center", gap: 12,
                    padding: "13px 16px", background: "transparent", border: "none", cursor: "pointer",
                  }}>
                    <div style={{ flex: 1, textAlign: "left" }}>
                      <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 7 }}>
                        <span style={{ fontSize: 13, color: "#cbd5e1" }}>{meta.n}</span>
                        <span style={{ fontSize: 10, color: "#475569", fontVariantNumeric: "tabular-nums" }}>{Math.round(pct * 100)}%</span>
                      </div>
                      <div style={{ height: 5, borderRadius: 3, background: "rgba(255,255,255,0.07)", overflow: "hidden" }}>
                        <div style={{ width: `${Math.min(100, pct * 100)}%`, height: "100%", background: meta.c, borderRadius: 3 }} />
                      </div>
                    </div>
                    <span style={{ fontSize: 16, fontWeight: 800, color: meta.c, fontVariantNumeric: "tabular-nums" }}>{fmtPace(paceSec)}</span>
                    <span style={{ color: "#475569", fontSize: 12, transform: open ? "rotate(180deg)" : "none", transition: "transform 0.2s" }}>▾</span>
                  </button>
                  {open && (
                    <div style={{ padding: "2px 16px 14px", display: "grid", gap: 7 }}>
                      {[
                        ["강도", `vVO₂max의 ${meta.range ?? Math.round(pct * 100) + "%"}`],
                        ["목적", meta.purpose],
                        ["느낌", meta.feel],
                        ["언제", meta.when],
                      ].map(([k, v]) => (
                        <div key={k} style={{ display: "flex", gap: 10, fontSize: 11.5, lineHeight: 1.5 }}>
                          <span style={{ width: 34, flexShrink: 0, color: "#475569", fontWeight: 700 }}>{k}</span>
                          <span style={{ color: "#94a3b8" }}>{v}</span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              );
            })}
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

          <label style={labelStyle}>주 며칠 달릴 수 있나요?</label>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 8, marginBottom: 8 }}>
            {[3, 4, 5, 6].map(n => (
              <button key={n} onClick={() => setRunDays(n)} style={{
                padding: "14px 4px", borderRadius: 14, cursor: "pointer",
                border: `1px solid ${runDays === n ? ACCENT : "rgba(255,255,255,0.1)"}`,
                background: runDays === n ? `${ACCENT}1a` : "rgba(255,255,255,0.03)",
                color: runDays === n ? ACCENT : "#94a3b8", fontSize: 15, fontWeight: 800,
              }}>{n}일</button>
            ))}
          </div>
          <div style={{ fontSize: 11, color: "#64748b", lineHeight: 1.6, marginBottom: 20 }}>
            {runDays === 3 ? "롱런·템포·인터벌만 — 적게 뛰지만 핵심만 압축 (휴식일로 회복 확보)"
              : runDays === 4 ? "핵심 3개 + 이지런 1회 — 균형 잡힌 입문~중급용"
              : runDays === 5 ? "표준 구성 — 이지·회복런까지 포함 (권장)"
              : "이지런 추가로 주행량 ↑ — 거리 적응에 유리, 회복 관리 필수"}
          </div>

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

          <button onClick={generateSchedule} disabled={!canProceed} style={{
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
    const activePlan = plan || {
      targetDist, targetH, targetM, targetDate, runDays, weeklyKm, vdot, isRecent,
      weeksLeft: Math.max(4, Math.ceil((new Date(targetDate) - new Date()) / (1000 * 60 * 60 * 24 * 7))),
    };
    const { weeks, needVdot, paces, targetLabel, daysLeft, weeksLeft } = buildScheduleFromPlan(activePlan);

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
              <div style={{ fontSize: 19, fontWeight: 900 }}>{targetLabel} {activePlan.targetH}:{String(activePlan.targetM).padStart(2, "0")}</div>
            </div>
            <div style={{ textAlign: "right" }}>
              <div style={{ fontSize: 11, color: "#64748b" }}>대회까지</div>
              <div style={{ fontSize: 19, fontWeight: 900, color: ACCENT }}>D-{daysLeft > 0 ? daysLeft : 0}</div>
            </div>
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 8 }}>
            {[
              { v: `${weeksLeft}주`, l: "총 기간" },
              { v: `주 ${activePlan.runDays}일`, l: "훈련 빈도" },
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

        {/* 비교 / 기록 진입 */}
        <div style={{ display: "flex", gap: 8, padding: "0 16px 12px" }}>
          <button onClick={() => setScreen("compare")} style={navBtn(ACCENT, true)}>📊 비교 분석</button>
          <button onClick={() => setScreen("history")} style={navBtn(ACCENT, false)}>
            📒 기록 {records.length > 0 ? `(${records.length})` : ""}
          </button>
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

                {/* 펼친 내용: 요일별 (+ 완료 기록 연동) */}
                {open && (
                  <div style={{ padding: "0 14px 12px" }}>
                    {wk.days.map((day, i) => {
                      const ks = kindStyle[day.kind];
                      const canLog = day.k > 0 && day.kind !== "rest" && plan;
                      const matched = canLog ? recordsForDay(records, plan, wk.w, day.d) : [];
                      const agg = matched.length ? aggregateRecords(matched) : null;
                      return (
                        <div key={i} style={{
                          display: "grid", gridTemplateColumns: "26px 1fr auto", gap: 10, alignItems: "center",
                          padding: "9px 12px", marginTop: 6, borderRadius: 10,
                          background: ks.bg, border: `1px solid ${agg ? "#34d39955" : ks.c + "22"}`,
                        }}>
                          <span style={{ fontSize: 12, fontWeight: 800, color: "#475569" }}>{day.d}</span>
                          <div>
                            <div style={{ fontSize: 12.5, fontWeight: 600, color: ks.c, lineHeight: 1.4 }}>{day.t}</div>
                            {day.time && !agg && <div style={{ fontSize: 10, color: "#475569", marginTop: 1 }}>{day.time}</div>}
                            {agg && (
                              <div style={{ fontSize: 10.5, color: "#34d399", marginTop: 2, fontWeight: 700 }}>
                                ✓ 실제 {Math.round(agg.distanceKm * 10) / 10}km · {fmtPace(agg.pace)}/km
                              </div>
                            )}
                          </div>
                          {canLog ? (
                            agg ? (
                              <button onClick={() => openLog(editPrefillFor(matched[0]), "schedule")} style={{
                                fontSize: 11, fontWeight: 800, color: "#34d399", whiteSpace: "nowrap",
                                background: "rgba(52,211,153,0.12)", border: "1px solid rgba(52,211,153,0.3)",
                                borderRadius: 8, padding: "5px 9px", cursor: "pointer",
                              }}>{Math.round((agg.distanceKm / day.k) * 100)}%</button>
                            ) : (
                              <button onClick={() => openLog(completePrefillFor(plan, wk.w, day), "schedule")} style={{
                                fontSize: 11, fontWeight: 700, color: ACCENT, whiteSpace: "nowrap",
                                background: `${ACCENT}14`, border: `1px solid ${ACCENT}40`,
                                borderRadius: 8, padding: "5px 9px", cursor: "pointer",
                              }}>완료 기록</button>
                            )
                          ) : (
                            <span style={{ fontSize: 12, fontWeight: 800, color: day.k > 0 ? ks.c : "#334155", whiteSpace: "nowrap" }}>
                              {day.k > 0 ? `${day.k}km` : "휴식"}
                            </span>
                          )}
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            );
          })}

          <button onClick={resetAll} style={{
            width: "100%", padding: 16, borderRadius: 16, marginTop: 8,
            border: "1px solid rgba(255,255,255,0.1)", cursor: "pointer",
            background: "rgba(255,255,255,0.04)", color: "#94a3b8", fontSize: 14, fontWeight: 700,
          }}>↺ 처음부터 다시 측정</button>
          <p style={{ textAlign: "center", color: "#1e293b", fontSize: 10, marginTop: 14, lineHeight: 1.6 }}>
            Daniels-Gilbert 공식 기반 추정 · 부상 위험과 실제 컨디션을 항상 우선하세요 · 기록은 이 브라우저에 저장됩니다
          </p>
        </div>
      </Phone>
    );
  }

  return null;
}

/* ====================== 보조 (모듈 스코프) ====================== */

/* 영속 플랜으로부터 스케줄과 표시용 파생값을 재계산 */
function buildScheduleFromPlan(plan) {
  const goalSec = timeToSec(plan.targetH, plan.targetM, 0);
  const needVdot = timeToVDOT(DIST_M[plan.targetDist], goalSec);
  const paces = trainingPaces(needVdot);
  const targetLabel = TARGET_OPTIONS.find(t => t.key === plan.targetDist).label;

  const raceDate = new Date(plan.targetDate);
  const today = new Date();
  const daysLeft = Math.ceil((raceDate - today) / (1000 * 60 * 60 * 24));
  const weeksLeft = plan.weeksLeft || Math.max(4, Math.ceil(daysLeft / 7));
  const startKm = parseInt(plan.weeklyKm) || 25;

  const { weeks } = buildWeeklySchedule({
    targetDist: plan.targetDist, vdot: needVdot, paces, weeksLeft, startKm, raceDate, runDays: plan.runDays,
  });
  return { weeks, needVdot, paces, targetLabel, daysLeft, weeksLeft };
}

function aggregateRecords(recs) {
  const distanceKm = recs.reduce((a, r) => a + (r.distanceKm || 0), 0);
  const durationSec = recs.reduce((a, r) => a + (r.durationSec || 0), 0);
  return { distanceKm, durationSec, pace: durationSec / distanceKm };
}

/* 완료 기록(신규) prefill — 해당 훈련일에 연결 */
function completePrefillFor(plan, week, day) {
  return {
    date: toISODate(planDateFor(plan, week, day.d)),
    distanceKm: day.k,
    link: { planId: plan.id, week, day: day.d, kind: day.kind },
  };
}
/* 기존 기록 편집 prefill */
function editPrefillFor(r) {
  return { id: r.id, date: r.date, distanceKm: r.distanceKm, durationSec: r.durationSec, notes: r.notes, link: r.link };
}

function navBtn(accent, primary) {
  return {
    flex: 1, padding: "11px 8px", borderRadius: 12, cursor: "pointer", fontSize: 13, fontWeight: 800,
    border: `1px solid ${primary ? accent : "rgba(255,255,255,0.12)"}`,
    background: primary ? `${accent}1a` : "rgba(255,255,255,0.04)",
    color: primary ? accent : "#cbd5e1",
  };
}
