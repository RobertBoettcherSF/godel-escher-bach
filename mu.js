import "./shell.js?v=1";
import {t} from "./i18n.js?v=1";
import {play} from "./sounds.js?v=1";

const reducedMotion = () =>
  window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const wait = (ms) => new Promise((resolve) => window.setTimeout(resolve, ms));

let engine = null;
let wasmBytes = 0;
let wasmKey = "wasmLoading";
let fault = "";
let picking = 0;
let busy = false;

function textFrom(bytes, length) {
  let out = "";
  for (let i = 0; i < length; i += 1) out += String.fromCharCode(bytes[i]);
  return out;
}

function read() {
  const max = engine.miu_max_length();
  const histMax = engine.miu_max_history();
  const memory = engine.memory.buffer;
  const chars = new Uint8Array(memory, engine.miu_chars() >>> 0, max);
  const meta = new Int32Array(memory, engine.miu_meta() >>> 0, 8);
  const ready = new Int32Array(memory, engine.miu_ready() >>> 0, 4);
  const posCount = new Int32Array(memory, engine.miu_pos_count() >>> 0, 4);
  const positions = new Int32Array(memory, engine.miu_positions() >>> 0, 4 * max);
  const histLen = new Int32Array(memory, engine.miu_hist_len() >>> 0, histMax);
  const histChars = new Uint8Array(memory, engine.miu_hist_chars() >>> 0, histMax * max);
  const steps = [];
  for (let step = 0; step < meta[2]; step += 1) {
    const n = histLen[step];
    steps.push(textFrom(histChars.subarray(step * max, step * max + n), n));
  }
  return {
    string: textFrom(chars, meta[0]),
    length: meta[0],
    iCount: meta[1],
    history: meta[2],
    error: meta[3],
    ready,
    steps,
    spots(rule) {
      const base = (rule - 1) * max;
      const list = [];
      for (let i = 0; i < posCount[rule - 1]; i += 1) list.push(positions[base + i]);
      return list;
    }
  };
}

function publish(st) {
  window.GEB.state = {
    wasm: `${t(wasmKey)}${wasmBytes ? " · " + wasmBytes : ""}`,
    string: st ? st.string : "—",
    history: st ? String(st.history) : "—",
    error: fault || (st ? `${st.error} ${t("err" + st.error)}` : "—")
  };
  window.GEB.refreshDebug?.();
}

function render(pop) {
  if (!engine) {
    publish(null);
    return;
  }
  const st = read();
  publish(st);
  const row = document.getElementById("blocks");
  const spots = picking ? st.spots(picking) : [];
  row.replaceChildren();
  for (let i = 1; i <= st.length; i += 1) {
    const letter = st.string[i - 1];
    const node = document.createElement("button");
    node.type = "button";
    node.className = `block ${letter.toLowerCase()}`;
    node.textContent = letter;
    node.dataset.index = String(i);
    if (picking) {
      if (engine.miu_resolve(picking, i) !== 0) node.classList.add("in-span");
      if (spots.includes(i)) node.classList.add("spot");
      node.tabIndex = 0;
    } else {
      node.tabIndex = -1;
    }
    if (pop && i > pop.from && i <= pop.to) node.classList.add("pop");
    node.addEventListener("click", () => onBlock(i));
    row.appendChild(node);
  }
  row.setAttribute("aria-label", `${t("blocks")} ${st.string.split("").join(" ")}`);

  document.querySelectorAll(".rule").forEach((button) => {
    const rule = Number(button.dataset.rule);
    const ready = st.ready[rule - 1] === 1;
    button.classList.toggle("is-ready", ready);
    button.classList.toggle("is-picking", picking === rule);
    button.setAttribute("aria-disabled", String(!ready));
  });

  document.getElementById("icount").textContent = String(st.iCount);
  const dots = document.getElementById("idots");
  dots.replaceChildren();
  for (let i = 0; i < st.iCount; i += 1) {
    const dot = document.createElement("span");
    dot.className = "mini i";
    dot.textContent = "I";
    dots.appendChild(dot);
  }

  document.getElementById("pick").hidden = picking === 0;
  const undo = document.getElementById("undo");
  const canUndo = st.history > 1;
  undo.classList.toggle("is-dim", !canUndo);
  undo.setAttribute("aria-disabled", String(!canUndo));

  const trail = document.getElementById("trail");
  trail.replaceChildren();
  st.steps.forEach((step, index) => {
    if (index > 0) {
      const arrow = document.createElement("span");
      arrow.className = "arrow";
      arrow.setAttribute("aria-hidden", "true");
      arrow.textContent = "→";
      trail.appendChild(arrow);
    }
    const group = document.createElement("div");
    group.className = index === st.steps.length - 1 ? "step latest" : "step";
    for (const letter of step) {
      const mini = document.createElement("span");
      mini.className = `mini ${letter.toLowerCase()}`;
      mini.textContent = letter;
      group.appendChild(mini);
    }
    trail.appendChild(group);
  });
  window.requestAnimationFrame(() => {
    trail.scrollLeft = trail.scrollWidth;
  });

  const live = document.getElementById("live");
  if (live) live.textContent = st.string.split("").join(" ");
  const resting = document.getElementById("resting");
  if (resting) resting.hidden = true;
}

function changedSpan(before, after) {
  let prefix = 0;
  while (
    prefix < before.length &&
    prefix < after.length &&
    before[prefix] === after[prefix]
  ) {
    prefix += 1;
  }
  let suffix = 0;
  while (
    suffix < before.length - prefix &&
    suffix < after.length - prefix &&
    before[before.length - 1 - suffix] === after[after.length - 1 - suffix]
  ) {
    suffix += 1;
  }
  return {
    oldFrom: prefix,
    oldTo: before.length - suffix,
    newFrom: prefix,
    newTo: after.length - suffix
  };
}

async function commit(rule, pos) {
  if (busy || !engine) return;
  busy = true;
  picking = 0;
  const before = read().string;
  engine.miu_apply(rule, pos);
  const afterState = read();
  if (afterState.error !== 0) {
    play("no");
    busy = false;
    render();
    return;
  }
  const diff = changedSpan(before, afterState.string);
  if (!reducedMotion() && diff.oldTo > diff.oldFrom) {
    document.querySelectorAll("#blocks .block").forEach((node) => {
      const index = Number(node.dataset.index) - 1;
      if (index >= diff.oldFrom && index < diff.oldTo) node.classList.add("leave");
    });
    await wait(240);
  }
  play("apply", rule);
  render(diff.newTo > diff.newFrom ? {from: diff.newFrom, to: diff.newTo} : null);
  await wait(reducedMotion() ? 0 : 320);
  busy = false;
}

function onRule(rule) {
  if (busy || !engine) return;
  const st = read();
  if (st.ready[rule - 1] !== 1) {
    play("no");
    return;
  }
  const spots = st.spots(rule);
  if (spots.length > 1) {
    picking = picking === rule ? 0 : rule;
    play("pick");
    render();
    return;
  }
  commit(rule, spots.length === 1 ? spots[0] : 0);
}

function onBlock(index) {
  if (!picking || busy || !engine) return;
  const pos = engine.miu_resolve(picking, index);
  if (pos === 0) {
    play("no");
    return;
  }
  commit(picking, pos);
}

function showFailure(error) {
  wasmKey = "wasmFailed";
  fault = error?.message || String(error);
  publish(null);
  const resting = document.getElementById("resting");
  if (resting) resting.hidden = false;
  document.querySelectorAll(".rule").forEach((button) => {
    button.classList.remove("is-ready", "is-picking");
    button.setAttribute("aria-disabled", "true");
  });
}

async function boot() {
  publish(null);
  try {
    const response = await fetch("miu.wasm?v=1");
    if (!response.ok) throw new Error(`miu.wasm ${response.status}`);
    const bytes = await response.arrayBuffer();
    wasmBytes = bytes.byteLength;
    const {instance} = await WebAssembly.instantiate(bytes);
    engine = instance.exports;
    wasmKey = "wasmReady";
    engine.miu_reset();
    render();
  } catch (error) {
    showFailure(error);
  }
}

document.querySelectorAll(".rule").forEach((button) => {
  button.addEventListener("click", () => onRule(Number(button.dataset.rule)));
});
document.getElementById("undo").addEventListener("click", () => {
  if (busy || !engine) return;
  if (read().history <= 1) {
    play("no");
    return;
  }
  picking = 0;
  engine.miu_undo();
  play("undo");
  render();
});
document.getElementById("reset").addEventListener("click", () => {
  if (busy || !engine) return;
  picking = 0;
  engine.miu_reset();
  play("reset");
  render();
});
document.getElementById("hint").addEventListener("click", () => {
  const button = document.getElementById("hint");
  const body = document.getElementById("hint-body");
  const open = button.getAttribute("aria-expanded") === "true";
  button.setAttribute("aria-expanded", String(!open));
  body.hidden = open;
  play("hint");
});
window.addEventListener("languagechange", () => {
  if (engine) render();
  else publish(null);
});
window.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && picking && engine) {
    picking = 0;
    render();
  }
});
boot();
