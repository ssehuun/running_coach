/* ============================================================
   신규 화면 — 러닝 기록 입력(LogScreen) · 히스토리(HistoryScreen)
              · 계획 vs 실제 비교(CompareScreen)
   ============================================================ */
import { useState } from "react";
import { fmtPace, fmtTime, timeToSec } from "./calc.js";
import {
  Phone, StatusBar, ACCENT, kindStyle, inputStyle, colonStyle, labelStyle,
} from "./ui.jsx";
import {
  perWorkout, weeklyVolume, paceTrend, adherence, recordPace,
  toISODate, staleRecordCount,
} from "./compare.js";
import { newId } from "./storage.js";

const STATUS_COLOR = { good: "#34d399", partial: "#fb923c", none: "#475569" };

/* ====================== 기록 입력 / 편집 ====================== */
export function LogScreen({ prefill, records, setRecords, onDone }) {
  const editing = !!(prefill && prefill.id);
  const init = prefill || {};
  const [date, setDate] = useState(init.date || toISODate(new Date()));
  const [dist, setDist] = useState(init.distanceKm != null ? String(init.distanceKm) : "");
  const initSec = init.durationSec || 0;
  const [h, setH] = useState(initSec ? String(Math.floor(initSec / 3600)) : "");
  const [m, setM] = useState(initSec ? String(Math.floor((initSec % 3600) / 60)) : "");
  const [s, setS] = useState(initSec ? String(initSec % 60) : "");
  const [notes, setNotes] = useState(init.notes || "");

  const distanceKm = parseFloat(dist);
  const durationSec = timeToSec(h, m, s);
  const valid = distanceKm > 0 && durationSec > 0 && !!date;
  const previewPace = valid ? fmtPace(durationSec / distanceKm) : "—";

  function save() {
    if (!valid) return;
    if (editing) {
      setRecords(prev => prev.map(r => r.id === prefill.id
        ? { ...r, date, distanceKm, durationSec, notes }
        : r));
    } else {
      const rec = {
        id: newId(), date, distanceKm, durationSec, notes,
        link: init.link || null,
      };
      setRecords(prev => [...prev, rec]);
    }
    onDone();
  }

  const linkInfo = init.link;

  return (
    <Phone>
      <StatusBar title={editing ? "기록 수정" : "러닝 기록"} onBack={onDone} />
      <div style={{ padding: "20px" }}>
        {linkInfo && (
          <div style={{
            padding: "10px 14px", borderRadius: 12, marginBottom: 18, fontSize: 12,
            background: `${ACCENT}12`, border: `1px solid ${ACCENT}33`, color: "#94a3b8",
          }}>
            📌 <strong style={{ color: "#cbd5e1" }}>{linkInfo.week}주차 {linkInfo.day}요일</strong> 계획 훈련에 연결됩니다.
          </div>
        )}

        <label style={labelStyle}>날짜</label>
        <input type="date" value={date} onChange={e => setDate(e.target.value)}
          style={{ ...inputStyle, fontSize: 16, marginBottom: 20, colorScheme: "dark", padding: 16 }} />

        <label style={labelStyle}>거리 (km)</label>
        <input value={dist} onChange={e => setDist(e.target.value.replace(/[^\d.]/g, ""))}
          placeholder="예: 10.5" inputMode="decimal"
          style={{ ...inputStyle, fontSize: 22, marginBottom: 20 }} />

        <label style={labelStyle}>시간 (시 : 분 : 초)</label>
        <div style={{ display: "flex", gap: 8, alignItems: "center", marginBottom: 16 }}>
          <input value={h} onChange={e => setH(e.target.value.replace(/\D/g, ""))} placeholder="0" maxLength={1} inputMode="numeric" style={inputStyle} />
          <span style={colonStyle}>:</span>
          <input value={m} onChange={e => setM(e.target.value.replace(/\D/g, ""))} placeholder="00" maxLength={2} inputMode="numeric" style={inputStyle} />
          <span style={colonStyle}>:</span>
          <input value={s} onChange={e => setS(e.target.value.replace(/\D/g, ""))} placeholder="00" maxLength={2} inputMode="numeric" style={inputStyle} />
        </div>

        <div style={{ textAlign: "center", fontSize: 13, color: "#64748b", marginBottom: 20 }}>
          평균 페이스 <strong style={{ color: ACCENT, fontSize: 16 }}>{previewPace}</strong> /km
        </div>

        <label style={labelStyle}>메모 — 선택</label>
        <textarea value={notes} onChange={e => setNotes(e.target.value)} rows={2}
          placeholder="컨디션·코스·날씨 등"
          style={{
            width: "100%", boxSizing: "border-box", padding: "12px 14px", borderRadius: 12,
            background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)",
            color: "#fff", fontSize: 14, outline: "none", resize: "vertical",
            fontFamily: "inherit", marginBottom: 24,
          }} />

        <button onClick={save} disabled={!valid} style={{
          width: "100%", padding: 18, borderRadius: 16, border: "none",
          cursor: valid ? "pointer" : "not-allowed",
          background: valid ? `linear-gradient(135deg, ${ACCENT}, #0891b2)` : "rgba(255,255,255,0.08)",
          color: valid ? "#06141a" : "#475569", fontSize: 16, fontWeight: 800,
        }}>{editing ? "수정 저장" : "기록 저장"}</button>
      </div>
    </Phone>
  );
}

/* ====================== 히스토리 ====================== */
export function HistoryScreen({ records, plan, onAdd, onEdit, onDelete, onBack }) {
  const sorted = [...records].sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : 0));
  const totalKm = records.reduce((a, r) => a + (r.distanceKm || 0), 0);

  return (
    <Phone>
      <StatusBar title="러닝 히스토리" onBack={onBack} />
      <div style={{ padding: "16px 16px 8px" }}>
        <div style={{
          display: "flex", justifyContent: "space-between", alignItems: "center",
          background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.07)",
          borderRadius: 14, padding: "12px 16px", marginBottom: 14,
        }}>
          <div>
            <div style={{ fontSize: 11, color: "#64748b" }}>총 기록</div>
            <div style={{ fontSize: 18, fontWeight: 900 }}>{records.length}회 · {Math.round(totalKm * 10) / 10}km</div>
          </div>
          <button onClick={onAdd} style={{
            background: `linear-gradient(135deg, ${ACCENT}, #0891b2)`, border: "none",
            color: "#06141a", fontSize: 13, fontWeight: 800, padding: "10px 16px",
            borderRadius: 12, cursor: "pointer",
          }}>+ 기록 추가</button>
        </div>

        {sorted.length === 0 && (
          <div style={{ textAlign: "center", color: "#475569", fontSize: 13, padding: "40px 0", lineHeight: 1.7 }}>
            아직 기록이 없습니다.<br />스케줄에서 훈련을 완료하거나<br />위 버튼으로 직접 추가해 보세요.
          </div>
        )}

        {sorted.map(r => {
          const linked = !!(r.link && plan && r.link.planId === plan.id);
          const stale = !!(r.link && plan && r.link.planId !== plan.id);
          return (
            <div key={r.id} style={{
              display: "flex", alignItems: "center", gap: 10, padding: "12px 14px", marginBottom: 8,
              borderRadius: 12, background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)",
            }}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                  <span style={{ fontSize: 14, fontWeight: 800 }}>{r.distanceKm}km</span>
                  <span style={{ fontSize: 12, color: "#94a3b8", fontVariantNumeric: "tabular-nums" }}>
                    {fmtTime(r.durationSec)} · {fmtPace(recordPace(r))}/km
                  </span>
                </div>
                <div style={{ fontSize: 11, color: "#64748b", marginTop: 3, display: "flex", gap: 6, alignItems: "center" }}>
                  <span>{r.date}</span>
                  {linked && <span style={{ color: ACCENT }}>· {r.link.week}주 {r.link.day} 연결</span>}
                  {stale && <span style={{ color: "#64748b" }}>· 이전 계획</span>}
                  {!r.link && <span style={{ color: "#475569" }}>· 자유 러닝</span>}
                </div>
                {r.notes && <div style={{ fontSize: 11, color: "#475569", marginTop: 3 }}>{r.notes}</div>}
              </div>
              <button onClick={() => onEdit(r)} style={iconBtn}>✎</button>
              <button onClick={() => onDelete(r.id)} style={{ ...iconBtn, color: "#f43f5e" }}>🗑</button>
            </div>
          );
        })}
      </div>
    </Phone>
  );
}

const iconBtn = {
  background: "rgba(255,255,255,0.06)", border: "none", color: "#94a3b8",
  width: 30, height: 30, borderRadius: 8, cursor: "pointer", fontSize: 13, flexShrink: 0,
};

/* ====================== 비교 분석 ====================== */
const TABS = [
  { key: "workout", label: "훈련별" },
  { key: "weekly", label: "주간 총량" },
  { key: "pace", label: "페이스" },
  { key: "adherence", label: "이행률" },
];

export function CompareScreen({ weeks, records, plan, onBack, onOpenHistory }) {
  const [tab, setTab] = useState("workout");
  const stale = staleRecordCount(records, plan);

  return (
    <Phone>
      <StatusBar title="계획 vs 실제" onBack={onBack} />
      <div style={{ display: "flex", gap: 6, padding: "12px 16px 6px" }}>
        {TABS.map(t => (
          <button key={t.key} onClick={() => setTab(t.key)} style={{
            flex: 1, padding: "9px 4px", borderRadius: 10, cursor: "pointer", fontSize: 12, fontWeight: 700,
            border: `1px solid ${tab === t.key ? ACCENT : "rgba(255,255,255,0.1)"}`,
            background: tab === t.key ? `${ACCENT}1a` : "rgba(255,255,255,0.03)",
            color: tab === t.key ? ACCENT : "#94a3b8",
          }}>{t.label}</button>
        ))}
      </div>

      {stale > 0 && (
        <div style={{ padding: "0 16px", marginTop: 4 }}>
          <div style={{ fontSize: 11, color: "#64748b", lineHeight: 1.5 }}>
            ※ 이전 계획에 연결된 기록 {stale}건은 비교에서 제외됩니다 (히스토리·페이스 추세에는 표시).
          </div>
        </div>
      )}

      <div style={{ padding: "12px 16px 32px" }}>
        {tab === "workout" && <WorkoutView weeks={weeks} records={records} plan={plan} />}
        {tab === "weekly" && <WeeklyView weeks={weeks} records={records} plan={plan} />}
        {tab === "pace" && <PaceView records={records} />}
        {tab === "adherence" && <AdherenceView weeks={weeks} records={records} plan={plan} onOpenHistory={onOpenHistory} />}
      </div>
    </Phone>
  );
}

function WorkoutView({ weeks, records, plan }) {
  const rows = perWorkout(weeks, records, plan);
  // 주차별로 묶어 표시
  const byWeek = {};
  rows.forEach(r => { (byWeek[r.week] ||= []).push(r); });

  return (
    <div>
      {Object.keys(byWeek).map(wk => (
        <div key={wk} style={{ marginBottom: 14 }}>
          <div style={{ fontSize: 12, fontWeight: 800, color: "#94a3b8", marginBottom: 6 }}>{wk}주차</div>
          {byWeek[wk].map((r, i) => {
            const sc = STATUS_COLOR[r.status];
            const ks = kindStyle[r.kind];
            return (
              <div key={i} style={{
                display: "grid", gridTemplateColumns: "24px 1fr auto", gap: 8, alignItems: "center",
                padding: "9px 12px", marginBottom: 6, borderRadius: 10,
                background: ks.bg, border: `1px solid ${sc}44`,
              }}>
                <span style={{ fontSize: 12, fontWeight: 800, color: "#475569" }}>{r.day}</span>
                <div>
                  <div style={{ fontSize: 12, color: "#cbd5e1" }}>
                    계획 {r.plannedKm}km{r.plannedPace != null && ` · ${fmtPace(r.plannedPace)}/km`}
                  </div>
                  <div style={{ fontSize: 12, fontWeight: 700, color: sc, marginTop: 2 }}>
                    {r.actualKm != null
                      ? `실제 ${Math.round(r.actualKm * 10) / 10}km · ${fmtPace(r.actualPace)}/km`
                      : "기록 없음"}
                  </div>
                </div>
                <div style={{ textAlign: "right", whiteSpace: "nowrap" }}>
                  {r.actualKm != null ? (
                    <>
                      <div style={{ fontSize: 12, fontWeight: 800, color: sc }}>{Math.round(r.distRatio * 100)}%</div>
                      {r.paceDelta != null && (
                        <div style={{ fontSize: 10, color: r.paceDelta <= 0 ? "#34d399" : "#fb923c" }}>
                          {r.paceDelta <= 0 ? "▼" : "▲"}{fmtPace(Math.abs(r.paceDelta))}
                        </div>
                      )}
                    </>
                  ) : <span style={{ fontSize: 16, color: "#334155" }}>—</span>}
                </div>
              </div>
            );
          })}
        </div>
      ))}
    </div>
  );
}

function WeeklyView({ weeks, records, plan }) {
  const data = weeklyVolume(weeks, records, plan);
  return (
    <div>
      {data.map(w => {
        const rate = Math.min(1.2, w.volumeRate);
        const barColor = w.volumeRate >= 0.9 ? "#34d399" : w.volumeRate >= 0.5 ? "#fb923c" : "#f43f5e";
        return (
          <div key={w.week} style={{
            padding: "12px 14px", marginBottom: 8, borderRadius: 12,
            background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)",
          }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 8 }}>
              <span style={{ fontSize: 13, fontWeight: 800 }}>
                {w.isRaceWeek ? "🏁 레이스 주" : `${w.week}주차`}
                <span style={{ fontSize: 11, fontWeight: 700, color: w.phase.c, marginLeft: 6 }}>{w.phase.name}</span>
              </span>
              <span style={{ fontSize: 12, color: "#94a3b8", fontVariantNumeric: "tabular-nums" }}>
                {w.actualVol} / {w.plannedVol}km
              </span>
            </div>
            <div style={{ height: 8, borderRadius: 4, background: "rgba(255,255,255,0.07)", overflow: "hidden", marginBottom: 6 }}>
              <div style={{ width: `${(rate / 1.2) * 100}%`, height: "100%", background: barColor, borderRadius: 4 }} />
            </div>
            <div style={{ display: "flex", justifyContent: "space-between", fontSize: 11, color: "#64748b" }}>
              <span>달성률 <strong style={{ color: barColor }}>{Math.round(w.volumeRate * 100)}%</strong></span>
              <span>완료 {w.completedSessions}/{w.plannedSessions} 세션 ({Math.round(w.completionPct * 100)}%)</span>
            </div>
          </div>
        );
      })}
    </div>
  );
}

function PaceView({ records }) {
  const { points, trend, min, max, avg } = paceTrend(records);
  if (points.length === 0) {
    return <div style={{ textAlign: "center", color: "#475569", fontSize: 13, padding: "40px 0" }}>
      기록을 추가하면 페이스 추세가 표시됩니다.
    </div>;
  }
  // SVG 좌표 (느릴수록 위로 가지 않게 y 반전: 빠른 페이스=위)
  const W = 330, H = 160, padX = 10, padY = 16;
  const lo = min, hi = max, span = hi - lo || 1;
  const x = (i) => padX + (points.length === 1 ? 0.5 : i / (points.length - 1)) * (W - padX * 2);
  const y = (p) => padY + ((p - lo) / span) * (H - padY * 2); // 빠를수록(작을수록) 위

  const linePts = trend.map((p, i) => `${x(i)},${y(p)}`).join(" ");

  return (
    <div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 8, marginBottom: 14 }}>
        {[["최고", min], ["평균", avg], ["최저", max]].map(([l, v]) => (
          <div key={l} style={{ background: "rgba(255,255,255,0.04)", borderRadius: 10, padding: "10px 6px", textAlign: "center" }}>
            <div style={{ fontSize: 9, color: "#475569" }}>{l} 페이스</div>
            <div style={{ fontSize: 15, fontWeight: 800, color: ACCENT, fontVariantNumeric: "tabular-nums" }}>{fmtPace(v)}</div>
          </div>
        ))}
      </div>
      <svg viewBox={`0 0 ${W} ${H}`} style={{ width: "100%", background: "rgba(255,255,255,0.03)", borderRadius: 12 }}>
        {points.length > 1 && <polyline points={linePts} fill="none" stroke={ACCENT} strokeWidth="2" strokeLinejoin="round" />}
        {points.map((p, i) => {
          const c = p.kind ? (kindStyle[p.kind]?.c || "#94a3b8") : "#94a3b8";
          return <circle key={i} cx={x(i)} cy={y(p.pace)} r="3.5" fill={c} />;
        })}
      </svg>
      <div style={{ fontSize: 10, color: "#475569", textAlign: "center", marginTop: 6 }}>
        선: 3점 이동평균 · 점: 개별 기록(색=훈련 종류) · 위쪽일수록 빠른 페이스
      </div>
    </div>
  );
}

function AdherenceView({ weeks, records, plan, onOpenHistory }) {
  const a = adherence(weeks, records, plan);
  const tiles = [
    { v: `${Math.round(a.adherenceRate * 100)}%`, l: "이행률", c: ACCENT },
    { v: `${a.completedSessions}/${a.dueSessions}`, l: "완료/마감 세션", c: "#cbd5e1" },
    { v: `${a.currentStreak}`, l: "현재 연속", c: "#34d399" },
    { v: `${a.longestStreak}`, l: "최장 연속", c: "#fb923c" },
  ];
  return (
    <div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(2,1fr)", gap: 10, marginBottom: 16 }}>
        {tiles.map(t => (
          <div key={t.l} style={{
            background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.07)",
            borderRadius: 14, padding: "16px 12px", textAlign: "center",
          }}>
            <div style={{ fontSize: 26, fontWeight: 900, color: t.c, fontVariantNumeric: "tabular-nums" }}>{t.v}</div>
            <div style={{ fontSize: 11, color: "#64748b", marginTop: 4 }}>{t.l}</div>
          </div>
        ))}
      </div>
      <div style={{ fontSize: 12, color: "#64748b", lineHeight: 1.7, marginBottom: 16 }}>
        {a.dueSessions === 0
          ? "아직 마감된 계획 훈련이 없습니다. 일정이 다가오면 이행률이 집계됩니다."
          : a.adherenceRate >= 0.8
          ? "훌륭합니다! 계획을 꾸준히 잘 따라가고 있어요. 💪"
          : a.adherenceRate >= 0.5
          ? "절반 이상 따라가고 있어요. 핵심 훈련(인터벌·롱런) 위주로 채워보세요."
          : "최근 누락이 많습니다. 무리하지 말고 가능한 요일부터 다시 리듬을 잡아보세요."}
      </div>
      <button onClick={onOpenHistory} style={{
        width: "100%", padding: 14, borderRadius: 12, border: "1px solid rgba(255,255,255,0.1)",
        background: "rgba(255,255,255,0.04)", color: "#94a3b8", fontSize: 13, fontWeight: 700, cursor: "pointer",
      }}>📒 전체 기록 보기</button>
    </div>
  );
}
