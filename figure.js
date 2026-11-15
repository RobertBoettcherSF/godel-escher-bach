import "./shell.js?v=1";
import {t} from "./i18n.js?v=1";
import {play, playChime} from "./sounds.js?v=1";

const NS = "http://www.w3.org/2000/svg";
const CELL_W = 720;
const CELL_H = 460;

let engine = null;
let wasmBytes = 0;
let wasmKey = "wasmLoading";
let fault = "";
let built = false;
let lastFront = null;

function read() {
  const shapes = engine.figure_shapes();
  const memory = engine.memory.buffer;
  const meta = new Int32Array(memory, engine.figure_meta() >>> 0, 8);
  return {
    shapes,
    blend: meta[0],
    front: meta[1],
    taps: meta[2],
    hidden: meta[3],
    found: meta[4],
    error: meta[5],
    last: meta[7],
    layer: new Int32Array(memory, engine.figure_shape_layer() >>> 0, shapes),
    kind: new Int32Array(memory, engine.figure_shape_kind() >>> 0, shapes),
    ink: new Int32Array(memory, engine.figure_shape_ink() >>> 0, shapes)
  };
}

function inkColour(ink) {
  const mix = ink / 255;
  const r = Math.round(255 + (36 - 255) * mix);
  const g = Math.round(246 + (24 - 246) * mix);
  const b = Math.round(234 + (51 - 234) * mix);
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

function add(parent, name, attrs) {
  const node = document.createElementNS(NS, name);
  for (const [key, value] of Object.entries(attrs)) node.setAttribute(key, value);
  parent.appendChild(node);
  return node;
}

function outlinePath(shape) {
  const count = new Int32Array(engine.memory.buffer, engine.figure_outline_count(), 8)[shape];
  const xy = new Int32Array(engine.memory.buffer, engine.figure_outline_xy(), 8 * 200 * 2);
  const base = shape * 200 * 2;
  let d = "";
  for (let i = 0; i < count; i += 1) {
    const x = xy[base + i * 2];
    const y = xy[base + i * 2 + 1];
    d += `${i === 0 ? "M" : "L"}${x} ${y} `;
  }
  return `${d}Z`;
}

function cellOf(shape) {
  const pair = Math.floor(shape / 2);
  return {col: pair % 2, row: Math.floor(pair / 2)};
}

function shiftPath(shape, d) {
  const {col, row} = cellOf(shape);
  const dx = col * CELL_W;
  const dy = row * CELL_H;
  const nums = d.match(/-?\d+(\.\d+)?/g).map(Number);
  let out = "";
  let n = 0;
  for (const token of d.split(/(-?\d+(?:\.\d+)?)/)) {
    if (/^-?\d/.test(token)) {
      out += String(nums[n] + (n % 2 === 0 ? dx : dy));
      n += 1;
    } else out += token;
  }
  return out;
}

function buildPicture() {
  const svg = document.getElementById("picture");
  const counts = new Int32Array(engine.memory.buffer, engine.figure_outline_count(), 8);
  const xy = new Int32Array(engine.memory.buffer, engine.figure_outline_xy(), 8 * 200 * 2);
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  for (let i = 0; i < xy.length; i += 2) {
    const used = counts[Math.floor(i / 2 / 200)] > ((i / 2) % 200);
    if (!used) continue;
    minX = Math.min(minX, xy[i]);
    maxX = Math.max(maxX, xy[i]);
    minY = Math.min(minY, xy[i + 1]);
    maxY = Math.max(maxY, xy[i + 1]);
  }
  const inset = 4;
  svg.setAttribute("viewBox", `${minX + inset} ${minY + inset} ${maxX - minX - inset * 2} ${maxY - minY - inset * 2}`);
  svg.replaceChildren();
  const filter = document.createElementNS(NS, "filter");
  filter.id = "animal-glow";
  filter.setAttribute("x", "-30%");
  filter.setAttribute("y", "-30%");
  filter.setAttribute("width", "160%");
  filter.setAttribute("height", "160%");
  add(filter, "feGaussianBlur", {stdDeviation: "5", in: "SourceGraphic"});
  const defs = document.createElementNS(NS, "defs");
  defs.appendChild(filter);
  svg.appendChild(defs);

  for (let shape = 0; shape < 8; shape += 1) {
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
    const outline = outlinePath(shape);
    add(group, "path", {class: "glow", d: outline, filter: "url(#animal-glow)"});
    add(group, "path", {class: "body", d: outline});
    if (shape % 2 === 0) {
      add(group, "path", {class: "mark", d: shiftPath(shape, "M 120 150 C 200 80 280 90 330 160")});
      add(group, "path", {class: "mark", d: shiftPath(shape, "M 140 200 C 220 140 300 150 340 210")});
      add(group, "path", {class: "bill-upper", d: shiftPath(shape, "M 300 128 C 340 118 390 132 360 148 C 330 140 305 138 300 132 Z")});
      add(group, "circle", {class: "eye-ring", cx: String(300 + cellOf(shape).col * CELL_W), cy: String(150 + cellOf(shape).row * CELL_H), r: "26"});
      add(group, "circle", {class: "eye-white", cx: String(300 + cellOf(shape).col * CELL_W), cy: String(150 + cellOf(shape).row * CELL_H), r: "12"});
      add(group, "circle", {class: "pupil", cx: String(308 + cellOf(shape).col * CELL_W), cy: String(150 + cellOf(shape).row * CELL_H), r: "6"});
    } else {
      add(group, "path", {class: "mark", d: shiftPath(shape, "M 560 150 C 640 110 700 130 730 190")});
      add(group, "circle", {class: "eye-ring", cx: String(520 + cellOf(shape).col * CELL_W), cy: String(210 + cellOf(shape).row * CELL_H), r: "28"});
      add(group, "circle", {class: "eye-white", cx: String(520 + cellOf(shape).col * CELL_W), cy: String(210 + cellOf(shape).row * CELL_H), r: "14"});
      add(group, "circle", {class: "pupil", cx: String(512 + cellOf(shape).col * CELL_W), cy: String(210 + cellOf(shape).row * CELL_H), r: "6"});
    }
    svg.appendChild(group);
  }
  built = true;
}

function paint(st, wiggle) {
  const svg = document.getElementById("picture");
  if (!built) buildPicture();
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  for (let shape = 0; shape < st.shapes; shape += 1) {
    const group = svg.querySelector(`g[data-shape="${shape}"]`);
    if (!group) continue;
    const ink = st.ink[shape];
    const fill = inkColour(ink);
    const line = ink > 140 ? "#fff6ea" : "#241833";
    const body = group.querySelector(".body");
    body.setAttribute("fill", fill);
    body.setAttribute("stroke", line);
    body.setAttribute("stroke-width", "5");
    body.setAttribute("stroke-linejoin", "round");
    group.querySelectorAll(".mark").forEach((mark) => {
      mark.setAttribute("fill", "none");
      mark.setAttribute("stroke", line);
      mark.setAttribute("stroke-width", "5");
      mark.setAttribute("stroke-linecap", "round");
    });
    const found = st.found === 1 && st.last === shape;
    group.classList.toggle("found", found);
    const name = t(st.kind[shape] === 0 ? "figBirds" : "figFish");
    group.setAttribute("aria-label", name);
    if (wiggle && !reduced && st.layer[shape] === st.front) {
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
  document.getElementById("who").textContent = t(st.front === 0 ? "figBirds" : "figFish");
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
    const response = await fetch("figure.wasm?v=34");
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
  const after = read();
  if (after.error !== 0 && after.taps === before.taps && after.blend === before.blend) play("no");
  else play("undo");
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
