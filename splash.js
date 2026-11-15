import "./shell.js?v=1";
import {play} from "./sounds.js?v=1";

const canvas = document.getElementById("loop");
const ctx = canvas.getContext("2d");
const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const started = performance.now();

function resize() {
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  const rect = canvas.getBoundingClientRect();
  canvas.width = Math.max(1, Math.round(rect.width * dpr));
  canvas.height = Math.max(1, Math.round(rect.height * dpr));
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
}

function loopPoint(t, radius) {
  const angle = t * Math.PI * 2 - Math.PI / 2;
  const sector = (Math.PI * 2) / 3;
  let local = angle % sector;
  if (local < 0) local += sector;
  local -= sector / 2;
  const distance = (radius * Math.cos(sector / 2)) / Math.max(0.35, Math.cos(local));
  const twist = Math.sin(t * Math.PI * 2) * radius * 0.06;
  return [
    Math.cos(angle) * distance + Math.cos(angle + Math.PI / 2) * twist,
    Math.sin(angle) * distance + Math.sin(angle + Math.PI / 2) * twist
  ];
}

function strokeLoop(cx, cy, radius, samples, alpha, width) {
  ctx.globalAlpha = alpha;
  ctx.lineWidth = width;
  ctx.strokeStyle = "rgba(255, 246, 234, 0.9)";
  ctx.beginPath();
  const [x0, y0] = loopPoint(0, radius);
  ctx.moveTo(cx + x0, cy + y0);
  for (let i = 1; i <= samples; i += 1) {
    const [x, y] = loopPoint(i / samples, radius);
    ctx.lineTo(cx + x, cy + y);
  }
  ctx.closePath();
  ctx.stroke();
}

function frame(now) {
  const rect = canvas.getBoundingClientRect();
  const width = rect.width;
  const height = rect.height;
  if (width < 2 || height < 2) {
    if (!reduced) requestAnimationFrame(frame);
    return;
  }
  ctx.clearRect(0, 0, width, height);
  const radius = Math.min(width, height) * 0.24;
  const cx = width / 2;
  const cy = Math.min(height * 0.36, height / 2 - 20);
  const elapsed = reduced ? 8000 : now - started;
  const draw = Math.min(1, Math.max(0, elapsed / 7000));
  const colours = ["#ff5d6c", "#6aa2ff", "#ffc44d"];
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  strokeLoop(cx, cy, radius, 180, 0.22, 28);
  const samples = 240;
  const limit = Math.max(2, Math.floor(samples * draw));
  for (let i = 1; i < limit; i += 1) {
    const t0 = (i - 1) / samples;
    const t1 = i / samples;
    const [x0, y0] = loopPoint(t0, radius);
    const [x1, y1] = loopPoint(t1, radius);
    ctx.globalAlpha = 1;
    ctx.strokeStyle = colours[Math.floor(t0 * 3) % 3];
    ctx.lineWidth = 22 + Math.sin(t0 * Math.PI * 2) * 8;
    ctx.beginPath();
    ctx.moveTo(cx + x0, cy + y0);
    ctx.lineTo(cx + x1, cy + y1);
    ctx.stroke();
  }
  if (!reduced) {
    const travel = draw < 1 ? draw : ((elapsed - 7000) / 6000) % 1;
    const [x, y] = loopPoint(travel, radius);
    ctx.globalAlpha = 1;
    ctx.fillStyle = "#fff6ea";
    ctx.beginPath();
    ctx.arc(cx + x, cy + y, 8, 0, Math.PI * 2);
    ctx.fill();
    ctx.lineWidth = 3;
    ctx.strokeStyle = "#1a1430";
    ctx.stroke();
  }
  ctx.globalAlpha = 1;
  if (!reduced) requestAnimationFrame(frame);
}

window.addEventListener("resize", () => {
  resize();
  if (reduced) frame(performance.now());
});
resize();
if (reduced) frame(performance.now());
else requestAnimationFrame(frame);
document.getElementById("main")?.addEventListener("click", () => play("open"));
