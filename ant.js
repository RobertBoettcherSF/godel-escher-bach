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
  const meta = new Int32Array(memory, exp.ant_meta() >>> 0, 19);
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
    scale: meta[18] || 256,
    x: new Int32Array(memory, exp.ant_x() >>> 0, count),
    y: new Int32Array(memory, exp.ant_y() >>> 0, count),
    head: new Int32Array(memory, exp.ant_head() >>> 0, count),
    carry: new Int32Array(memory, exp.ant_carry() >>> 0, count),
    trail: new Int32Array(memory, exp.ant_trail() >>> 0, cells),
    meals: new Int32Array(memory, exp.ant_food() >>> 0, cells),
    group: new Int32Array(memory, exp.ant_cluster() >>> 0, clusters),
    sumX: new Int32Array(memory, exp.ant_sum_x() >>> 0, clusters),
    sumY: new Int32Array(memory, exp.ant_sum_y() >>> 0, clusters),
    motif: new Int32Array(memory, exp.ant_motif() >>> 0, motifN),
    voice: new Int32Array(memory, exp.ant_voice() >>> 0, voices * 3),
    outline: new Int32Array(memory, exp.ant_outline() >>> 0, 16)
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

function drawHaze(state, cw, ch) {
  for (let i = 0; i < state.trail.length; i += 1) {
    const strength = state.trail[i];
    if (strength <= 0) continue;
    const x = i % state.width;
    const y = Math.floor(i / state.width);
    ctx.fillStyle = `rgba(176, 98, 32, ${0.12 + (strength / state.trailMax) * 0.62})`;
    ctx.beginPath();
    ctx.arc((x + 0.5) * cw, (y + 0.5) * ch, Math.max(cw, ch) * 0.62, 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawNest(cx, cy, s) {
  ctx.fillStyle = "#c4a574";
  ctx.beginPath();
  ctx.ellipse(cx, cy, s * 1.35, s * 0.85, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#5c3a1e";
  ctx.beginPath();
  ctx.ellipse(cx, cy + s * 0.08, s * 0.42, s * 0.3, 0, 0, Math.PI * 2);
  ctx.fill();
}

function drawCrumbs(cx, cy, s) {
  ctx.fillStyle = "#6f8f3a";
  ctx.beginPath();
    ctx.ellipse(cx, cy, s * 0.85, s * 0.4, -0.7, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#d98a2b";
  [[-0.38, 0.28], [0.34, 0.22], [0.02, -0.36]].forEach(([ox, oy]) => {
    ctx.beginPath();
    ctx.arc(cx + ox * s, cy + oy * s, s * 0.13, 0, Math.PI * 2);
    ctx.fill();
  });
}

function drawAnt(px, py, heading, carry, s) {
  const ang = heading * Math.PI / 4;
  const ux = Math.cos(ang);
  const uy = Math.sin(ang);
  const vx = -uy;
  const vy = ux;
  ctx.strokeStyle = "#241833";
  ctx.lineWidth = Math.max(1, s * 0.07);
  const mx = px - ux * s * 0.05;
  const my = py - uy * s * 0.05;
  [-1, 1].forEach((side) => {
    [-0.35, 0.12, 0.5].forEach((t) => {
      ctx.beginPath();
      ctx.moveTo(mx + ux * s * t, my + uy * s * t);
      ctx.lineTo(mx + ux * s * t + vx * s * 0.48 * side, my + uy * s * t + vy * s * 0.48 * side);
      ctx.stroke();
    });
  });
  ctx.fillStyle = "#241833";
  [[-0.5, 0.34], [0.05, 0.26], [0.55, 0.2]].forEach(([t, r]) => {
    ctx.beginPath();
    ctx.ellipse(px + ux * s * t, py + uy * s * t, s * r, s * r * 0.7, ang, 0, Math.PI * 2);
    ctx.fill();
  });
  if (carry) {
    ctx.fillStyle = "#e0a040";
    ctx.beginPath();
    ctx.arc(px + ux * s * 0.78, py + uy * s * 0.78, s * 0.14, 0, Math.PI * 2);
    ctx.fill();
  }
}

function trailHull(state) {
  const pts = [];
  for (let i = 0; i < state.trail.length; i += 1) {
    if (state.trail[i] < 4) continue;
    pts.push([i % state.width + 0.5, Math.floor(i / state.width) + 0.5]);
  }
  pts.sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  if (pts.length < 3) return pts;
  const cross = (o, a, b) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
  const lower = [];
  pts.forEach((p) => {
    while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], p) <= 0) lower.pop();
    lower.push(p);
  });
  const upper = [];
  for (let i = pts.length - 1; i >= 0; i -= 1) {
    const p = pts[i];
    while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], p) <= 0) upper.pop();
    upper.push(p);
  }
  lower.pop();
  upper.pop();
  return lower.concat(upper);
}

function drawOutline(state, cw, ch) {
  const hull = trailHull(state);
  let cx = (state.nestX + 0.5) * cw;
  let cy = (state.nestY + 0.5) * ch;
  const points = [];
  if (hull.length >= 3) {
    let sx = 0;
    let sy = 0;
    hull.forEach(([x, y]) => {
      sx += x;
      sy += y;
    });
    cx = (sx / hull.length) * cw;
    cy = (sy / hull.length) * ch;
    hull.forEach(([x, y]) => {
      const px = x * cw;
      const py = y * ch;
      const dx = px - cx;
      const dy = py - cy;
      const len = Math.hypot(dx, dy) || 1;
      const pad = Math.min(cw, ch) * 0.85;
      points.push([px + (dx / len) * pad, py + (dy / len) * pad]);
    });
  } else {
    for (let i = 0; i < 8; i += 1) {
      const ang = (i / 8) * Math.PI * 2;
      points.push([cx + Math.cos(ang) * cw * 1.4, cy + Math.sin(ang) * ch * 1.4]);
    }
  }
  ctx.beginPath();
  points.forEach(([x, y], i) => {
    const next = points[(i + 1) % points.length];
    const midX = (x + next[0]) / 2;
    const midY = (y + next[1]) / 2;
    if (i === 0) ctx.moveTo(midX, midY);
    ctx.quadraticCurveTo(x, y, midX, midY);
  });
  ctx.closePath();
  ctx.fillStyle = "rgba(120, 64, 28, 0.55)";
  ctx.strokeStyle = "#5c3a1e";
  ctx.lineWidth = 3;
  ctx.fill();
  ctx.stroke();
}

function drawColony(state) {
  const w = canvas.width;
  const h = canvas.height;
  const cw = w / state.width;
  const ch = h / state.height;
  const level = Number(zoom.value);
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = "#fffdf8";
  ctx.fillRect(0, 0, w, h);

  if (level < 2) drawHaze(state, cw, ch);

  if (level === 0) {
    const body = Math.min(cw, ch) * 0.52;
    for (let i = 0; i < state.count; i += 1) {
      drawAnt(
        (state.x[i] / state.scale) * cw,
        (state.y[i] / state.scale) * ch,
        state.head[i],
        state.carry[i] === 1,
        body
      );
    }
  } else if (level === 1) {
    for (let id = 0; id < state.clusters; id += 1) {
      const n = state.group[id];
      if (n <= 0) continue;
      const px = (state.sumX[id] / n / state.scale) * cw;
      const py = (state.sumY[id] / n / state.scale) * ch;
      let radius = cw * (0.2 + n * 0.16);
      radius = Math.max(4, Math.min(radius, px - 2, py - 2, w - px - 2, h - py - 2));
      ctx.fillStyle = "rgba(36, 24, 51, 0.22)";
      ctx.beginPath();
      ctx.arc(px, py, radius, 0, Math.PI * 2);
      ctx.fill();
    }
  } else {
    drawOutline(state, cw, ch);
  }

  if (level < 2) {
    const nestS = Math.min(cw, ch);
    drawNest((state.nestX + 0.5) * cw, (state.nestY + 0.5) * ch, nestS);
    for (let i = 0; i < state.meals.length; i += 1) {
      if (state.meals[i] <= 0) continue;
      const x = i % state.width;
      const y = Math.floor(i / state.width);
      drawCrumbs((x + 0.5) * cw, (y + 0.5) * ch, Math.min(cw, ch) * 1.15);
    }
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
  return motionQuery.matches ? 900 : 50;
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

const response = await fetch("ant.wasm?v=2");
const {instance} = await WebAssembly.instantiate(await response.arrayBuffer());
wasm = instance;
wasm.exports.ant_reset();
draw();
startAnts();
