import "./shell.js?v=1";
import {t} from "./i18n.js?v=1";
import {play, playChime} from "./sounds.js?v=1";

const NS = "http://www.w3.org/2000/svg";

// One bird and the fish under its belly. The four shared cubics are stored
// once and reversed, so the bird's belly and the fish's back are the same curve.
const BIRD = [
  "M 52,150",
  "C 18,140 2,112 20,92",
  "C 2,78 8,46 36,58",
  "C 18,32 34,8 62,28",
  "C 96,8 118,30 124,62",
  "C 136,18 186,-16 228,18",
  "C 252,38 214,74 176,66",
  "C 214,46 258,28 300,48",
  "C 336,22 378,30 412,58",
  "C 376,74 338,90 304,82",
  "C 276,108 256,138 236,156",
  "C 220,148 200,132 188,150",
  "C 176,130 166,100 158,102",
  "C 150,100 140,120 132,158",
  "C 108,176 78,168 52,150",
  "Z"
].join(" ");

const FISH = [
  "M 16,188",
  "C 4,170 22,152 52,150",
  "C 78,168 108,176 132,158",
  "C 140,120 150,100 158,102",
  "C 166,100 176,130 188,150",
  "C 200,132 220,148 236,156",
  "C 268,162 300,170 322,186",
  "C 352,156 424,132 492,156",
  "C 444,172 392,184 356,188",
  "C 400,206 456,258 504,232",
  "C 452,274 372,252 330,220",
  "C 300,200 260,214 220,226",
  "C 186,236 158,276 124,250",
  "C 100,232 78,238 58,220",
  "C 40,206 26,200 16,188",
  "Z"
].join(" ");

const PLACES = [
  [8, 28],
  [540, 28],
  [8, 348],
  [540, 348]
];

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

function buildPicture() {
  const svg = document.getElementById("picture");
  svg.setAttribute("viewBox", "-16 -8 1100 660");
  svg.replaceChildren();
  const filter = document.createElementNS(NS, "filter");
  filter.id = "animal-glow";
  filter.setAttribute("x", "-40%");
  filter.setAttribute("y", "-40%");
  filter.setAttribute("width", "180%");
  filter.setAttribute("height", "180%");
  add(filter, "feGaussianBlur", {stdDeviation: "5", in: "SourceGraphic"});
  const defs = document.createElementNS(NS, "defs");
  defs.appendChild(filter);
  svg.appendChild(defs);

  PLACES.forEach(([x, y], place) => {
    [0, 1].forEach((part) => {
      const shape = place * 2 + part;
      const placed = document.createElementNS(NS, "g");
      placed.setAttribute("transform", `translate(${x} ${y})`);
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
      const outline = part === 0 ? BIRD : FISH;
      add(group, "path", {
        class: "glow",
        d: outline,
        filter: "url(#animal-glow)"
      });
      add(group, "path", {class: "body", d: outline});
      if (part === 0) {
        add(group, "path", {
          class: "mark",
          d: "M 158,44 C 188,12 222,22 198,54"
        });
        add(group, "circle", {class: "eye-ring", cx: "292", cy: "66", r: "16"});
        add(group, "circle", {class: "eye-white", cx: "292", cy: "66", r: "9"});
        add(group, "circle", {class: "pupil", cx: "297", cy: "66", r: "4.5"});
        add(group, "polygon", {
          class: "beak",
          points: "318,56 396,72 320,88"
        });
      } else {
        add(group, "path", {
          class: "mark",
          d: "M 150,224 C 142,252 118,250 126,226"
        });
        add(group, "circle", {class: "eye-ring", cx: "46", cy: "178", r: "14"});
        add(group, "circle", {class: "eye-white", cx: "46", cy: "178", r: "8"});
        add(group, "circle", {class: "pupil", cx: "41", cy: "178", r: "3.5"});
      }
      placed.appendChild(group);
      svg.appendChild(placed);
    });
  });
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
    group.classList.toggle("gap", ink < 90);
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
    const response = await fetch("figure.wasm?v=31");
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
