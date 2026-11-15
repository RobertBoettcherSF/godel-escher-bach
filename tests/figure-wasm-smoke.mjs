import {readFile} from "node:fs/promises";
import test from "node:test";
import assert from "node:assert/strict";

const file = await readFile(new URL("../figure.wasm", import.meta.url));
const {instance} = await WebAssembly.instantiate(file);
const e = instance.exports;

function read() {
  const cols = e.figure_cols();
  const rows = e.figure_rows();
  const shapes = e.figure_shapes();
  const cells = cols * rows;
  const memory = e.memory.buffer;
  const meta = new Int32Array(memory, e.figure_meta() >>> 0, 8);
  return {
    cols,
    rows,
    shapes,
    blend: meta[0],
    front: meta[1],
    taps: meta[2],
    hidden: meta[3],
    found: meta[4],
    error: meta[5],
    cellShape: new Int32Array(memory, e.figure_cell_shape() >>> 0, cells),
    cellLayer: new Int32Array(memory, e.figure_cell_layer() >>> 0, cells),
    cellInk: new Int32Array(memory, e.figure_cell_ink() >>> 0, cells),
    shapeLayer: new Int32Array(memory, e.figure_shape_layer() >>> 0, shapes)
  };
}

test("every cell is one layer, and two swaps restore the inks", () => {
  e.figure_reset();
  let st = read();
  assert.equal(st.cols, 24);
  assert.equal(st.rows, 16);
  assert.equal(st.shapes, 6);
  const owned = new Array(st.shapes).fill(0);
  let dark = 0;
  let light = 0;
  for (let i = 0; i < st.cols * st.rows; i += 1) {
    const shape = st.cellShape[i];
    const layer = st.cellLayer[i];
    assert.ok(shape >= 0 && shape < st.shapes);
    assert.ok(layer === 0 || layer === 1);
    assert.equal(layer, st.shapeLayer[shape]);
    owned[shape] += 1;
    if (layer === 0) {
      dark += 1;
      assert.equal(st.cellInk[i], 255);
    } else {
      light += 1;
      assert.equal(st.cellInk[i], 0);
    }
  }
  assert.equal(dark + light, st.cols * st.rows);
  assert.ok(dark > 0 && light > 0);
  assert.ok(owned.every((n) => n > 0));
  const start = Array.from(st.cellInk);
  assert.equal(st.shapeLayer[st.hidden], 1);
  e.figure_tap(st.hidden);
  st = read();
  assert.equal(st.found, 1);
  assert.equal(st.blend, 100);
  assert.equal(st.front, 1);
  e.figure_tap(0);
  st = read();
  assert.equal(st.blend, 0);
  assert.deepEqual(Array.from(st.cellInk), start);
  e.figure_blend(25);
  st = read();
  assert.equal(st.cellInk[0] === 192 || st.cellLayer[0] === 1, true);
  const bird = st.cellLayer.findIndex((layer) => layer === 0);
  const fish = st.cellLayer.findIndex((layer) => layer === 1);
  assert.equal(st.cellInk[bird], 255 - 63);
  assert.equal(st.cellInk[fish], 63);
});
