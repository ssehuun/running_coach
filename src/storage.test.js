import { describe, it, expect, beforeEach } from "vitest";
import {
  KEYS, loadJSON, saveJSON, loadPlan, savePlan, clearPlan,
  loadRecords, addRecord, updateRecord, deleteRecord, newId,
} from "./storage.js";

/* 노드 환경용 최소 localStorage 목 */
function installLocalStorage() {
  const store = new Map();
  globalThis.localStorage = {
    getItem: (k) => (store.has(k) ? store.get(k) : null),
    setItem: (k, v) => store.set(k, String(v)),
    removeItem: (k) => store.delete(k),
    clear: () => store.clear(),
  };
}

beforeEach(() => installLocalStorage());

describe("JSON 라운드트립 & 폴백", () => {
  it("저장/로드", () => {
    saveJSON("k", { a: 1 });
    expect(loadJSON("k", null)).toEqual({ a: 1 });
  });
  it("없는 키 → fallback", () => {
    expect(loadJSON("missing", [])).toEqual([]);
  });
  it("손상 JSON → fallback", () => {
    localStorage.setItem("bad", "{not json");
    expect(loadJSON("bad", "fb")).toBe("fb");
  });
});

describe("플랜", () => {
  it("save/load/clear", () => {
    expect(loadPlan()).toBeNull();
    savePlan({ id: "P1", weeksLeft: 12 });
    expect(loadPlan()).toEqual({ id: "P1", weeksLeft: 12 });
    clearPlan();
    expect(loadPlan()).toBeNull();
  });
});

describe("기록", () => {
  it("기본은 빈 배열", () => {
    expect(loadRecords()).toEqual([]);
  });
  it("add/update/delete + 영속", () => {
    let recs = [];
    recs = addRecord(recs, { id: "a", distanceKm: 10 });
    expect(recs).toHaveLength(1);
    expect(loadRecords()).toHaveLength(1); // KEYS.records에 저장됨

    recs = updateRecord(recs, "a", { distanceKm: 12 });
    expect(recs[0].distanceKm).toBe(12);
    expect(loadRecords()[0].distanceKm).toBe(12);

    recs = deleteRecord(recs, "a");
    expect(recs).toHaveLength(0);
    expect(loadRecords()).toEqual([]);
  });
});

describe("newId", () => {
  it("고유 문자열", () => {
    expect(newId()).not.toBe(newId());
    expect(typeof newId()).toBe("string");
  });
});

describe("KEYS", () => {
  it("키 상수 존재", () => {
    expect(KEYS.plan).toBeTruthy();
    expect(KEYS.records).toBeTruthy();
  });
});
