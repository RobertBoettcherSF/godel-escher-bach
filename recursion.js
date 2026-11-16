import "./shell.js?v=1";
import {t} from "./i18n.js?v=1";
import {play, playFall, playRise} from "./sounds.js?v=1";

const FRAME = ["#3d5a80", "#c45c44", "#d4a017", "#1f7a64", "#6d597a", "#241833"];
const SKY = ["#d7ebf7", "#fde7dc", "#fff4d4", "#d9f3ea", "#efe4f7", "#f6f1ea"];
const FLOWER = `<svg class="flower" viewBox="0 0 80 110" aria-hidden="true">
  <ellipse cx="40" cy="102" rx="26" ry="7" fill="#c4a15a"/>
  <path d="M40 96 C40 70 18 62 14 36" fill="none" stroke="#2a9d8f" stroke-width="6" stroke-linecap="round"/>
  <ellipse cx="18" cy="34" rx="16" ry="10" transform="rotate(-28 18 34)" fill="#81b29a"/>
  <circle cx="46" cy="58" r="20" fill="#e9c46a"/>
  <circle cx="46" cy="58" r="8" fill="#fff6ea"/>
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
    dot: new Int32Array(memory, exp.recursion_dots() >>> 0, Math.max(dots, 1) * 5)
  };
}

function sceneMarkup(level) {
  const frame = level < 6
    ? `<div class="wall-frame" style="background:${FRAME[level]}">${sceneMarkup(level + 1)}</div>`
    : `<div class="wall-frame blank" style="background:${FRAME[5]}"><div class="mat"></div></div>`;
  return `<div class="scene" data-level="${level}" style="background:${SKY[level - 1]}">
    <svg class="sun" viewBox="0 0 100 100" aria-hidden="true"><g fill="#f0a202" stroke="#f0a202" stroke-width="8" stroke-linecap="round"><line x1="50" y1="4" x2="50" y2="18"/><line x1="50" y1="82" x2="50" y2="96"/><line x1="4" y1="50" x2="18" y2="50"/><line x1="82" y1="50" x2="96" y2="50"/><line x1="16" y1="16" x2="26" y2="26"/><line x1="74" y1="74" x2="84" y2="84"/><line x1="84" y1="16" x2="74" y2="26"/><line x1="26" y1="74" x2="16" y2="84"/></g><circle cx="50" cy="50" r="26" fill="#f0a202"/></svg>
    ${FLOWER}
    <div class="ground"></div>
    ${frame}
  </div>`;
}

let scenesReady = false;
let shownDepth = 0;

function ensureScenes() {
  if (scenesReady) return;
  frames.innerHTML = `<div class="story-stage"><div class="scene-cam">${sceneMarkup(1)}</div></div>`;
  scenesReady = true;
}

function zoomTransform(depth) {
  const cam = frames.querySelector(".scene-cam");
  const scene = frames.querySelector(`.scene[data-level="${depth}"]`);
  cam.style.transition = "none";
  cam.style.transform = "none";
  const camBox = cam.getBoundingClientRect();
  const targetBox = scene.getBoundingClientRect();
  const scale = Math.max(camBox.width / targetBox.width, camBox.height / targetBox.height);
  const originX = targetBox.left - camBox.left + targetBox.width / 2;
  const originY = targetBox.top - camBox.top + targetBox.height / 2;
  const tx = camBox.width / 2 - originX * scale;
  const ty = camBox.height / 2 - originY * scale;
  return `translate(${tx}px, ${ty}px) scale(${scale})`;
}

function applyZoom(depth, animate) {
  const cam = frames.querySelector(".scene-cam");
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const previous = cam.style.transform;
  const next = zoomTransform(depth);
  if (animate && !reduced && previous) {
    cam.style.transition = "none";
    cam.style.transform = previous;
    cam.getBoundingClientRect();
    cam.style.transition = "transform 0.7s ease";
    cam.style.transform = next;
  } else {
    cam.style.transition = "none";
    cam.style.transform = next;
  }
}

function drawFrames(state) {
  ensureScenes();
  stack.replaceChildren();
  for (let level = 1; level <= state.maxDepth; level += 1) {
    const item = document.createElement("li");
    item.style.background = level <= state.depth ? FRAME[level - 1] : "#eadcc6";
    if (level === state.depth) item.classList.add("here");
    stack.append(item);
  }
  if (shownDepth !== state.depth) {
    applyZoom(state.depth, shownDepth !== 0);
    shownDepth = state.depth;
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
    const mix = state.tree === 0 ? 0 : level / state.tree;
    const channel = (from, to) => Math.round(from + (to - from) * mix);
    const width = Math.max(2.2, 36 * 0.66 ** level);
    const colour = `rgb(${channel(107, 47)} ${channel(62, 122)} ${channel(38, 64)})`;
    parts.push(
      `<line x1="${state.seg[base]}" y1="${1000 - state.seg[base + 1]}" x2="${state.seg[base + 2]}" y2="${1000 - state.seg[base + 3]}" stroke="${colour}" stroke-width="${width.toFixed(1)}" stroke-linecap="round"/>`
    );
  }
  tree.innerHTML = parts.join("");
  depthInput.value = String(state.tree);
  depthN.textContent = String(state.tree);
}

function dotAt(state, index) {
  const base = index * 5;
  return {
    x: state.dot[base],
    y: 1000 - state.dot[base + 1],
    r: state.dot[base + 2],
    color: state.dot[base + 3],
    pile: state.dot[base + 4]
  };
}

function pileBounds(dots) {
  let minX = Infinity;
  let maxX = -Infinity;
  let minY = Infinity;
  let maxY = -Infinity;
  for (const dot of dots) {
    minX = Math.min(minX, dot.x - dot.r);
    maxX = Math.max(maxX, dot.x + dot.r);
    minY = Math.min(minY, dot.y - dot.r);
    maxY = Math.max(maxY, dot.y + dot.r);
  }
  return {minX, maxX, minY, maxY, cx: (minX + maxX) / 2};
}

function drawRabbits(state) {
  const marks = [];
  const piles = [[], [], []];
  for (let i = 0; i < state.dots; i += 1) {
    const dot = dotAt(state, i);
    piles[dot.pile].push(dot);
    marks.push(`<circle cx="${dot.x}" cy="${dot.y}" r="${dot.r}" fill="${dot.color === 0 ? "#e23b4a" : "#2c6bed"}"/>`);
  }
  const label = (dots, text, size) => {
    if (!dots.length) return;
    const box = pileBounds(dots);
    marks.push(`<text x="${box.cx}" y="${box.maxY + size}" text-anchor="middle" font-size="${size}" font-weight="700" fill="#241833">${text}</text>`);
  };
  if (state.terms >= 3) {
    label(piles[0], String(state.older), 34);
    label(piles[1], String(state.newer), 34);
    label(piles[2], String(state.value), 42);
    const left = pileBounds(piles[0]);
    const mid = pileBounds(piles[1]);
    const right = pileBounds(piles[2]);
    const rowY = (right.minY + right.maxY) / 2;
    const plusX = (left.maxX + mid.minX) / 2;
    marks.push(`<text x="${plusX}" y="${rowY}" text-anchor="middle" dominant-baseline="middle" font-size="48" font-weight="700" fill="#241833">+</text>`);
    const x1 = mid.maxX + 18;
    const x2 = right.minX - 16;
    marks.push(`<line x1="${x1}" y1="${rowY}" x2="${x2}" y2="${rowY}" stroke="#241833" stroke-width="7" stroke-linecap="round"/>`);
    marks.push(`<polygon points="${x2},${rowY} ${x2 - 18},${rowY - 12} ${x2 - 18},${rowY + 12}" fill="#241833"/>`);
  } else {
    label(piles[2], String(state.value), 56);
  }
  rabbits.innerHTML = marks.join("");
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

const response = await fetch("recursion.wasm?v=2");
const {instance} = await WebAssembly.instantiate(await response.arrayBuffer());
wasm = instance;
wasm.exports.recursion_reset();
draw();
