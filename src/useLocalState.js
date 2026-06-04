/* ============================================================
   useLocalState — localStorage에 자동 영속되는 useState
   마운트 시 한 번 읽고, 값이 바뀔 때마다 저장한다.
   ============================================================ */
import { useState, useEffect, useRef } from "react";
import { loadJSON, saveJSON } from "./storage.js";

export function useLocalState(key, initial) {
  const [value, setValue] = useState(() => loadJSON(key, initial));
  const first = useRef(true);
  useEffect(() => {
    if (first.current) { first.current = false; return; } // 초기 로드값 재저장 방지
    saveJSON(key, value);
  }, [key, value]);
  return [value, setValue];
}
