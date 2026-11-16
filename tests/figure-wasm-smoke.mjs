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
  const points = meta[6];
  return {
    shapes,
    morph: meta[0],
    uniform: meta[1],
    highlight: meta[2],
    taps: meta[3],
    error: meta[4],
    points,
    eyes: meta[7],
    last: meta[8],
    kind: new Int32Array(memory, e.figure_kind() >>> 0, shapes),
    xy: new Float32Array(memory, e.figure_outline_xy() >>> 0, shapes * points * 2)
  };
}

test("birds share edges, and a tap lights one set", () => {
  e.figure_reset();
  let st = read();
  assert.equal(st.shapes, 440);
  assert.equal(st.points, 1597);
  assert.equal(st.morph, 1);
  let dark = 0;
  let cream = 0;
  for (let shape = 0; shape < st.shapes; shape += 1) {
    assert.ok(st.kind[shape] === 0 || st.kind[shape] === 1);
    if (st.kind[shape] === 0) dark += 1;
    else cream += 1;
  }
  assert.equal(dark, 220);
  assert.equal(cream, 220);

  const top = ((8 - -1) * 20 + (2 - -11)) * 2;
  const grown = read().xy[(top * 1597 + 40) * 2 + 1];
  e.figure_uniform(0);
  st = read();
  assert.equal(st.morph, 0);
  assert.equal(st.eyes, 0);
  const straight = st.xy[(top * 1597 + 40) * 2 + 1];
  e.figure_uniform(100);
  st = read();
  assert.ok(st.eyes > 0);
  const bent = st.xy[(top * 1597 + 40) * 2 + 1];
  assert.ok(Math.abs(bent - straight) > 0.02);
  assert.ok(Math.abs(grown - straight) > 0.02);

  e.figure_tap(0);
  st = read();
  assert.equal(st.highlight, st.kind[0] + 1);
  assert.equal(st.error, 0);
  e.figure_tap(0);
  assert.equal(read().highlight, 0);
  e.figure_undo();
  assert.equal(read().highlight, st.kind[0] + 1);
  e.figure_tap(-3);
  assert.equal(read().error, 2);
  e.figure_reset();
  e.figure_undo();
  assert.equal(read().error, 5);
});
