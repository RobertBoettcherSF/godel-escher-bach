import "./shell.js?v=1";
import {t} from "./i18n.js?v=1";
import {play, playChime} from "./sounds.js?v=1";

const DARK = "#211a33";
const CREAM = "#fdf5e8";
const MIN_X = -11.8;
const MAX_X = 14.25;
const MIN_Y = -1.2;
const MAX_Y = 9.2;

const svg = document.getElementById("picture");
const who = document.getElementById("who");
const slider = document.getElementById("birds");
const world = document.createElementNS("http://www.w3.org/2000/svg", "g");
const eyes = document.createElementNS("http://www.w3.org/2000/svg", "g");
const birds = [];

let wasm = null;
let built = 0;

function read() {
  const exp = wasm.exports;
  const shapes = exp.figure_shapes();
  const memory = exp.memory.buffer;
  const meta = new Int32Array(memory, exp.figure_meta() >>> 0, 9);
  const points = meta[6];
  const eyeCount = meta[7];
  return {
    shapes,
    morph: meta[0] === 1,
    uniform: meta[1],
    highlight: meta[2],
    taps: meta[3],
    error: meta[4],
    points,
    eyes: eyeCount,
    last: meta[8],
    kind: new Int32Array(memory, exp.figure_kind() >>> 0, shapes),
    xy: new Float32Array(memory, exp.figure_outline_xy() >>> 0, shapes * points * 2),
    eyeXY: new Float32Array(memory, exp.figure_eye_xy() >>> 0, Math.max(eyeCount, 1) * 2),
    eyeKind: new Int32Array(memory, exp.figure_eye_kind() >>> 0, Math.max(eyeCount, 1))
  };
}

function pathData(xy, shape, points) {
  const base = shape * points * 2;
  const parts = new Array(points + 1);
  for (let i = 0; i < points; i += 1) {
    const x = xy[base + i * 2].toFixed(3);
    const y = xy[base + i * 2 + 1].toFixed(3);
    parts[i] = (i === 0 ? "M" : "L") + x + " " + y;
  }
  parts[points] = "Z";
  return parts.join("");
}

function ensure(count) {
  if (built === count) return;
  world.replaceChildren();
  eyes.replaceChildren();
  birds.length = 0;
  for (let shape = 0; shape < count; shape += 1) {
    const group = document.createElementNS("http://www.w3.org/2000/svg", "g");
    group.classList.add("bird");
    group.dataset.shape = String(shape);
    const body = document.createElementNS("http://www.w3.org/2000/svg", "path");
    body.classList.add("body");
    const halo = document.createElementNS("http://www.w3.org/2000/svg", "path");
    halo.classList.add("halo");
    halo.setAttribute("fill", "none");
    halo.setAttribute("stroke", "#f0a202");
    halo.setAttribute("stroke-width", "3");
    halo.setAttribute("stroke-linejoin", "round");
    halo.setAttribute("vector-effect", "non-scaling-stroke");
    group.append(body, halo);
    world.append(group);
    birds.push({group, body, halo});
  }
  world.append(eyes);
  built = count;
}

function paintEyes(state) {
  eyes.replaceChildren();
  for (let i = 0; i < state.eyes; i += 1) {
    const dark = state.eyeKind[i] === 0;
    const eye = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    eye.setAttribute("cx", state.eyeXY[i * 2].toFixed(3));
    eye.setAttribute("cy", state.eyeXY[i * 2 + 1].toFixed(3));
    eye.setAttribute("r", "0.018");
    eye.setAttribute("fill", dark ? CREAM : DARK);
    const pupil = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    pupil.setAttribute("cx", eye.getAttribute("cx"));
    pupil.setAttribute("cy", eye.getAttribute("cy"));
    pupil.setAttribute("r", "0.007");
    pupil.setAttribute("fill", dark ? DARK : CREAM);
    eyes.append(eye, pupil);
  }
}

function show(state) {
  ensure(state.shapes);
  for (let shape = 0; shape < state.shapes; shape += 1) {
    const dark = state.kind[shape] === 0;
    const colour = dark ? DARK : CREAM;
    const item = birds[shape];
    const d = pathData(state.xy, shape, state.points);
    item.body.setAttribute("d", d);
    item.body.setAttribute("fill", colour);
    item.body.setAttribute("stroke", colour);
    item.body.setAttribute("stroke-width", "1.4");
    item.body.setAttribute("stroke-linejoin", "round");
    item.body.setAttribute("vector-effect", "non-scaling-stroke");
    item.halo.setAttribute("d", d);
    item.group.classList.toggle("lit", state.highlight === state.kind[shape] + 1);
    item.group.setAttribute("aria-label", t(dark ? "figDark" : "figLight"));
  }
  paintEyes(state);
  if (state.highlight === 1) who.textContent = t("figDark");
  else if (state.highlight === 2) who.textContent = t("figLight");
  else if (state.morph) who.textContent = t("figGrowing");
  else if (state.uniform === 0) who.textContent = t("figFlat");
  else who.textContent = t("figBirds");
  window.GEB.state = {
    wasm: "ok",
    layer: state.morph ? "growing" : String(state.uniform),
    taps: String(state.taps),
    string: state.shapes + " birds",
    history: state.last < 0 ? "—" : String(state.last),
    error: t("err" + state.error)
  };
  window.GEB.refreshDebug?.();
}

function draw() {
  show(read());
}

svg.setAttribute("viewBox", `${MIN_X} ${-MAX_Y} ${MAX_X - MIN_X} ${MAX_Y - MIN_Y}`);
world.setAttribute("transform", "scale(1,-1)");
svg.append(world);

svg.addEventListener("click", (event) => {
  const group = event.target.closest?.(".bird");
  if (!group || !wasm) return;
  wasm.exports.figure_tap(Number(group.dataset.shape));
  const state = read();
  if (state.error === 0 && state.highlight !== 0) playChime();
  else play("undo");
  show(state);
});

slider?.addEventListener("input", () => {
  wasm?.exports.figure_uniform(Number(slider.value));
  draw();
});

document.getElementById("undo")?.addEventListener("click", () => {
  wasm?.exports.figure_undo();
  play("undo");
  const state = read();
  if (!state.morph) slider.value = String(state.uniform);
  show(state);
});

document.getElementById("reset")?.addEventListener("click", () => {
  wasm?.exports.figure_reset();
  if (slider) slider.value = "0";
  play("reset");
  draw();
});

window.addEventListener("languagechange", () => {
  if (wasm) draw();
});

const response = await fetch("figure.wasm?v=4");
const {instance} = await WebAssembly.instantiate(await response.arrayBuffer());
wasm = instance;
wasm.exports.figure_reset();
draw();
