import {readFile} from "node:fs/promises";
import test from "node:test";
import assert from "node:assert/strict";

const file = await readFile(new URL("../recursion.wasm", import.meta.url));
const {instance} = await WebAssembly.instantiate(file);
const e = instance.exports;

function text(st, which, len) {
  let out = "";
  const start = which * 256;
  for (let i = len - 1; i >= 0; i -= 1) out += String(st.places[start + i]);
  return out || "0";
}

function read() {
  const memory = e.memory.buffer;
  const meta = new Int32Array(memory, e.recursion_meta() >>> 0, 12);
  const segments = meta[3];
  const dots = meta[8];
  return {
    depth: meta[0],
    tree: meta[2],
    segments,
    terms: meta[4],
    valueLen: meta[5],
    olderLen: meta[6],
    newerLen: meta[7],
    dots,
    visible: meta[10],
    unit: meta[11],
    places: new Int32Array(memory, e.recursion_digits() >>> 0, 256 * 3),
    error: meta[9],
    seg: new Int32Array(memory, e.recursion_segments() >>> 0, Math.max(segments, 1) * 5),
    dot: new Int32Array(memory, e.recursion_dots() >>> 0, Math.max(dots, 1) * 5)
  };
}

test("frames, branches and rabbit dots stay inside their caps", () => {
  e.recursion_reset();
  let st = read();
  assert.equal(st.depth, 1);
  assert.equal(st.tree, 5);
  assert.equal(st.segments, 2 ** 6 - 1);
  assert.equal(st.terms, 1);
  assert.equal(text(st, 0, st.valueLen), "1");

  for (let i = 0; i < 30; i += 1) e.recursion_deeper();
  st = read();
  assert.equal(st.depth, 31);
  assert.equal(st.error, 0);
  for (let i = 0; i < 30; i += 1) e.recursion_back();
  st = read();
  assert.equal(st.depth, 1);
  assert.equal(st.error, 0);
  e.recursion_back();
  st = read();
  assert.equal(st.depth, 1);
  assert.equal(st.error, 2);

  e.recursion_tree(0);
  assert.equal(read().segments, 1);
  e.recursion_tree(10);
  st = read();
  assert.equal(st.segments, 2 ** 11 - 1);
  assert.equal(st.visible, 10);
  const trunk = st.seg[0] - st.seg[2];
  assert.ok(Math.abs(trunk) <= 2);
  const at10 = st.seg[0];
  e.recursion_tree(11);
  st = read();
  assert.ok(st.segments > 8 && st.segments <= 2047);
  assert.notEqual(st.seg[0], at10);
  e.recursion_tree(20);
  st = read();
  assert.equal(st.tree, 20);
  assert.ok(st.segments > 8 && st.segments <= 2047);
  assert.ok(st.seg[4] > 0);
  e.recursion_tree(0);
  assert.equal(read().segments, 1);

  e.recursion_next();
  st = read();
  assert.equal(st.terms, 2);
  assert.equal(text(st, 0, st.valueLen), "1");
  e.recursion_next();
  st = read();
  assert.equal(text(st, 0, st.valueLen), "2");
  for (let i = 0; i < 8; i += 1) e.recursion_next();
  st = read();
  assert.equal(text(st, 0, st.valueLen), "89");
  assert.equal(text(st, 1, st.olderLen), "34");
  assert.equal(text(st, 2, st.newerLen), "55");
  let red = 0;
  let blue = 0;
  for (let i = 0; i < st.dots; i += 1) {
    if (st.dot[i * 5 + 4] !== 2) continue;
    if (st.dot[i * 5 + 3] === 0) red += 1;
    else blue += 1;
    assert.ok(st.dot[i * 5 + 2] >= 10);
  }
  assert.equal(red, 34);
  assert.equal(blue, 55);
  for (let i = 0; i < 90; i += 1) e.recursion_next();
  st = read();
  assert.equal(st.terms, 101);
  assert.equal(text(st, 0, st.valueLen), "573147844013817084101");
  assert.equal(st.error, 0);
  assert.ok(st.dots > 0 && st.dots <= 400);
  assert.ok(st.unit > 0);
  e.recursion_rabbits_reset();
  assert.equal(read().terms, 1);
});
