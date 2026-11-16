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
let starter = 0;

function read() {
  const exp = wasm.exports;
  const memory = exp.memory.buffer;
  const meta = new Int32Array(memory, exp.crab_meta() >>> 0, 4);
  return {
    tiles: meta[0],
    palindrome: meta[1] === 1,
    notes: meta[2],
    letters: new Int32Array(memory, exp.crab_letters() >>> 0, 11),
    pitches: new Int32Array(memory, exp.crab_notes() >>> 0, 8),
    mirrors: new Int32Array(memory, exp.crab_mirrors() >>> 0, 8)
  };
}

function loadStarter() {
  const lang = getLang();
  const list = STARTERS[lang] || STARTERS.en;
  const text = list[starter % list.length];
  wasm.exports.crab_clear();
  for (let i = 0; i < text.length && i < 11; i += 1) {
    wasm.exports.crab_set_letter(i, text.codePointAt(i));
  }
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

function noteHead(x, y, filled, index, mid) {
  const colour = filled ? "#241833" : "#c4492a";
  const up = y > mid;
  const tip = up ? y - 28 : y + 28;
  const top = Math.min(y, tip);
  const hit = index < 0 ? "" : ` data-note="${index}" tabindex="0" role="button"`;
  const fill = filled ? colour : "#fffdf8";
  return `<g class="note"${hit}>
    <rect x="${x - 22}" y="${top - 12}" width="44" height="${Math.abs(tip - y) + 24}" fill="transparent"/>
    <line x1="${x + 10}" y1="${y}" x2="${x + 10}" y2="${tip}" stroke="${colour}" stroke-width="2.5"/>
    <ellipse cx="${x}" cy="${y}" rx="12" ry="8.5" fill="${fill}" stroke="${colour}" stroke-width="2.5"/>
  </g>`;
}

function drawStaff(state) {
  const lines = [];
  for (let i = 0; i < 5; i += 1) {
    lines.push(`<line x1="56" y1="${54 + i * 16}" x2="840" y2="${54 + i * 16}" stroke="#cbbba6" stroke-width="2"/>`);
    lines.push(`<line x1="56" y1="${190 + i * 16}" x2="840" y2="${190 + i * 16}" stroke="#cbbba6" stroke-width="2"/>`);
  }
  lines.push(`<text x="18" y="96" font-size="26" fill="#241833">→</text>`);
  lines.push(`<text x="18" y="232" font-size="26" fill="#c4492a">←</text>`);
  const heads = [];
  for (let i = 0; i < state.notes; i += 1) {
    const x = 92 + i * 92;
    const forward = state.pitches[i];
    const back = state.mirrors[i];
    const yForward = 118 - forward * 16;
    const yBack = 254 - back * 16;
    if (forward >= 6) {
      heads.push(`<line x1="${x - 16}" y1="${yForward}" x2="${x + 16}" y2="${yForward}" stroke="#cbbba6" stroke-width="2"/>`);
    }
    if (back >= 6) {
      heads.push(`<line x1="${x - 16}" y1="${yBack}" x2="${x + 16}" y2="${yBack}" stroke="#cbbba6" stroke-width="2"/>`);
    }
    heads.push(noteHead(x, yForward, true, i, 86));
    heads.push(noteHead(x, yBack, false, -1, 222));
  }
  staff.innerHTML = lines.join("") + heads.join("");
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
  const list = STARTERS[getLang()] || STARTERS.en;
  starter = (starter + 1) % list.length;
  loadStarter();
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
  starter = 0;
  if (wasm) loadStarter();
});

const response = await fetch("crab.wasm?v=1");
const {instance} = await WebAssembly.instantiate(await response.arrayBuffer());
wasm = instance;
wasm.exports.crab_reset();
loadStarter();
