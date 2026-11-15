import {readFile} from "node:fs/promises";
import test from "node:test";
import assert from "node:assert/strict";

const file = await readFile(new URL("../miu.wasm", import.meta.url));
const {instance} = await WebAssembly.instantiate(file);
const e = instance.exports;

function text(chars, length) {
  let out = "";
  for (let i = 0; i < length; i++) out += String.fromCharCode(chars[i]);
  return out;
}

function read() {
  const max = e.miu_max_length();
  const histMax = e.miu_max_history();
  const memory = e.memory.buffer;
  const chars = new Uint8Array(memory, e.miu_chars() >>> 0, max);
  const meta = new Int32Array(memory, e.miu_meta() >>> 0, 8);
  const ready = new Int32Array(memory, e.miu_ready() >>> 0, 4);
  const posCount = new Int32Array(memory, e.miu_pos_count() >>> 0, 4);
  const positions = new Int32Array(memory, e.miu_positions() >>> 0, 4 * max);
  const histLen = new Int32Array(memory, e.miu_hist_len() >>> 0, histMax);
  const histChars = new Uint8Array(memory, e.miu_hist_chars() >>> 0, histMax * max);
  const steps = [];
  for (let step = 0; step < meta[2]; step++) {
    const n = histLen[step];
    steps.push(text(histChars.subarray(step * max, step * max + n), n));
  }
  const spots = (rule) => {
    const base = (rule - 1) * max;
    return Array.from(positions.subarray(base, base + posCount[rule - 1]));
  };
  return {
    string: text(chars, meta[0]),
    length: meta[0],
    iCount: meta[1],
    history: meta[2],
    error: meta[3],
    ready: Array.from(ready),
    spots,
    steps
  };
}

test("compiled module applies the four rules and keeps the I-count", () => {
  assert.equal(e.miu_max_length(), 64);
  assert.equal(e.miu_max_history(), 64);
  e.miu_reset();
  let st = read();
  assert.equal(st.string, "MI");
  assert.equal(st.iCount, 1);
  assert.equal(st.history, 1);
  assert.equal(st.error, 0);
  assert.deepEqual(st.ready, [1, 1, 0, 0]);
  assert.deepEqual(st.steps, ["MI"]);

  e.miu_apply(2, 0);
  e.miu_apply(2, 0);
  st = read();
  assert.equal(st.string, "MIIII");
  assert.deepEqual(st.spots(3), [2, 3]);
  assert.equal(e.miu_resolve(3, 4), 3);
  assert.equal(e.miu_resolve(3, 2), 2);
  assert.equal(e.miu_resolve(3, 1), 0);

  e.miu_apply(1, 0);
  st = read();
  assert.equal(st.string, "MIIIIU");
  e.miu_apply(3, e.miu_resolve(3, 5));
  st = read();
  assert.equal(st.string, "MIUU");
  assert.equal(st.iCount, 1);
  assert.notEqual(st.iCount % 3, 0);
  assert.notEqual(st.string, "MU");

  e.miu_apply(4, 3);
  st = read();
  assert.equal(st.string, "MI");
  assert.equal(st.history, 6);
  assert.deepEqual(st.steps, ["MI", "MII", "MIIII", "MIIIIU", "MIUU", "MI"]);

  e.miu_undo();
  st = read();
  assert.equal(st.string, "MIUU");
  e.miu_reset();
  const before = read().string;
  e.miu_apply(4, 1);
  st = read();
  assert.equal(st.string, before);
  assert.equal(st.error, 2);
  assert.equal(st.history, 1);
  e.miu_apply(9, 0);
  assert.equal(read().error, 1);
});
