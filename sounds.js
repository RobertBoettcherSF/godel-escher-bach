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

export function playChime() {
  if (muted) return false;
  const AC = globalThis.AudioContext || globalThis.webkitAudioContext;
  if (!AC) return true;
  try {
    if (!context) context = new AC();
    if (context.state === "suspended") context.resume().catch(() => {});
    const start = context.currentTime;
    [523, 659].forEach((freq, index) => {
      const osc = context.createOscillator();
      const gain = context.createGain();
      const at = start + index * 0.09;
      osc.type = "sine";
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0.0001, at);
      gain.gain.exponentialRampToValueAtTime(0.04, at + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, at + 0.2);
      osc.connect(gain);
      gain.connect(context.destination);
      osc.start(at);
      osc.stop(at + 0.22);
    });
  } catch {
    /* autoplay limits */
  }
  return true;
}

export function playRise(step) {
  if (muted) return false;
  const freq = 196 * 2 ** (Math.min(Math.max(step, 1), 24) / 12);
  const AC = globalThis.AudioContext || globalThis.webkitAudioContext;
  if (!AC) return true;
  try {
    if (!context) context = new AC();
    if (context.state === "suspended") context.resume().catch(() => {});
    const start = context.currentTime;
    const osc = context.createOscillator();
    const gain = context.createGain();
    osc.type = "sine";
    osc.frequency.value = freq;
    gain.gain.setValueAtTime(0.0001, start);
    gain.gain.exponentialRampToValueAtTime(0.045, start + 0.012);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.16);
    osc.connect(gain);
    gain.connect(context.destination);
    osc.start(start);
    osc.stop(start + 0.18);
  } catch {
    /* autoplay limits */
  }
  return true;
}

export function playFall(step) {
  if (muted) return false;
  const base = 196 * 2 ** (Math.min(Math.max(step, 1), 24) / 12);
  const AC = globalThis.AudioContext || globalThis.webkitAudioContext;
  if (!AC) return true;
  try {
    if (!context) context = new AC();
    if (context.state === "suspended") context.resume().catch(() => {});
    const start = context.currentTime;
    [base, base / 1.26].forEach((freq, index) => {
      const osc = context.createOscillator();
      const gain = context.createGain();
      const at = start + index * 0.09;
      osc.type = "sine";
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0.0001, at);
      gain.gain.exponentialRampToValueAtTime(0.045, at + 0.012);
      gain.gain.exponentialRampToValueAtTime(0.0001, at + 0.16);
      osc.connect(gain);
      gain.connect(context.destination);
      osc.start(at);
      osc.stop(at + 0.18);
    });
  } catch {
    /* autoplay limits */
  }
  return true;
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

const scale = [261.63, 293.66, 329.63, 349.23, 392.0, 440.0, 493.88];

const sounding = new Set();

export function armAudio() {
  if (muted) return false;
  const AC = globalThis.AudioContext || globalThis.webkitAudioContext;
  if (!AC) return false;
  try {
    if (!context) context = new AC();
    if (context.state === "suspended") context.resume().catch(() => {});
  } catch {
    return false;
  }
  return true;
}

export function toneAt(pitch, voice) {
  if (!context || muted) return;
  try {
    const freq = scale[Math.max(0, Math.min(6, pitch))] || 261.63;
    const osc = context.createOscillator();
    const gain = context.createGain();
    const start = context.currentTime;
    osc.type = voice === 0 ? "sine" : "triangle";
    osc.frequency.value = freq;
    gain.gain.setValueAtTime(0.0001, start);
    gain.gain.exponentialRampToValueAtTime(0.05, start + 0.03);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.3);
    osc.connect(gain);
    gain.connect(context.destination);
    osc.start(start);
    osc.stop(start + 0.32);
    sounding.add(osc);
    osc.onended = () => sounding.delete(osc);
  } catch {
    /* autoplay limits */
  }
}

export function silenceTones() {
  if (!context) {
    sounding.clear();
    return;
  }
  const now = context.currentTime;
  for (const osc of sounding) {
    try {
      osc.stop(now);
    } catch {
      /* already stopped */
    }
  }
  sounding.clear();
}

export function playDuet(forward, backward) {
  if (muted) return false;
  const AC = globalThis.AudioContext || globalThis.webkitAudioContext;
  if (!AC) return true;
  try {
    if (!context) context = new AC();
    if (context.state === "suspended") context.resume().catch(() => {});
    const start = context.currentTime;
    for (let i = 0; i < forward.length; i += 1) {
      const at = start + i * 0.34;
      [forward[i], backward[i]].forEach((pitch, voice) => {
        const osc = context.createOscillator();
        const gain = context.createGain();
        osc.type = voice === 0 ? "sine" : "triangle";
        osc.frequency.value = scale[Math.max(0, Math.min(6, pitch))] || 261.63;
        gain.gain.setValueAtTime(0.0001, at);
        gain.gain.exponentialRampToValueAtTime(0.05, at + 0.03);
        gain.gain.exponentialRampToValueAtTime(0.0001, at + 0.3);
        osc.connect(gain);
        gain.connect(context.destination);
        osc.start(at);
        osc.stop(at + 0.32);
      });
    }
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
