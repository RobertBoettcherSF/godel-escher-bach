import "./shell.js?v=1";
import {t} from "./i18n.js?v=1";
import {play, playChime} from "./sounds.js?v=1";

const NS = "http://www.w3.org/2000/svg";

// One bird and the fish tucked under its belly. The belly cubics are repeated,
// reversed, as the fish's back, so the two outlines share that curve.
const BIRD = [
  "M 72,146",
  "C 28,162 4,128 24,108",
  "C 2,92 10,64 40,74",
  "C 62,36 108,16 148,42",
  "C 168,8 196,-28 214,8",
  "C 232,42 220,74 242,82",
  "C 262,52 308,46 328,70",
  "C 362,58 404,82 368,102",
  "C 340,118 312,124 286,130",
  "C 250,168 214,188 190,160",
  "C 175,118 158,116 146,158",
  "C 112,188 78,162 72,146",
  "Z",
  "M 168,72 C 188,8 255,-18 232,58 C 220,82 182,88 168,72 Z"
].join(" ");

const FISH = [
  "M 72,146",
  "C 78,162 112,188 146,158",
  "C 158,116 175,118 190,160",
  "C 214,188 250,168 286,130",
  "C 340,150 410,168 436,206",
  "C 392,214 430,246 384,226",
  "C 310,258 200,250 120,236",
  "C 48,222 4,196 18,166",
  "C 28,144 48,142 72,146",
  "Z",
  "M 412,172 L 520,118 L 438,188 Z",
  "M 414,198 L 524,262 L 436,210 Z",
  "M 155,160 L 196,96 L 232,164 Z"
].join(" ");

const PLACES = [
  [8, 40],
  [520, 40],
  [260, 290],
  [772, 290]
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
  svg.setAttribute("viewBox", "-20 -40 1400 700");
  svg.replaceChildren();
  const filter = document.createElementNS(NS, "filter");
  filter.id = "animal-glow";
  filter.setAttribute("x", "-20%");
  filter.setAttribute("y", "-20%");
  filter.setAttribute("width", "140%");
  filter.setAttribute("height", "140%");
  add(filter, "feGaussianBlur", {stdDeviation: "5", in: "SourceGraphic"});
  const defs = document.createElementNS(NS, "defs");
  defs.appendChild(filter);
  svg.appendChild(defs);

  PLACES.forEach(([x, y], place) => {
    [0, 1].forEach((part) => {
      const shape = place * 2 + part;
      const group = document.createElementNS(NS, "g");
      group.dataset.shape = String(shape);
      group.classList.add("animal");
      group.setAttribute("role", "button");
      group.tabIndex = 0;
      group.setAttribute("transform", `translate(${x} ${y})`);
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
          d: "M 175,70 C 198,18 236,16 220,72"
        });
        add(group, "path", {
          class: "mark",
          d: "M 36,96 C 16,82 22,66 44,76"
        });
        add(group, "circle", {class: "eye-ring", cx: "322", cy: "78", r: "16"});
        add(group, "circle", {class: "eye-white", cx: "322", cy: "78", r: "10"});
        add(group, "circle", {class: "pupil", cx: "327", cy: "78", r: "4.5"});
        add(group, "polygon", {
          class: "beak",
          points: "340,70 408,90 344,108"
        });
      } else {
        add(group, "path", {
          class: "mark",
          d: "M 168,150 C 176,128 196,130 188,156"
        });
        add(group, "circle", {class: "eye-ring", cx: "58", cy: "176", r: "15"});
        add(group, "circle", {class: "eye-white", cx: "58", cy: "176", r: "9"});
        add(group, "circle", {class: "pupil", cx: "53", cy: "176", r: "4"});
      }
      svg.appendChild(group);
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
    group.querySelector(".body").setAttribute("fill", fill);
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
