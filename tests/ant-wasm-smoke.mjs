import {readFile} from "node:fs/promises";
import test from "node:test";
import assert from "node:assert/strict";

const file = await readFile(new URL("../ant.wasm", import.meta.url));
const {instance} = await WebAssembly.instantiate(file);
const e = instance.exports;

function read() {
  const memory = e.memory.buffer;
  const meta = new Int32Array(memory, e.ant_meta() >>> 0, 19);
  const count = meta[0];
  const width = meta[1];
  const height = meta[2];
  const voices = meta[9];
  const motifN = meta[10];
  return {
    count,
    width,
    height,
    trailMax: meta[3],
    steps: meta[7],
    clusters: meta[8],
    voices,
    motifN,
    loopN: meta[11],
    beat: meta[12],
    scale: meta[18],
    x: new Int32Array(memory, e.ant_x() >>> 0, count),
    y: new Int32Array(memory, e.ant_y() >>> 0, count),
    trail: new Int32Array(memory, e.ant_trail() >>> 0, width * height),
    group: new Int32Array(memory, e.ant_cluster() >>> 0, meta[8]),
    voice: new Int32Array(memory, e.ant_voice() >>> 0, voices * 3),
    motif: new Int32Array(memory, e.ant_motif() >>> 0, motifN)
  };
}

function checkWorld(st) {
  assert.equal(st.count, 150);
  let sum = 0;
  for (let i = 0; i < st.count; i += 1) {
    assert.ok(st.x[i] >= 0 && st.x[i] < st.width * st.scale);
    assert.ok(st.y[i] >= 0 && st.y[i] < st.height * st.scale);
  }
  for (let i = 0; i < st.trail.length; i += 1) {
    assert.ok(st.trail[i] >= 0 && st.trail[i] <= st.trailMax);
  }
  for (let id = 0; id < st.clusters; id += 1) sum += st.group[id];
  assert.equal(sum, st.count);
}

test("ants stay on the grid and the fugue enters in order", () => {
  e.ant_reset();
  let st = read();
  assert.equal(st.width, 28);
  assert.equal(st.height, 18);
  assert.equal(st.voices, 4);
  assert.deepEqual(Array.from(st.motif), [0, 2, 4, 5]);
  checkWorld(st);

  e.ant_drop(3, 4);
  for (let n = 0; n < 12; n += 1) e.ant_step();
  st = read();
  checkWorld(st);
  assert.equal(st.steps, 12);

  e.ant_set_beat(0);
  st = read();
  assert.equal(st.voice[0], 1);
  assert.equal(st.voice[1], 0);
  assert.equal(st.voice[3], 0);
  e.ant_set_beat(4);
  st = read();
  assert.equal(st.voice[3], 1);
  assert.equal(st.voice[4], 0);
  e.ant_set_beat(12);
  st = read();
  assert.equal(st.voice[9], 1);
  assert.equal(st.voice[10], 0);
  e.ant_set_beat(16);
  assert.equal(read().beat, 0);
  e.ant_set_beat(-1);
  assert.equal(read().beat, -1);
});
