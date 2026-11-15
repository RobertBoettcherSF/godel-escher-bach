import {t} from "./i18n.js?v=1";

function state() {
  return window.GEB?.state || {};
}

export function refreshDebug() {
  const panel = document.getElementById("debug");
  if (!panel || panel.hidden) return;
  const data = state();
  const version = document.querySelector(".version")?.textContent?.trim() || "";
  const set = (id, value) => {
    const node = document.getElementById(id);
    if (node) node.textContent = value;
  };
  set("dbg-version", version);
  set("dbg-wasm", data.wasm || t("wasmNone"));
  set("dbg-string", data.string ?? "—");
  set("dbg-path", data.history ?? "—");
  set("dbg-error", data.error ?? "—");
  set("dbg-steps", data.steps ?? "—");
  set("dbg-gap", data.gap ?? "—");
  set("dbg-layer", data.layer ?? "—");
  set("dbg-taps", data.taps ?? "—");
}

export function bindDebug() {
  const panel = document.getElementById("debug");
  if (!panel) return;
  window.GEB = window.GEB || {state: {}};
  window.GEB.refreshDebug = refreshDebug;
  window.addEventListener("keydown", (event) => {
    if (event.key !== "F9" || event.repeat) return;
    event.preventDefault();
    panel.hidden = !panel.hidden;
    refreshDebug();
  });
  window.addEventListener("languagechange", refreshDebug);
}
