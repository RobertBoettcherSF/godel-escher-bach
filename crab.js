import "./shell.js?v=1";
import {getLang} from "./i18n.js?v=1";
import {play, playDuet} from "./sounds.js?v=1";

const STARTERS = {
  en: ["KAYAK", "RADAR", "TENET"],
  de: ["OTTO", "REITTIER", "LAGERREGAL"],
  es: ["SOMOS", "RECONOCER", "ANILINA"],
  fr: ["ÉTÉ", "KAYAK", "RESSASSER"]
};

const row = document.getElementById("letters");
const mark = document.getElementById("canon-mark");
const staff = document.getElementById("staff");
const another = document.getElementById("another");
const playButton = document.getElementById("play-canon");

let wasm = null;
let pair = 0;

const DEGREE = 12;
const UPPER_BOTTOM = 116;
const LOWER_BOTTOM = 268;

function read() {
  const exp = wasm.exports;
  const memory = exp.memory.buffer;
  const meta = new Int32Array(memory, exp.crab_meta() >>> 0, 6);
  return {
    tiles: meta[0],
    palindrome: meta[1] === 1,
    notes: meta[2],
    melodyCount: meta[4],
    melody: meta[5],
    letters: new Int32Array(memory, exp.crab_letters() >>> 0, 11),
    pitches: new Int32Array(memory, exp.crab_notes() >>> 0, 8),
    mirrors: new Int32Array(memory, exp.crab_mirrors() >>> 0, 8)
  };
}

function showPair() {
  const list = STARTERS[getLang()] || STARTERS.en;
  const text = list[pair % list.length];
  wasm.exports.crab_clear();
  for (let i = 0; i < text.length && i < 11; i += 1) {
    wasm.exports.crab_set_letter(i, text.codePointAt(i));
  }
  wasm.exports.crab_select_melody(pair);
  draw();
}

function glyph(code) {
  if (!code) return "·";
  return String.fromCodePoint(code);
}

function drawLetters(state) {
  const tiles = [];
  for (let i = 0; i < state.tiles; i += 1) {
    const code = state.letters[i];
    tiles.push(
      `<button type="button" class="letter${code ? "" : " is-gap"}" data-letter="${i}">${glyph(code)}</button>`
    );
  }
  row.innerHTML = tiles.join("");
  mark.textContent = state.palindrome ? "✓" : "✗";
  mark.className = state.palindrome ? "canon-mark yes" : "canon-mark no";
  mark.setAttribute("aria-label", state.palindrome ? "Yes" : "No");
}

function pitchY(pitch, bottom) {
  return bottom - pitch * DEGREE;
}

function noteHead(x, y, filled, index, mid) {
  const colour = filled ? "#241833" : "#c4492a";
  const up = y > mid;
  const tip = up ? y - 26 : y + 26;
  const top = Math.min(y, tip);
  const hit = index < 0 ? "" : ` data-note="${index}" tabindex="0" role="button"`;
  const fill = filled ? colour : "#fffdf8";
  return `<g class="note"${hit}>
    <rect x="${x - 20}" y="${top - 10}" width="40" height="${Math.abs(tip - y) + 20}" fill="transparent"/>
    <line x1="${x + 9}" y1="${y}" x2="${x + 9}" y2="${tip}" stroke="${colour}" stroke-width="2.4"/>
    <ellipse cx="${x}" cy="${y}" rx="11" ry="6.5" fill="${fill}" stroke="${colour}" stroke-width="2.4"/>
  </g>`;
}

function drawStaff(state) {
  const parts = [];
  for (const bottom of [UPPER_BOTTOM, LOWER_BOTTOM]) {
    for (let degree = 0; degree <= 8; degree += 2) {
      const y = bottom - degree * DEGREE;
      parts.push(`<line x1="64" y1="${y}" x2="824" y2="${y}" stroke="#cbbba6" stroke-width="2"/>`);
    }
  }
  parts.push(`<text x="24" y="${pitchY(4, UPPER_BOTTOM) + 8}" font-size="26" fill="#241833">→</text>`);
  parts.push(`<text x="24" y="${pitchY(4, LOWER_BOTTOM) + 8}" font-size="26" fill="#c4492a">←</text>`);
  for (let i = 0; i < state.notes; i += 1) {
    const x = 108 + i * 86;
    parts.push(noteHead(x, pitchY(state.pitches[i], UPPER_BOTTOM), true, i, pitchY(4, UPPER_BOTTOM)));
    parts.push(noteHead(x, pitchY(state.mirrors[i], LOWER_BOTTOM), false, -1, pitchY(4, LOWER_BOTTOM)));
  }
  staff.innerHTML = parts.join("");
}

function draw() {
  const state = read();
  drawLetters(state);
  drawStaff(state);
  window.GEB.state = {
    wasm: "ok",
    string: state.palindrome ? "yes" : "no",
    history: `${state.pitches[0]}`,
    error: "ok"
  };
  window.GEB.refreshDebug?.();
}

row.addEventListener("click", (event) => {
  const tile = event.target.closest("[data-letter]");
  if (!tile) return;
  wasm.exports.crab_cycle_letter(Number(tile.dataset.letter));
  play("pick");
  draw();
});

staff.addEventListener("click", (event) => {
  const note = event.target.closest("[data-note]");
  if (!note || note.dataset.note === "-1") return;
  wasm.exports.crab_cycle_note(Number(note.dataset.note));
  play("pick");
  draw();
});

another.addEventListener("click", () => {
  pair += 1;
  showPair();
  play("open");
});

function playCanon() {
  const state = read();
  const forward = [...state.pitches];
  const backward = [...state.mirrors];
  if (!playDuet(forward, backward)) play("no");
}

playButton.addEventListener("click", playCanon);

staff.addEventListener("keydown", (event) => {
  if (event.key !== "Enter" && event.key !== " ") return;
  const note = event.target.closest("[data-note]");
  if (!note) return;
  event.preventDefault();
  wasm.exports.crab_cycle_note(Number(note.dataset.note));
  play("pick");
  draw();
});

window.addEventListener("languagechange", () => {
  pair = 0;
  if (wasm) showPair();
});

const response = await fetch("crab.wasm?v=2");
const {instance} = await WebAssembly.instantiate(await response.arrayBuffer());
wasm = instance;
wasm.exports.crab_reset();
showPair();
