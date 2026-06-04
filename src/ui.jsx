/* ============================================================
   공유 프레젠테이션 — 스타일 상수 · Phone/StatusBar/VdotGauge
   여러 화면(App.jsx, screens.jsx)에서 재사용한다.
   ============================================================ */
import { LEVELS, GAUGE_MIN, GAUGE_MAX, levelOf } from "./calc.js";

export const ACCENT = "#22d3ee";
export const BG = "#0a0e17";

export const kindStyle = {
  rest: { c: "#64748b", bg: "rgba(100,116,139,0.12)" },
  easy: { c: "#60a5fa", bg: "rgba(96,165,250,0.1)" },
  speed: { c: "#facc15", bg: "rgba(250,204,21,0.1)" },
  tempo: { c: "#fb923c", bg: "rgba(251,146,60,0.1)" },
  long: { c: "#f43f5e", bg: "rgba(244,63,94,0.1)" },
  race: { c: "#22d3ee", bg: "rgba(34,211,238,0.15)" },
};

export const inputStyle = {
  width: "100%", textAlign: "center", padding: "16px 0",
  background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)",
  borderRadius: 12, color: "#fff", fontSize: 24, fontWeight: 800,
  fontVariantNumeric: "tabular-nums", outline: "none",
};
export const colonStyle = { fontSize: 22, fontWeight: 800, color: "#475569" };
export const labelStyle = {
  display: "block", fontSize: 12, fontWeight: 700, color: "#64748b",
  marginBottom: 10, letterSpacing: "0.02em",
};

/* 안정적인 참조를 위해 컴포넌트는 모듈 스코프에 정의 */
export function Phone({ children }) {
  return (
    <div style={{
      maxWidth: 390, margin: "0 auto", minHeight: "100vh", background: BG, color: "#e2e8f0",
      fontFamily: "'Noto Sans KR', 'Apple SD Gothic Neo', sans-serif", position: "relative",
    }}>{children}</div>
  );
}
export function StatusBar({ title, onBack }) {
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

/* VDOT 스케일 게이지: 등급 밴드 위에 사용자 위치를 마커로 표시 */
export function VdotGauge({ vdot }) {
  const cur = levelOf(vdot);
  const toPct = (v) => Math.max(0, Math.min(1, (v - GAUGE_MIN) / (GAUGE_MAX - GAUGE_MIN)));
  const pos = toPct(vdot);
  return (
    <div style={{ padding: "6px 24px 2px" }}>
      <div style={{ position: "relative", height: 16 }}>
        <div style={{
          position: "absolute", left: `${pos * 100}%`, transform: "translateX(-50%)",
          fontSize: 11, color: "#fff", lineHeight: 1,
        }}>▼</div>
      </div>
      <div style={{ display: "flex", height: 10, borderRadius: 6, overflow: "hidden" }}>
        {LEVELS.map(l => {
          const w = (toPct(Math.min(l.max, GAUGE_MAX)) - toPct(Math.max(l.min, GAUGE_MIN))) * 100;
          return <div key={l.key} style={{
            width: `${w}%`, background: l.c, opacity: cur.key === l.key ? 1 : 0.4,
          }} />;
        })}
      </div>
      <div style={{ display: "flex", marginTop: 6 }}>
        {LEVELS.map(l => {
          const w = (toPct(Math.min(l.max, GAUGE_MAX)) - toPct(Math.max(l.min, GAUGE_MIN))) * 100;
          return <div key={l.key} style={{
            width: `${w}%`, textAlign: "center", fontSize: 10,
            fontWeight: cur.key === l.key ? 800 : 600,
            color: cur.key === l.key ? l.c : "#475569",
          }}>{l.name}</div>;
        })}
      </div>
    </div>
  );
}
