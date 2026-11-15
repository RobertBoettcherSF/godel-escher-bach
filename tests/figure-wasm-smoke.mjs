import {readFile} from "node:fs/promises";
import test from "node:test";
import assert from "node:assert/strict";

const file = await readFile(new URL("../figure.wasm", import.meta.url));
const {instance} = await WebAssembly.instantiate(file);
const e = instance.exports;

function read() {
  const shapes = e.figure_shapes();
  const memory = e.memory.buffer;
  const meta = new Int32Array(memory, e.figure_meta() >>> 0, 9);
  return {
    shapes,
    blend: meta[0],
    front: meta[1],
    taps: meta[2],
    hidden: meta[3],
    found: meta[4],
    error: meta[5],
    last: meta[7],
    grow: meta[8],
    layer: new Int32Array(memory, e.figure_shape_layer() >>> 0, shapes),
    kind: new Int32Array(memory, e.figure_shape_kind() >>> 0, shapes),
    ink: new Int32Array(memory, e.figure_shape_ink() >>> 0, shapes)
  };
}

test("each animal is one layer, and two swaps restore the inks", () => {
  e.figure_reset();
  let st = read();
  assert.ok(st.shapes >= 16 && st.shapes % 2 === 0);
  assert.equal(st.grow, 100);
  let birds = 0;
  let fish = 0;
  for (let shape = 0; shape < st.shapes; shape += 1) {
    assert.ok(st.layer[shape] === 0 || st.layer[shape] === 1);
    assert.equal(st.kind[shape], st.layer[shape]);
    assert.equal(st.ink[shape], st.layer[shape] === 0 ? 255 : 0);
    if (st.layer[shape] === 0) birds += 1;
    else fish += 1;
  }
  assert.equal(birds + fish, st.shapes);
  assert.ok(birds > 0 && fish > 0);
  const start = Array.from(st.ink);
  const hidden = st.hidden;
  assert.equal(st.layer[hidden], 1);
  e.figure_tap(hidden);
  st = read();
  assert.equal(st.found, 1);
  assert.equal(st.last, hidden);
  assert.equal(st.blend, 100);
  assert.equal(st.front, 1);
  e.figure_tap(0);
  st = read();
  assert.equal(st.blend, 0);
  assert.deepEqual(Array.from(st.ink), start);
  e.figure_blend(25);
  st = read();
  assert.equal(st.ink[0], 255 - 63);
  assert.equal(st.ink[1], 63);
  e.figure_grow(0);
  st = read();
  assert.equal(st.grow, 0);
  assert.equal(st.blend, 25);
  e.figure_grow(140);
  assert.equal(read().grow, 100);
});
