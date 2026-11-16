import "./shell.js?v=1";
import {t} from "./i18n.js?v=1";
import {play, playFall, playRise} from "./sounds.js?v=1";

const NS = "http://www.w3.org/2000/svg";
const FRAME = ["#3d5a80", "#e07a5f", "#e9c46a", "#2a9d8f", "#6d597a", "#241833"];
const PAPER = ["#f4f7fb", "#fff1ec", "#fff8e8", "#eef8f4", "#f4eef8", "#f7f3ee"];
const SEED = `<svg class="seed" viewBox="0 0 80 80" aria-hidden="true">
  <ellipse cx="40" cy="62" rx="18" ry="7" fill="#c4a15a"/>
  <path d="M40 58 C40 40 22 36 18 20" fill="none" stroke="#2a9d8f" stroke-width="5" stroke-linecap="round"/>
  <ellipse cx="22" cy="22" rx="12" ry="8" transform="rotate(-30 22 22)" fill="#81b29a"/>
  <circle cx="40" cy="36" r="14" fill="#e9c46a"/>
  <circle cx="40" cy="36" r="5" fill="#fff6ea"/>
</svg>`;

const frames = document.getElementById("frames");
const stack = document.getElementById("stack");
const tree = document.getElementById("tree");
const rabbits = document.getElementById("rabbits");
const depthInput = document.getElementById("depth");
const depthN = document.getElementById("depth-n");
const rabbitN = document.getElementById("rabbit-n");
const deeper = document.getElementById("deeper");
const back = document.getElementById("back");
const next = document.getElementById("next");

let wasm = null;

function read() {
  const exp = wasm.exports;
  const memory = exp.memory.buffer;
  const meta = new Int32Array(memory, exp.recursion_meta() >>> 0, 12);
  const segments = meta[3];
  const dots = meta[8];
  return {
    depth: meta[0],
    maxDepth: meta[1],
    tree: meta[2],
    segments,
    terms: meta[4],
    value: meta[5],
    older: meta[6],
    newer: meta[7],
    dots,
    error: meta[9],
    seg: new Int32Array(memory, exp.recursion_segments() >>> 0, Math.max(segments, 1) * 5),
    dot: new Int32Array(memory, exp.recursion_dots() >>> 0, Math.max(dots, 1) * 4)
  };
}

function drawFrames(state) {
  let inner = SEED;
  for (let level = state.depth; level >= 1; level -= 1) {
    inner = `<div class="nest" style="border-color:${FRAME[level - 1]};background:${PAPER[level - 1]}">${inner}</div>`;
  }
  frames.innerHTML = inner;
  stack.replaceChildren();
  for (let level = 1; level <= state.maxDepth; level += 1) {
    const item = document.createElement("li");
    item.style.background = level <= state.depth ? FRAME[level - 1] : "#eadcc6";
    if (level === state.depth) item.classList.add("here");
    stack.append(item);
  }
  deeper.classList.toggle("is-dim", state.depth >= state.maxDepth);
  deeper.setAttribute("aria-disabled", state.depth >= state.maxDepth ? "true" : "false");
  back.classList.toggle("is-dim", state.depth <= 1);
  back.setAttribute("aria-disabled", state.depth <= 1 ? "true" : "false");
}

function drawTree(state) {
  const parts = [];
  for (let i = 0; i < state.segments; i += 1) {
    const base = i * 5;
    const level = state.seg[base + 4];
    const width = Math.max(7, 30 * 0.72 ** level);
    const colour = level === 0 ? "#241833" : "#1f7a45";
    parts.push(
      `<line x1="${state.seg[base]}" y1="${1000 - state.seg[base + 1]}" x2="${state.seg[base + 2]}" y2="${1000 - state.seg[base + 3]}" stroke="${colour}" stroke-width="${width.toFixed(1)}" stroke-linecap="round"/>`
    );
  }
  tree.innerHTML = parts.join("");
  depthInput.value = String(state.tree);
  depthN.textContent = String(state.tree);
}

function drawRabbits(state) {
  if (state.dots === 0) {
    rabbits.innerHTML = `<circle cx="500" cy="500" r="220" fill="#fffdf8" stroke="#eadcc6" stroke-width="16"/>`;
  } else {
    const marks = [];
    let redRight = -1;
    let blueLeft = 2000;
    for (let i = 0; i < state.dots; i += 1) {
      const x = state.dot[i * 4];
      const y = 1000 - state.dot[i * 4 + 1];
      const r = state.dot[i * 4 + 2];
      const color = state.dot[i * 4 + 3];
      if (color === 0) redRight = Math.max(redRight, x);
      else blueLeft = Math.min(blueLeft, x);
      marks.push(`<circle cx="${x}" cy="${y}" r="${r}" fill="${color === 0 ? "#e23b4a" : "#2c6bed"}"/>`);
    }
    if (state.terms >= 3 && redRight > 0 && blueLeft < 2000) {
      const mid = (redRight + blueLeft) / 2;
      marks.unshift(`<rect x="${mid - 10}" y="180" width="20" height="640" rx="10" fill="#241833"/>`);
    }
    rabbits.innerHTML = marks.join("");
  }
  rabbitN.textContent = String(state.value);
  next.classList.toggle("is-dim", state.terms >= 11);
  next.setAttribute("aria-disabled", state.terms >= 11 ? "true" : "false");
}

function show(state) {
  drawFrames(state);
  drawTree(state);
  drawRabbits(state);
  window.GEB.state = {
    wasm: "ok",
    string: `${state.depth} / ${state.tree} / ${state.value}`,
    history: `${state.segments} branches`,
    error: t("err" + state.error)
  };
  window.GEB.refreshDebug?.();
}

function draw() {
  show(read());
}

deeper.addEventListener("click", () => {
  const before = read().depth;
  wasm.exports.recursion_deeper();
  const state = read();
  if (state.error === 0 && state.depth > before) playRise(state.depth);
  else play("no");
  show(state);
});

back.addEventListener("click", () => {
  const before = read().depth;
  wasm.exports.recursion_back();
  const state = read();
  if (state.error === 0 && state.depth < before) playFall(before);
  else play("no");
  show(state);
});

depthInput.addEventListener("input", () => {
  wasm.exports.recursion_tree(Number(depthInput.value));
  draw();
});

next.addEventListener("click", () => {
  wasm.exports.recursion_next();
  const state = read();
  if (state.error === 0) playRise(state.terms);
  else play("no");
  show(state);
});

document.getElementById("rabbit-reset").addEventListener("click", () => {
  wasm.exports.recursion_rabbits_reset();
  play("reset");
  draw();
});

const response = await fetch("recursion.wasm?v=1");
const {instance} = await WebAssembly.instantiate(await response.arrayBuffer());
wasm = instance;
wasm.exports.recursion_reset();
draw();
