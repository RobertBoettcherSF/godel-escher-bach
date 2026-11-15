import {t} from "./i18n.js?v=1";

const KEY = "geb.sound";
const tones = {
  apply: [660, 0.08],
  no: [196, 0.07],
  pick: [523, 0.05],
  undo: [330, 0.07],
  reset: [440, 0.09],
  language: [784, 0.045],
  locked: [146, 0.08],
  hint: [988, 0.06],
  open: [698, 0.05]
};
const rulePitch = [523, 659, 784, 392];
let muted = false;
try {
  muted = globalThis.localStorage?.getItem(KEY) === "off";
} catch {
  /* private mode */
}
let context = null;

export const isMuted = () => muted;

export function setMuted(value) {
  muted = Boolean(value);
  try {
    globalThis.localStorage?.setItem(KEY, muted ? "off" : "on");
  } catch {
    /* ignore */
  }
  window.dispatchEvent(new CustomEvent("soundchange"));
}

export function toggleMuted() {
  setMuted(!muted);
  return muted;
}

export function play(name, rule) {
  const tone = tones[name];
  if (!tone || muted) return false;
  const AC = globalThis.AudioContext || globalThis.webkitAudioContext;
  if (!AC) return true;
  try {
    if (!context) context = new AC();
    if (context.state === "suspended") context.resume().catch(() => {});
    const freq = name === "apply" && rule ? rulePitch[rule - 1] : tone[0];
    const dur = tone[1];
    const start = context.currentTime;
    const osc = context.createOscillator();
    const gain = context.createGain();
    osc.type = "sine";
    osc.frequency.value = freq;
    gain.gain.setValueAtTime(0.0001, start);
    gain.gain.exponentialRampToValueAtTime(0.04, start + 0.01);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + dur);
    osc.connect(gain);
    gain.connect(context.destination);
    osc.start(start);
    osc.stop(start + dur + 0.02);
  } catch {
    /* autoplay limits */
  }
  return true;
}

export function bindSoundButton() {
  const button = document.getElementById("sound-toggle");
  if (!button) return;
  const update = () => {
    const label = button.querySelector("[data-i18n]");
    const key = muted ? "soundOff" : "soundOn";
    if (label) {
      label.dataset.i18n = key;
      label.textContent = t(key);
    }
    button.setAttribute("aria-pressed", String(!muted));
    button.setAttribute("aria-label", t(key));
  };
  button.addEventListener("click", () => {
    const wasMuted = muted;
    toggleMuted();
    update();
    if (wasMuted) play("language");
  });
  window.addEventListener("languagechange", update);
  update();
}
