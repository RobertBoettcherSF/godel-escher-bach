import "./shell.js?v=1";
import {t} from "./i18n.js?v=1";
import {play, playChime} from "./sounds.js?v=1";

const NS = "http://www.w3.org/2000/svg";
const VIEW_W = 1000;
const VIEW_H = 640;

let engine = null;
let wasmBytes = 0;
let wasmKey = "wasmLoading";
let fault = "";
let built = false;
let lastFront = null;

function read() {
  const shapes = engine.figure_shapes();
  const memory = engine.memory.buffer;
  const meta = new Int32Array(memory, engine.figure_meta() >>> 0, 9);
  const counts = new Int32Array(memory, engine.figure_outline_count() >>> 0, shapes);
  const stride = engine.figure_outline_stride();
  const xy = new Float32Array(memory, engine.figure_outline_xy() >>> 0, shapes * stride);
  return {
    shapes,
    blend: meta[0],
    front: meta[1],
    taps: meta[2],
    hidden: meta[3],
    found: meta[4],
    error: meta[5],
    last: meta[7],
    grow: meta[8],
    layer: new Int32Array(memory, engine.figure_shape_layer() >>> 0, shapes),
    kind: new Int32Array(memory, engine.figure_shape_kind() >>> 0, shapes),
    ink: new Int32Array(memory, engine.figure_shape_ink() >>> 0, shapes),
    counts,
    stride,
    xy
  };
}

function pointsOf(st, shape) {
  const pts = [];
  const base = shape * st.stride;
  const count = st.counts[shape];
  for (let i = 0; i < count; i += 1) {
    pts.push({x: st.xy[base + i * 2], y: st.xy[base + i * 2 + 1]});
  }
  return pts;
}

function pathOf(pts) {
  let d = "";
  for (let i = 0; i < pts.length; i += 1) {
    d += `${i === 0 ? "M" : "L"}${pts[i].x.toFixed(2)},${pts[i].y.toFixed(2)}`;
  }
  return `${d}Z`;
}

function marks(pts, right) {
  let cx = 0;
  let cy = 0;
  let nose = pts[0];
  for (const p of pts) {
    cx += p.x;
    cy += p.y;
    if (right ? p.x > nose.x : p.x < nose.x) nose = p;
  }
  cx /= pts.length;
  cy /= pts.length;
  const sign = right ? 1 : -1;
  const reach = Math.abs(nose.x - cx);
  return {
    eye: {x: cx + sign * reach * 0.55, y: cy + 26},
    x1: cx + sign * reach * 0.08,
    y1: cy + 30,
    x2: cx + sign * reach * 0.18,
    y2: cy + 42
  };
}

function publish(st) {
  const layer = st ? t(st.front === 0 ? "figDark" : "figLight") : "—";
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

function buildPicture(st) {
  const svg = document.getElementById("picture");
  svg.setAttribute("viewBox", `0 0 ${VIEW_W} ${VIEW_H}`);
  svg.replaceChildren();
  const defs = document.createElementNS(NS, "defs");
  const filter = document.createElementNS(NS, "filter");
  filter.id = "animal-glow";
  filter.setAttribute("x", "-40%");
  filter.setAttribute("y", "-40%");
  filter.setAttribute("width", "180%");
  filter.setAttribute("height", "180%");
  add(filter, "feGaussianBlur", {stdDeviation: "5", in: "SourceGraphic"});
  defs.appendChild(filter);
  const clip = document.createElementNS(NS, "clipPath");
  clip.id = "window-clip";
  add(clip, "rect", {x: "0", y: "0", width: String(VIEW_W), height: String(VIEW_H)});
  defs.appendChild(clip);
  svg.appendChild(defs);

  const window = document.createElementNS(NS, "g");
  window.setAttribute("clip-path", "url(#window-clip)");
  const world = document.createElementNS(NS, "g");
  world.setAttribute("transform", `translate(0 ${VIEW_H}) scale(1 -1)`);
  window.appendChild(world);
  svg.appendChild(window);

  const order = [];
  for (let shape = 0; shape < st.shapes; shape += 1) {
    if (st.layer[shape] !== st.front) order.push(shape);
  }
  for (let shape = 0; shape < st.shapes; shape += 1) {
    if (st.layer[shape] === st.front) order.push(shape);
  }

  for (const shape of order) {
    const pts = pointsOf(st, shape);
    const right = st.layer[shape] === 0;
    const detail = marks(pts, right);
    const group = document.createElementNS(NS, "g");
    group.dataset.shape = String(shape);
    group.classList.add("animal", right ? "dark" : "light");
    group.setAttribute("role", "button");
    group.tabIndex = 0;
    group.addEventListener("click", () => onTap(shape));
    group.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        onTap(shape);
      }
    });
    add(group, "path", {class: "glow", d: pathOf(pts), filter: "url(#animal-glow)"});
    add(group, "path", {class: "body", d: pathOf(pts)});
    add(group, "line", {
      class: "feather",
      x1: detail.x1,
      y1: detail.y1,
      x2: detail.x2,
      y2: detail.y2
    });
    add(group, "circle", {class: "eye-ring", cx: detail.eye.x, cy: detail.eye.y, r: "11"});
    add(group, "circle", {class: "eye-white", cx: detail.eye.x + (right ? 1 : -1), cy: detail.eye.y, r: "6.2"});
    add(group, "circle", {class: "pupil", cx: detail.eye.x + (right ? 3.2 : -3.2), cy: detail.eye.y, r: "3.1"});
    world.appendChild(group);
  }
  built = true;
}

function paint(st, wiggle) {
  const svg = document.getElementById("picture");
  if (!built) buildPicture(st);
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const showMarks = st.grow >= 28;
  for (let shape = 0; shape < st.shapes; shape += 1) {
    const group = svg.querySelector(`g[data-shape="${shape}"]`);
    if (!group) continue;
    const dark = st.layer[shape] === 0;
    const front = st.layer[shape] === st.front;
    const body = group.querySelector(".body");
    body.setAttribute("fill", dark ? "#201830" : "#fffaf2");
    group.classList.toggle("front", front);
    const found = st.found === 1 && st.last === shape;
    group.classList.toggle("found", found);
    group.querySelector(".feather").style.display = showMarks ? "" : "none";
    group.querySelectorAll(".eye-ring, .eye-white, .pupil").forEach((node) => {
      node.style.display = showMarks ? "" : "none";
    });
    const scale = (st.grow / 100) * (front ? 1 : 0.62);
    const eye = group.querySelector(".eye-ring");
    const white = group.querySelector(".eye-white");
    const pupil = group.querySelector(".pupil");
    const feather = group.querySelector(".feather");
    eye.setAttribute("r", String(11 * scale));
    white.setAttribute("r", String(6.2 * scale));
    pupil.setAttribute("r", String(3.1 * scale));
    feather.setAttribute("stroke-width", front ? "4.5" : "2.4");
    group.setAttribute("aria-label", t(dark ? "figDark" : "figLight"));
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
  const svg = document.getElementById("picture");
  const previous = svg.dataset.grow;
  if (!built || previous !== String(st.grow) || svg.dataset.front !== String(st.front)) {
    built = false;
    buildPicture(st);
    svg.dataset.grow = String(st.grow);
    svg.dataset.front = String(st.front);
  }
  paint(st, Boolean(options.wiggle) && st.front !== lastFront);
  lastFront = st.front;
  const grow = document.getElementById("grow");
  if (document.activeElement !== grow) grow.value = String(st.grow);
  const find = document.getElementById("find");
  const key = st.found === 1 ? "figFound" : "figFind";
  find.dataset.i18n = key;
  find.textContent = t(key);
  document.getElementById("who").textContent = t(st.front === 0 ? "figDark" : "figLight");
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

document.getElementById("grow").addEventListener("input", (event) => {
  if (!engine) return;
  engine.figure_grow(Number(event.target.value));
  render();
});
document.getElementById("undo").addEventListener("click", () => {
  if (!engine) return;
  const before = read();
  engine.figure_undo();
  const after = read();
  if (after.error !== 0 && after.taps === before.taps && after.blend === before.blend && after.grow === before.grow) play("no");
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
