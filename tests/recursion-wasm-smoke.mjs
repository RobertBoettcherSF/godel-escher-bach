import {readFile} from "node:fs/promises";
import test from "node:test";
import assert from "node:assert/strict";

const file = await readFile(new URL("../recursion.wasm", import.meta.url));
const {instance} = await WebAssembly.instantiate(file);
const e = instance.exports;

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
    value: meta[5],
    older: meta[6],
    newer: meta[7],
    dots,
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
  assert.equal(st.value, 1);

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
  const trunk = st.seg[0] - st.seg[2];
  assert.ok(Math.abs(trunk) <= 2);

  e.recursion_next();
  st = read();
  assert.equal(st.terms, 2);
  assert.equal(st.value, 1);
  e.recursion_next();
  st = read();
  assert.equal(st.value, 2);
  for (let i = 0; i < 8; i += 1) e.recursion_next();
  st = read();
  assert.equal(st.value, 89);
  assert.equal(st.older, 34);
  assert.equal(st.newer, 55);
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
  e.recursion_next();
  assert.equal(read().error, 4);
  e.recursion_rabbits_reset();
  assert.equal(read().terms, 1);
});
