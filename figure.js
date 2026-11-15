import "./shell.js?v=1";
import {t} from "./i18n.js?v=1";
import {play, playChime} from "./sounds.js?v=1";

const NS = "http://www.w3.org/2000/svg";
let engine = null;
let wasmBytes = 0;
let wasmKey = "wasmLoading";
let fault = "";
let built = false;
let lastFront = null;

function read() {
  const cols = engine.figure_cols();
  const rows = engine.figure_rows();
  const shapes = engine.figure_shapes();
  const cells = cols * rows;
  const memory = engine.memory.buffer;
  const meta = new Int32Array(memory, engine.figure_meta() >>> 0, 8);
  return {
    cols,
    rows,
    shapes,
    cells,
    blend: meta[0],
    front: meta[1],
    taps: meta[2],
    hidden: meta[3],
    found: meta[4],
    error: meta[5],
    cellShape: new Int32Array(memory, engine.figure_cell_shape() >>> 0, cells),
    cellLayer: new Int32Array(memory, engine.figure_cell_layer() >>> 0, cells),
    cellInk: new Int32Array(memory, engine.figure_cell_ink() >>> 0, cells),
    shapeLayer: new Int32Array(memory, engine.figure_shape_layer() >>> 0, shapes),
    shapeKind: new Int32Array(memory, engine.figure_shape_kind() >>> 0, shapes),
    shapeHead: new Int32Array(memory, engine.figure_shape_head() >>> 0, shapes),
    dirC: new Int32Array(memory, engine.figure_shape_dir_c() >>> 0, shapes),
    dirR: new Int32Array(memory, engine.figure_shape_dir_r() >>> 0, shapes)
  };
}

function inkColour(ink) {
  const tMix = ink / 255;
  const r = Math.round(255 + (36 - 255) * tMix);
  const g = Math.round(246 + (24 - 246) * tMix);
  const b = Math.round(234 + (51 - 234) * tMix);
  return `rgb(${r} ${g} ${b})`;
}

function publish(st) {
  const layer = st ? t(st.front === 0 ? "figBirds" : "figFish") : "—";
  window.GEB.state = {
    wasm: `${t(wasmKey)}${wasmBytes ? " · " + wasmBytes : ""}`,
    string: layer,
    history: st ? String(st.taps) : "—",
    error: fault || (st ? `${st.error} ${t("err" + st.error)}` : "—"),
    layer,
    taps: st ? String(st.taps) : "—"
  };
  window.GEB.refreshDebug?.();
}

function buildPicture(st) {
  const svg = document.getElementById("picture");
  svg.setAttribute("viewBox", `0 0 ${st.cols} ${st.rows}`);
  svg.replaceChildren();
  const groups = [];
  for (let shape = 0; shape < st.shapes; shape += 1) {
    const group = document.createElementNS(NS, "g");
    group.dataset.shape = String(shape);
    group.classList.add("animal");
    group.setAttribute("role", "button");
    group.tabIndex = 0;
    group.addEventListener("click", () => onTap(shape));
    group.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        onTap(shape);
      }
    });
    svg.appendChild(group);
    groups[shape] = group;
  }
  for (let index = 0; index < st.cells; index += 1) {
    const shape = st.cellShape[index];
    const rect = document.createElementNS(NS, "rect");
    rect.setAttribute("x", String((index % st.cols) - 0.06));
    rect.setAttribute("y", String(Math.floor(index / st.cols) - 0.06));
    rect.setAttribute("width", "1.12");
    rect.setAttribute("height", "1.12");
    rect.dataset.cell = String(index);
    groups[shape].appendChild(rect);
  }
  for (let shape = 0; shape < st.shapes; shape += 1) {
    const head = st.shapeHead[shape];
    const col = (head % st.cols) + 0.5;
    const row = Math.floor(head / st.cols) + 0.5;
    const dx = st.dirC[shape];
    const eye = document.createElementNS(NS, "circle");
    eye.setAttribute("class", "eye");
    eye.dataset.face = String(shape);
    eye.setAttribute("cx", String(col - dx * 0.05));
    eye.setAttribute("cy", String(row - 0.12));
    eye.setAttribute("r", "0.46");
    groups[shape].appendChild(eye);
    const pupil = document.createElementNS(NS, "circle");
    pupil.setAttribute("class", "pupil");
    pupil.setAttribute("cx", String(col + dx * 0.08));
    pupil.setAttribute("cy", String(row - 0.12));
    pupil.setAttribute("r", "0.2");
    groups[shape].appendChild(pupil);
    const beak = document.createElementNS(NS, "polygon");
    beak.setAttribute("class", "beak");
    const base = col + dx * 0.35;
    const tip = col + dx * 1.05;
    beak.setAttribute("points", `${base},${row - 0.28} ${tip},${row + 0.08} ${base},${row + 0.38}`);
    groups[shape].appendChild(beak);
  }
  built = true;
}

function paint(st, wiggle) {
  const svg = document.getElementById("picture");
  if (!built) buildPicture(st);
  svg.querySelectorAll("rect[data-cell]").forEach((rect) => {
    const index = Number(rect.dataset.cell);
    rect.setAttribute("fill", inkColour(st.cellInk[index]));
  });
  for (let shape = 0; shape < st.shapes; shape += 1) {
    const head = st.shapeHead[shape];
    const ink = st.cellInk[head];
    const eye = svg.querySelector(`.eye[data-face="${shape}"]`);
    if (eye) eye.setAttribute("fill", ink > 140 ? "#fff6ea" : "#241833");
    const group = svg.querySelector(`g[data-shape="${shape}"]`);
    if (!group) continue;
    const name = t(st.shapeKind[shape] === 0 ? "figBirds" : "figFish");
    group.setAttribute("aria-label", name);
    if (wiggle && st.shapeLayer[shape] === st.front) {
      group.classList.remove("wiggle");
      void group.getBoundingClientRect();
      group.classList.add("wiggle");
    }
  }
}

function render(options = {}) {
  if (!engine) {
    publish(null);
    return;
  }
  const st = read();
  publish(st);
  paint(st, Boolean(options.wiggle) && st.front !== lastFront);
  lastFront = st.front;
  const fade = document.getElementById("fade");
  if (document.activeElement !== fade) fade.value = String(st.blend);
  const find = document.getElementById("find");
  const key = st.found === 1 ? "figFound" : "figFind";
  find.dataset.i18n = key;
  find.textContent = t(key);
  const who = document.getElementById("who");
  who.textContent = t(st.front === 0 ? "figBirds" : "figFish");
  const resting = document.getElementById("resting");
  if (resting) resting.hidden = true;
}

function onTap(shape) {
  if (!engine) return;
  engine.figure_tap(shape);
  const st = read();
  if (st.error !== 0) {
    play("no");
    render();
    return;
  }
  playChime();
  render({wiggle: true});
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
    const response = await fetch("figure.wasm?v=3");
    if (!response.ok) throw new Error(`figure.wasm ${response.status}`);
    const bytes = await response.arrayBuffer();
    wasmBytes = bytes.byteLength;
    const {instance} = await WebAssembly.instantiate(bytes);
    engine = instance.exports;
    wasmKey = "wasmReady";
    built = false;
    engine.figure_reset();
    render();
  } catch (error) {
    showFailure(error);
  }
}

document.getElementById("fade").addEventListener("input", (event) => {
  if (!engine) return;
  engine.figure_blend(Number(event.target.value));
  render();
});
document.getElementById("undo").addEventListener("click", () => {
  if (!engine) return;
  const before = read();
  engine.figure_undo();
  if (read().error !== 0 && read().taps === before.taps && read().blend === before.blend) {
    play("no");
  } else {
    play("undo");
  }
  render({wiggle: true});
});
document.getElementById("reset").addEventListener("click", () => {
  if (!engine) return;
  engine.figure_reset();
  play("reset");
  render();
});
window.addEventListener("languagechange", () => {
  if (engine) render();
  else publish(null);
});
boot();
