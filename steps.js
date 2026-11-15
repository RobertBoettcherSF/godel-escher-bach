import "./shell.js?v=1";
import {t} from "./i18n.js?v=1";
import {play, playRise} from "./sounds.js?v=1";

let engine = null;
let wasmBytes = 0;
let wasmKey = "wasmLoading";
let fault = "";
let timer = null;

function read() {
  const max = engine.steps_max();
  const memory = engine.memory.buffer;
  const meta = new Int32Array(memory, engine.steps_meta() >>> 0, 10);
  const widths = new Int32Array(memory, engine.steps_widths() >>> 0, max);
  return {
    count: meta[0],
    error: meta[1],
    gapNum: meta[2],
    gapDen: meta[3],
    sumNum: meta[4],
    sumDen: meta[5],
    gapUnits: meta[6],
    sumUnits: meta[7],
    scale: meta[8],
    max,
    widths
  };
}

function publish(st) {
  const gap = st ? `${st.gapNum}/${st.gapDen}` : "—";
  window.GEB.state = {
    wasm: `${t(wasmKey)}${wasmBytes ? " · " + wasmBytes : ""}`,
    string: gap,
    history: st ? String(st.count) : "—",
    error: fault || (st ? `${st.error} ${t("err" + st.error)}` : "—"),
    steps: st ? String(st.count) : "—",
    gap
  };
  window.GEB.refreshDebug?.();
}

function place(st) {
  const lane = document.getElementById("lane");
  const runner = document.getElementById("runner");
  const tortoise = document.getElementById("tortoise");
  const room = Math.max(0, lane.clientWidth - tortoise.offsetWidth - runner.offsetWidth);
  const frac = st.sumDen === 0 ? 0 : st.sumNum / st.sumDen;
  runner.style.left = `${frac * room}px`;
}

function drawBar(st) {
  const bar = document.getElementById("bar");
  const colours = ["c0", "c1", "c2"];
  bar.replaceChildren();
  for (let i = 0; i < st.count; i += 1) {
    const chunk = document.createElement("span");
    chunk.className = `crumb ${colours[i % 3]}`;
    chunk.style.flexGrow = String(st.widths[i]);
    bar.appendChild(chunk);
  }
  const rest = document.createElement("span");
  rest.className = "crumb rest";
  rest.style.flexGrow = String(st.gapUnits);
  bar.appendChild(rest);
}

function render() {
  if (!engine) {
    publish(null);
    return;
  }
  const st = read();
  publish(st);
  place(st);
  drawBar(st);
  document.getElementById("step-count").textContent = String(st.count);
  document.getElementById("gap-fraction").textContent = `${st.gapNum}/${st.gapDen}`;
  const step = document.getElementById("step");
  const ready = st.count < st.max;
  step.classList.toggle("is-ready", ready);
  step.setAttribute("aria-disabled", String(!ready));
  const undo = document.getElementById("undo");
  undo.classList.toggle("is-dim", st.count === 0);
  undo.setAttribute("aria-disabled", String(st.count === 0));
  const resting = document.getElementById("resting");
  if (resting) resting.hidden = true;
}

function stopAuto() {
  if (timer) window.clearInterval(timer);
  timer = null;
  const button = document.getElementById("auto");
  if (!button) return;
  button.setAttribute("aria-pressed", "false");
  const label = button.querySelector("[data-i18n]");
  if (label) {
    label.dataset.i18n = "stepsAuto";
    label.textContent = t("stepsAuto");
  }
}

function startAuto() {
  stopAuto();
  const button = document.getElementById("auto");
  button.setAttribute("aria-pressed", "true");
  const label = button.querySelector("[data-i18n]");
  if (label) {
    label.dataset.i18n = "stepsStop";
    label.textContent = t("stepsStop");
  }
  timer = window.setInterval(() => {
    if (!engine) return;
    const before = read();
    if (before.count >= before.max) {
      stopAuto();
      play("no");
      return;
    }
    engine.steps_step();
    playRise(read().count);
    render();
  }, 680);
}

function showFailure(error) {
  wasmKey = "wasmFailed";
  fault = error?.message || String(error);
  publish(null);
  const resting = document.getElementById("resting");
  if (resting) resting.hidden = false;
}

async function boot() {
  publish(null);
  try {
    const response = await fetch("steps.wasm?v=2");
    if (!response.ok) throw new Error(`steps.wasm ${response.status}`);
    const bytes = await response.arrayBuffer();
    wasmBytes = bytes.byteLength;
    const {instance} = await WebAssembly.instantiate(bytes);
    engine = instance.exports;
    wasmKey = "wasmReady";
    engine.steps_reset();
    render();
  } catch (error) {
    showFailure(error);
  }
}

document.getElementById("step").addEventListener("click", () => {
  if (!engine) return;
  const st = read();
  if (st.count >= st.max) {
    play("no");
    return;
  }
  engine.steps_step();
  playRise(read().count);
  render();
});
document.getElementById("auto").addEventListener("click", () => {
  if (!engine) return;
  if (timer) stopAuto();
  else startAuto();
});
document.getElementById("undo").addEventListener("click", () => {
  if (!engine) return;
  stopAuto();
  if (read().count === 0) {
    play("no");
    return;
  }
  engine.steps_undo();
  play("undo");
  render();
});
document.getElementById("reset").addEventListener("click", () => {
  if (!engine) return;
  stopAuto();
  engine.steps_reset();
  play("reset");
  render();
});
window.addEventListener("languagechange", () => {
  if (engine) render();
  else publish(null);
  if (timer) {
    const label = document.querySelector("#auto [data-i18n]");
    if (label) label.textContent = t("stepsStop");
  }
});
window.addEventListener("resize", () => {
  if (engine) place(read());
});
boot();
