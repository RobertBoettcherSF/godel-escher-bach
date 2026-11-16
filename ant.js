import "./shell.js?v=1";
import {t} from "./i18n.js?v=1";
import {armAudio, isMuted, play, silenceTones, toneAt} from "./sounds.js?v=1";

const canvas = document.getElementById("colony");
const zoom = document.getElementById("zoom");
const zoomNow = document.getElementById("zoom-now");
const fugue = document.getElementById("fugue");
const playButton = document.getElementById("play-fugue");
const ctx = canvas.getContext("2d");
const motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");

const voiceColours = ["#241833", "#2c6bed", "#c4492a", "#3f8f5b"];
const zoomKeys = ["antNear", "antGroups", "antFar"];

let wasm = null;
let antTimer = 0;
let playing = false;
let playOrigin = 0;
let heardBeat = -1;
let playFrame = 0;

function read() {
  const exp = wasm.exports;
  const memory = exp.memory.buffer;
  const meta = new Int32Array(memory, exp.ant_meta() >>> 0, 18);
  const count = meta[0];
  const width = meta[1];
  const height = meta[2];
  const cells = width * height;
  const clusters = meta[8];
  const voices = meta[9];
  const motifN = meta[10];
  return {
    count,
    width,
    height,
    trailMax: meta[3],
    nestX: meta[4],
    nestY: meta[5],
    food: meta[6],
    steps: meta[7],
    clusters,
    voices,
    motifN,
    loopN: meta[11],
    beat: meta[12],
    stepMs: meta[13],
    symX: meta[14],
    symY: meta[15],
    symRX: meta[16],
    symRY: meta[17],
    x: new Int32Array(memory, exp.ant_x() >>> 0, count),
    y: new Int32Array(memory, exp.ant_y() >>> 0, count),
    carry: new Int32Array(memory, exp.ant_carry() >>> 0, count),
    trail: new Int32Array(memory, exp.ant_trail() >>> 0, cells),
    meals: new Int32Array(memory, exp.ant_food() >>> 0, cells),
    group: new Int32Array(memory, exp.ant_cluster() >>> 0, clusters),
    sumX: new Int32Array(memory, exp.ant_sum_x() >>> 0, clusters),
    sumY: new Int32Array(memory, exp.ant_sum_y() >>> 0, clusters),
    motif: new Int32Array(memory, exp.ant_motif() >>> 0, motifN),
    voice: new Int32Array(memory, exp.ant_voice() >>> 0, voices * 3)
  };
}

function cellOf(state, px, py) {
  const rect = canvas.getBoundingClientRect();
  const x = Math.floor(((px - rect.left) / rect.width) * state.width);
  const y = Math.floor(((py - rect.top) / rect.height) * state.height);
  return {
    x: Math.max(0, Math.min(state.width - 1, x)),
    y: Math.max(0, Math.min(state.height - 1, y))
  };
}

function drawColony(state) {
  const w = canvas.width;
  const h = canvas.height;
  const cw = w / state.width;
  const ch = h / state.height;
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = "#fffdf8";
  ctx.fillRect(0, 0, w, h);

  for (let i = 0; i < state.trail.length; i += 1) {
    const strength = state.trail[i];
    if (strength <= 0) continue;
    const x = i % state.width;
    const y = Math.floor(i / state.width);
    ctx.fillStyle = `rgba(44, 107, 237, ${0.08 + (strength / state.trailMax) * 0.55})`;
    ctx.fillRect(x * cw, y * ch, cw + 0.5, ch + 0.5);
  }

  for (let i = 0; i < state.meals.length; i += 1) {
    if (state.meals[i] <= 0) continue;
    const x = i % state.width;
    const y = Math.floor(i / state.width);
    ctx.fillStyle = "#f0a202";
    ctx.beginPath();
    ctx.arc((x + 0.5) * cw, (y + 0.5) * ch, Math.min(cw, ch) * 0.28, 0, Math.PI * 2);
    ctx.fill();
  }

  ctx.fillStyle = "#8a3b1a";
  ctx.fillRect(state.nestX * cw + cw * 0.2, state.nestY * ch + ch * 0.2, cw * 0.6, ch * 0.6);

  const level = Number(zoom.value);
  if (level === 0) {
    for (let i = 0; i < state.count; i += 1) {
      const px = (state.x[i] + 0.5) * cw;
      const py = (state.y[i] + 0.5) * ch;
      ctx.fillStyle = state.carry[i] ? "#c4492a" : "#241833";
      ctx.beginPath();
      ctx.ellipse(px, py, cw * 0.28, ch * 0.18, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(px + cw * 0.16, py - ch * 0.08, cw * 0.08, 0, Math.PI * 2);
      ctx.fill();
    }
  } else if (level === 1) {
    for (let id = 0; id < state.clusters; id += 1) {
      const n = state.group[id];
      if (n <= 0) continue;
      const px = ((state.sumX[id] / n) + 0.5) * cw;
      const py = ((state.sumY[id] / n) + 0.5) * ch;
      let radius = cw * (0.55 + Math.sqrt(n) * 0.2);
      radius = Math.max(cw * 0.45, Math.min(radius, px - 4, py - 4, w - px - 4, h - py - 4));
      ctx.fillStyle = "rgba(36, 24, 51, 0.28)";
      ctx.beginPath();
      ctx.arc(px, py, radius, 0, Math.PI * 2);
      ctx.fill();
    }
  } else {
    const px = (state.symX + 0.5) * cw;
    const py = (state.symY + 0.5) * ch;
    const rx = Math.max(cw * 1.4, Math.sqrt(state.symRX) * cw * 0.85);
    const ry = Math.max(ch * 1.1, Math.sqrt(state.symRY) * ch * 0.85);
    ctx.fillStyle = "rgba(36, 24, 51, 0.88)";
    ctx.beginPath();
    ctx.ellipse(px, py, rx, ry, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#fff6ea";
    ctx.beginPath();
    ctx.arc(px - rx * 0.25, py - ry * 0.1, Math.min(rx, ry) * 0.16, 0, Math.PI * 2);
    ctx.arc(px + rx * 0.25, py - ry * 0.1, Math.min(rx, ry) * 0.16, 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawFugue(state) {
  const rows = [];
  for (let v = 0; v < state.voices; v += 1) {
    const active = state.voice[v * 3] === 1;
    const note = state.voice[v * 3 + 1];
    const dots = [];
    for (let n = 0; n < state.motifN; n += 1) {
      const on = active && note === n ? " is-on" : "";
      dots.push(`<span class="fugue-note${on}" style="--voice:${voiceColours[v]}">${state.motif[n] + 1}</span>`);
    }
    rows.push(
      `<div class="fugue-row${active ? " is-in" : ""}">
        <span class="fugue-voice" style="background:${voiceColours[v]}"></span>
        ${dots.join("")}
      </div>`
    );
  }
  fugue.innerHTML = rows.join("");
}

function draw() {
  const state = read();
  drawColony(state);
  drawFugue(state);
  window.GEB.state = {
    wasm: "ok",
    string: `${state.steps}`,
    history: `${state.food}`,
    error: "ok"
  };
  window.GEB.refreshDebug?.();
}

function colonyGap() {
  return motionQuery.matches ? 900 : 150;
}

function startAnts() {
  if (antTimer) clearInterval(antTimer);
  antTimer = setInterval(() => {
    wasm.exports.ant_step();
    draw();
  }, colonyGap());
}

function soundBeat(state) {
  for (let v = 0; v < state.voices; v += 1) {
    const pitch = state.voice[v * 3 + 2];
    if (pitch >= 0) toneAt(pitch, v % 2);
  }
}

function setPlayLabel(on) {
  const span = playButton.querySelector("[data-i18n]");
  const key = on ? "canonStop" : "play";
  if (span) {
    span.dataset.i18n = key;
    span.textContent = t(key);
  }
  playButton.setAttribute("aria-pressed", String(on));
}

function stopFugue() {
  playing = false;
  heardBeat = -1;
  if (playFrame) cancelAnimationFrame(playFrame);
  playFrame = 0;
  silenceTones();
  if (wasm) {
    wasm.exports.ant_set_beat(-1);
    draw();
  }
  setPlayLabel(false);
}

function playLoop() {
  if (!playing) return;
  const step = (read().stepMs || 420) / 1000;
  const beat = Math.floor((performance.now() - playOrigin) / 1000 / step);
  if (beat !== heardBeat) {
    heardBeat = beat;
    wasm.exports.ant_set_beat(beat);
    const state = read();
    soundBeat(state);
    drawFugue(state);
  }
  playFrame = requestAnimationFrame(playLoop);
}

function startFugue() {
  if (!armAudio()) {
    play("no");
    return;
  }
  playing = true;
  playOrigin = performance.now();
  heardBeat = -1;
  setPlayLabel(true);
  playLoop();
}

canvas.addEventListener("pointerdown", (event) => {
  const state = read();
  const cell = cellOf(state, event.clientX, event.clientY);
  wasm.exports.ant_drop(cell.x, cell.y);
  wasm.exports.ant_step();
  draw();
});

zoom.addEventListener("input", () => {
  const key = zoomKeys[Number(zoom.value)] || "antNear";
  zoomNow.dataset.i18n = key;
  zoomNow.textContent = t(key);
  draw();
});

playButton.addEventListener("click", () => {
  if (playing) stopFugue();
  else startFugue();
});

window.addEventListener("soundchange", () => {
  if (isMuted()) stopFugue();
});

document.addEventListener("visibilitychange", () => {
  if (document.hidden) {
    stopFugue();
    if (antTimer) clearInterval(antTimer);
    antTimer = 0;
  } else if (wasm && !antTimer) {
    startAnts();
  }
});

motionQuery.addEventListener("change", () => {
  if (wasm) startAnts();
});

const response = await fetch("ant.wasm?v=1");
const {instance} = await WebAssembly.instantiate(await response.arrayBuffer());
wasm = instance;
wasm.exports.ant_reset();
draw();
startAnts();
