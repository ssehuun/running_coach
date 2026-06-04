/* ============================================================
   localStorage 영속성 — 플랜 + 러닝 기록
   모든 접근을 try/catch로 감싸 시크릿 모드·용량 초과에도
   인메모리로 우아하게 동작한다(저장만 무시).
   ============================================================ */

export const KEYS = { plan: "rc.plan.v1", records: "rc.records.v1" };

export function loadJSON(key, fallback) {
  try {
    const raw = localStorage.getItem(key);
    if (raw == null) return fallback;
    return JSON.parse(raw);
  } catch {
    return fallback;
  }
}

export function saveJSON(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    /* quota / 비활성 스토리지 — 무시 */
  }
}

/* ---- 플랜 ---- */
export function loadPlan() {
  const p = loadJSON(KEYS.plan, null);
  return p && typeof p === "object" ? p : null;
}
export function savePlan(plan) { saveJSON(KEYS.plan, plan); }
export function clearPlan() {
  try { localStorage.removeItem(KEYS.plan); } catch { /* 무시 */ }
}

/* ---- 러닝 기록 ---- */
export function loadRecords() {
  const r = loadJSON(KEYS.records, []);
  return Array.isArray(r) ? r : [];
}
export function saveRecords(records) { saveJSON(KEYS.records, records); }

export function addRecord(records, record) {
  const next = [...records, record];
  saveRecords(next);
  return next;
}
export function updateRecord(records, id, patch) {
  const next = records.map(r => (r.id === id ? { ...r, ...patch } : r));
  saveRecords(next);
  return next;
}
export function deleteRecord(records, id) {
  const next = records.filter(r => r.id !== id);
  saveRecords(next);
  return next;
}

/* 고유 ID — crypto.randomUUID 우선, 미지원 환경은 폴백 */
export function newId() {
  try {
    if (typeof crypto !== "undefined" && crypto.randomUUID) return crypto.randomUUID();
  } catch { /* 폴백으로 */ }
  return `id-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}
