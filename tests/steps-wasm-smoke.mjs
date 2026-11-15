import {readFile} from "node:fs/promises";
import test from "node:test";
import assert from "node:assert/strict";

const file = await readFile(new URL("../steps.wasm", import.meta.url));
const {instance} = await WebAssembly.instantiate(file);
const e = instance.exports;

function read() {
  const max = e.steps_max();
  const memory = e.memory.buffer;
  const meta = new Int32Array(memory, e.steps_meta() >>> 0, 10);
  const widths = new Int32Array(memory, e.steps_widths() >>> 0, max);
  return {
    count: meta[0],
    error: meta[1],
    gapNum: meta[2],
    gapDen: meta[3],
    sumNum: meta[4],
    sumDen: meta[5],
    gapUnits: meta[6],
    sumUnits: meta[7],
    scale: meta[8],
    max: meta[9],
    widths
  };
}

test("halving steps keep an exact gap and a sum below one", () => {
  assert.equal(e.steps_max(), 30);
  assert.equal(e.steps_scale(), 2 ** 30);
  e.steps_reset();
  let st = read();
  assert.equal(st.count, 0);
  assert.equal(st.gapNum, 1);
  assert.equal(st.gapDen, 1);
  assert.equal(st.sumNum, 0);
  assert.equal(st.error, 0);

  e.steps_step();
  st = read();
  assert.equal(st.gapDen, 2);
  assert.equal(st.sumNum, 1);
  assert.equal(st.sumDen, 2);
  assert.equal(st.widths[0], st.scale / 2);

  e.steps_step();
  e.steps_step();
  st = read();
  assert.equal(st.count, 3);
  assert.equal(st.gapNum, 1);
  assert.equal(st.gapDen, 8);
  assert.equal(st.sumNum, 7);
  assert.equal(st.sumDen, 8);
  assert.ok(st.sumNum < st.sumDen);
  assert.equal(st.sumUnits + st.gapUnits, st.scale);
  assert.equal(st.widths[0] + st.widths[1] + st.widths[2], st.sumUnits);

  e.steps_undo();
  st = read();
  assert.equal(st.count, 2);
  assert.equal(st.gapDen, 4);
  assert.equal(st.sumNum, 3);

  e.steps_reset();
  e.steps_undo();
  assert.equal(read().error, 5);
  assert.equal(read().count, 0);
});
