import "./shell.js?v=1";
import {t} from "./i18n.js?v=1";
import {play, playFall, playRise} from "./sounds.js?v=1";

const FRAME = ["#3d5a80", "#c45c44", "#d4a017", "#1f7a64", "#6d597a", "#241833"];
const WALL = ["#d7ebf7", "#fde7dc", "#fff4d4", "#d9f3ea", "#efe4f7", "#f6f1ea"];
const FRAME_X = 56;
const FRAME_Y = 8;
const FRAME_S = 38;
const FRAME_BAND = 3.2;
const INNER_X = FRAME_X + FRAME_BAND;
const INNER_Y = FRAME_Y + FRAME_BAND;
const INNER_S = FRAME_S - FRAME_BAND * 2;
const SUN = `<g stroke="#e39b12" stroke-width="1.6" stroke-linecap="round" fill="none">
  <line x1="14" y1="3.4" x2="14" y2="6.4"/>
  <line x1="14" y1="21.6" x2="14" y2="24.6"/>
  <line x1="3.4" y1="14" x2="6.4" y2="14"/>
  <line x1="21.6" y1="14" x2="24.6" y2="14"/>
  <line x1="6.6" y1="6.6" x2="8.6" y2="8.6"/>
  <line x1="19.4" y1="19.4" x2="21.4" y2="21.4"/>
  <line x1="21.4" y1="6.6" x2="19.4" y2="8.6"/>
  <line x1="8.6" y1="19.4" x2="6.6" y2="21.4"/>
  <circle cx="14" cy="14" r="6.4" fill="#f6b429" stroke="none"/>
</g>`;
const FLOWER = `<g>
  <line x1="28" y1="58" x2="28" y2="80" stroke="#2f7a40" stroke-width="2.8" stroke-linecap="butt"/>
  <ellipse cx="20" cy="66" rx="8" ry="3.4" transform="rotate(-42 20 66)" fill="#3e9a52"/>
  <circle cx="16" cy="50" r="9" fill="#e23d4a"/>
  <circle cx="40" cy="50" r="9" fill="#e23d4a"/>
  <circle cx="20" cy="38" r="9" fill="#e23d4a"/>
  <circle cx="36" cy="38" r="9" fill="#e23d4a"/>
  <circle cx="28" cy="46" r="9" fill="#d62839"/>
  <circle cx="28" cy="46" r="4.2" fill="#f0a202"/>
</g>`;

const frames = document.getElementById("frames");
const stack = document.getElementById("stack");
const tree = document.getElementById("tree");
const rabbits = document.getElementById("rabbits");
const treeN = document.getElementById("tree-n");
const treeGrow = document.getElementById("tree-grow");
const treeBack = document.getElementById("tree-back");
const levelN = document.getElementById("level-n");
const rabbitN = document.getElementById("rabbit-n");
const deeper = document.getElementById("deeper");
const back = document.getElementById("back");
const next = document.getElementById("next");

let wasm = null;

function placesText(places, which, len) {
  let out = "";
  const start = which * 256;
  for (let i = len - 1; i >= 0; i -= 1) out += String(places[start + i]);
  return out || "0";
}

function read() {
  const exp = wasm.exports;
  const memory = exp.memory.buffer;
  const meta = new Int32Array(memory, exp.recursion_meta() >>> 0, 14);
  const segments = meta[3];
  const dots = meta[8];
  const valueLen = meta[5];
  const olderLen = meta[6];
  const newerLen = meta[7];
  const places = new Int32Array(memory, exp.recursion_digits() >>> 0, 256 * 3);
  return {
    depth: meta[0],
    tree: meta[2],
    visible: meta[10],
    sig: meta[12],
    segments,
    terms: meta[4],
    valueLen,
    olderLen,
    newerLen,
    unit: meta[11],
    valueText: placesText(places, 0, valueLen),
    olderText: placesText(places, 1, olderLen),
    newerText: placesText(places, 2, newerLen),
    dots,
    error: meta[9],
    seg: new Int32Array(memory, exp.recursion_segments() >>> 0, Math.max(segments, 1) * 5),
    dot: new Int32Array(memory, exp.recursion_dots() >>> 0, Math.max(dots, 1) * 5)
  };
}

function sceneInner(level, total) {
  const wall = WALL[(level - 1) % WALL.length];
  const frame = FRAME[(level - 1) % FRAME.length];
  const picture = level >= total
    ? `<rect x="${INNER_X}" y="${INNER_Y}" width="${INNER_S}" height="${INNER_S}" fill="${WALL[level % WALL.length]}"/>`
    : `<svg data-level="${level + 1}" x="${INNER_X}" y="${INNER_Y}" width="${INNER_S}" height="${INNER_S}" viewBox="0 0 100 100" preserveAspectRatio="none">${sceneInner(level + 1, total)}</svg>`;
  return `<rect width="100" height="100" fill="${wall}"/>
    <rect x="0" y="80" width="100" height="20" fill="#e4c27a"/>
    ${SUN}${FLOWER}
    <rect x="8" y="80" width="84" height="1.8" fill="#8a5a28"/>
    <rect x="${FRAME_X}" y="${FRAME_Y}" width="${FRAME_S}" height="${FRAME_S}" fill="${frame}"/>
    ${picture}`;
}

const NESTED = 4;
let shownDepth = 0;
let sliding = false;

function paintScene(depth) {
  const total = depth + NESTED;
  frames.innerHTML = `<div class="story-stage"><div class="scene-cam"><svg class="scene-root" data-level="${depth}" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">${sceneInner(depth, total)}</svg></div></div>`;
  shownDepth = depth;
}

function paintCounter(depth) {
  const start = Math.max(1, depth - 4);
  stack.replaceChildren();
  for (let level = start; level <= depth; level += 1) {
    const item = document.createElement("li");
    item.style.background = FRAME[(level - 1) % FRAME.length];
    stack.append(item);
  }
  levelN.textContent = String(depth);
}

function motionOff() {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

function zoomTransform(depth) {
  const cam = frames.querySelector(".scene-cam");
  const scene = frames.querySelector(`svg[data-level="${depth}"]`);
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

function remember(state) {
  paintCounter(state.depth);
  back.classList.toggle("is-dim", state.depth <= 1);
  back.setAttribute("aria-disabled", state.depth <= 1 ? "true" : "false");
  window.GEB.state = {
    wasm: "ok",
    string: `${state.depth} / ${state.tree} / ${state.valueText}`,
    history: `${state.segments} branches`,
    error: t("err" + state.error)
  };
  window.GEB.refreshDebug?.();
}

function drawFrames(state) {
  remember(state);
  if (!sliding && shownDepth !== state.depth) paintScene(state.depth);
}

function drawTree(state) {
  const visible = state.visible;
  const paths = [];
  const leaves = [];
  const channel = (from, to, mix) => Math.round(from + (to - from) * mix);
  for (let i = 0; i < state.segments; i += 1) {
    const base = i * 5;
    const level = state.seg[base + 4];
    const x1 = state.seg[base];
    const y1 = 1000 - state.seg[base + 1];
    const x2 = state.seg[base + 2];
    const y2 = 1000 - state.seg[base + 3];
    if (level < 0) {
      leaves.push(`<circle cx="${x2}" cy="${y2}" r="2.4" fill="#8ed18a"/>`);
      continue;
    }
    if (!paths[level]) paths[level] = [];
    paths[level].push(`M${x1} ${y1}L${x2} ${y2}`);
  }
  const parts = [];
  for (let level = 0; level < paths.length; level += 1) {
    if (!paths[level]) continue;
    const mix = visible === 0 ? 0 : level / visible;
    const colour = `rgb(${channel(107, 47, mix)} ${channel(62, 122, mix)} ${channel(38, 64, mix)})`;
    const width = Math.max(2.2, 36 * 0.66 ** level).toFixed(1);
    parts.push(`<path d="${paths[level].join("")}" fill="none" stroke="${colour}" stroke-width="${width}" stroke-linecap="round"/>`);
  }
  tree.innerHTML = parts.join("") + leaves.join("");
  treeN.textContent = String(state.tree);
  treeBack.classList.toggle("is-dim", state.tree <= 0);
  treeBack.setAttribute("aria-disabled", state.tree <= 0 ? "true" : "false");
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
  const fit = (labelText, width, max) => Math.max(
    12,
    Math.min(max, Math.floor((width / Math.max(labelText.length, 1)) * 1.55))
  );
  const label = (dots, labelText, size) => {
    if (!dots.length) return;
    const box = pileBounds(dots);
    marks.push(`<text x="${box.cx}" y="${box.maxY + size + 10}" text-anchor="middle" font-size="${size}" font-weight="700" fill="#241833">${labelText}</text>`);
  };
  if (state.terms >= 3) {
    const left = pileBounds(piles[0]);
    const mid = pileBounds(piles[1]);
    const right = pileBounds(piles[2]);
    label(piles[0], state.olderText, fit(state.olderText, left.maxX - left.minX, 34));
    label(piles[1], state.newerText, fit(state.newerText, mid.maxX - mid.minX, 34));
    label(piles[2], state.valueText, fit(state.valueText, Math.max(right.maxX - right.minX, 180), 42));
    const rowY = (right.minY + right.maxY) / 2;
    const plusX = (left.maxX + mid.minX) / 2;
    marks.push(`<text x="${plusX}" y="${rowY}" text-anchor="middle" dominant-baseline="middle" font-size="48" font-weight="700" fill="#241833">+</text>`);
    const x1 = mid.maxX + 18;
    const x2 = right.minX - 16;
    marks.push(`<line x1="${x1}" y1="${rowY}" x2="${x2}" y2="${rowY}" stroke="#241833" stroke-width="7" stroke-linecap="round"/>`);
    marks.push(`<polygon points="${x2},${rowY} ${x2 - 18},${rowY - 12} ${x2 - 18},${rowY + 12}" fill="#241833"/>`);
  } else {
    label(piles[2], state.valueText, 56);
  }
  if (state.unit > 0) {
    const sup = "⁰¹²³⁴⁵⁶⁷⁸⁹";
    const legend = state.unit <= 3
      ? `● = 1${"0".repeat(state.unit)}`
      : `● = 10${String(state.unit).replace(/\d/g, (digit) => sup[digit])}`;
    marks.push(`<text x="500" y="78" text-anchor="middle" font-size="32" font-weight="700" fill="#241833">${legend}</text>`);
  }
  rabbits.innerHTML = marks.join("");
  rabbitN.textContent = state.valueText;
}

function show(state) {
  drawFrames(state);
  drawTree(state);
  drawRabbits(state);
}

function draw() {
  show(read());
}

function stepIn() {
  if (sliding) return;
  const before = read().depth;
  wasm.exports.recursion_deeper();
  const state = read();
  if (!(state.error === 0 && state.depth > before)) {
    play("no");
    remember(state);
    return;
  }
  playRise(state.depth);
  remember(state);
  const cam = frames.querySelector(".scene-cam");
  const inner = frames.querySelector(`svg[data-level="${state.depth}"]`);
  if (motionOff() || !cam || !inner) {
    paintScene(state.depth);
    return;
  }
  sliding = true;
  const next = zoomTransform(state.depth);
  cam.style.transition = "none";
  cam.style.transform = "none";
  cam.getBoundingClientRect();
  cam.style.transition = "transform 0.55s ease";
  cam.style.transform = next;
  const done = (event) => {
    if (event && event.target !== cam) return;
    cam.removeEventListener("transitionend", done);
    window.clearTimeout(slideTimer);
    paintScene(state.depth);
    sliding = false;
  };
  const slideTimer = window.setTimeout(done, 700);
  cam.addEventListener("transitionend", done);
}

function stepOut() {
  if (sliding) return;
  const before = read().depth;
  wasm.exports.recursion_back();
  const state = read();
  if (!(state.error === 0 && state.depth < before)) {
    play("no");
    remember(state);
    return;
  }
  playFall(before);
  remember(state);
  if (motionOff()) {
    paintScene(state.depth);
    return;
  }
  paintScene(state.depth);
  const cam = frames.querySelector(".scene-cam");
  const zoomed = zoomTransform(before);
  sliding = true;
  cam.style.transition = "none";
  cam.style.transform = zoomed;
  cam.getBoundingClientRect();
  cam.style.transition = "transform 0.55s ease";
  cam.style.transform = "none";
  const done = (event) => {
    if (event && event.target !== cam) return;
    cam.removeEventListener("transitionend", done);
    window.clearTimeout(slideTimer);
    cam.style.transition = "none";
    cam.style.transform = "none";
    sliding = false;
  };
  const slideTimer = window.setTimeout(done, 700);
  cam.addEventListener("transitionend", done);
}

deeper.addEventListener("click", stepIn);
frames.addEventListener("click", stepIn);
frames.addEventListener("keydown", (event) => {
  if (event.key !== "Enter" && event.key !== " ") return;
  event.preventDefault();
  stepIn();
});

back.addEventListener("click", stepOut);

const treeHint = document.getElementById("tree-hint");
const treeReset = document.getElementById("tree-reset");

function showTiny(on) {
  treeHint.hidden = !on;
  treeReset.classList.toggle("is-hot", on);
}

function growTree() {
  const before = read();
  wasm.exports.recursion_tree(before.tree + 1);
  const state = read();
  if (state.tree <= before.tree) {
    play("no");
    drawTree(state);
    return;
  }
  playRise(state.tree);
  drawTree(state);
  showTiny(state.segments === before.segments && state.sig === before.sig);
}

function backTree() {
  const before = read();
  if (before.tree <= 0) {
    play("no");
    return;
  }
  wasm.exports.recursion_tree(before.tree - 1);
  playFall(before.tree);
  drawTree(read());
  showTiny(false);
}

function stepRabbit() {
  wasm.exports.recursion_next();
  const state = read();
  if (state.error === 0) playRise(state.terms);
  else play("no");
  drawRabbits(state);
  window.GEB.state.string = `${state.depth} / ${state.tree} / ${state.valueText}`;
  window.GEB.refreshDebug?.();
}

treeGrow.addEventListener("click", growTree);
tree.addEventListener("click", growTree);
tree.addEventListener("keydown", (event) => {
  if (event.key !== "Enter" && event.key !== " ") return;
  event.preventDefault();
  growTree();
});
treeBack.addEventListener("click", backTree);
treeReset.addEventListener("click", () => {
  wasm.exports.recursion_tree(0);
  play("reset");
  drawTree(read());
  showTiny(false);
});

next.addEventListener("click", stepRabbit);
rabbits.addEventListener("click", stepRabbit);
rabbits.addEventListener("keydown", (event) => {
  if (event.key !== "Enter" && event.key !== " ") return;
  event.preventDefault();
  stepRabbit();
});

window.addEventListener("resize", () => {
  if (!wasm || sliding) return;
  const cam = frames.querySelector(".scene-cam");
  if (!cam) return;
  cam.style.transition = "none";
  cam.style.transform = "none";
});

document.getElementById("rabbit-reset").addEventListener("click", () => {
  wasm.exports.recursion_rabbits_reset();
  play("reset");
  draw();
});

const response = await fetch("recursion.wasm?v=7");
const {instance} = await WebAssembly.instantiate(await response.arrayBuffer());
wasm = instance;
wasm.exports.recursion_reset();
draw();
