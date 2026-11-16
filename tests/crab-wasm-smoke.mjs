import {readFile} from "node:fs/promises";
import test from "node:test";
import assert from "node:assert/strict";

const file = await readFile(new URL("../crab.wasm", import.meta.url));
const {instance} = await WebAssembly.instantiate(file);
const e = instance.exports;

function read() {
  const memory = e.memory.buffer;
  const meta = new Int32Array(memory, e.crab_meta() >>> 0, 10);
  return {
    tiles: meta[0],
    palindrome: meta[1],
    notes: meta[2],
    pitchMax: meta[3],
    melodyCount: meta[4],
    melody: meta[5],
    stepMs: meta[6],
    beat: meta[7],
    upper: meta[8],
    lower: meta[9],
    letters: Array.from(new Int32Array(memory, e.crab_letters() >>> 0, 11)),
    pitches: Array.from(new Int32Array(memory, e.crab_notes() >>> 0, 8)),
    mirrors: Array.from(new Int32Array(memory, e.crab_mirrors() >>> 0, 8))
  };
}

function setText(text) {
  e.crab_clear();
  for (let i = 0; i < text.length; i += 1) e.crab_set_letter(i, text.charCodeAt(i));
}

test("the row and the mirrored voice come from Ada", () => {
  e.crab_reset();
  let st = read();
  assert.equal(st.tiles, 0);
  assert.equal(st.notes, 8);
  assert.equal(st.pitchMax, 6);
  assert.equal(st.melodyCount, 3);
  assert.equal(st.melody, 0);
  assert.equal(st.palindrome, 1);
  assert.deepEqual(st.mirrors, st.pitches.slice().reverse());

  const lines = [];
  for (let i = 0; i < st.melodyCount; i += 1) {
    e.crab_select_melody(i);
    st = read();
    assert.equal(st.melody, i);
    assert.deepEqual(st.mirrors, [...st.pitches].reverse());
    lines.push(st.pitches.join(","));
  }
  assert.equal(new Set(lines).size, 3);
  e.crab_select_melody(st.melodyCount);
  assert.deepEqual(read().pitches, lines[0].split(",").map(Number));

  setText("KAYAK");
  st = read();
  assert.equal(st.tiles, 5);
  e.crab_set_letter(4, "Z".charCodeAt(0));
  e.crab_cycle_letter(4);
  st = read();
  assert.equal(st.letters[4], 0);
  assert.equal(st.tiles, 5);

  setText("RADAR");
  st = read();
  assert.equal(st.tiles, 5);
  assert.equal(st.palindrome, 1);
  assert.equal(st.letters[0], "R".charCodeAt(0));
  assert.equal(st.letters[4], "R".charCodeAt(0));
  e.crab_cycle_letter(0);
  st = read();
  assert.equal(st.palindrome, 0);
  assert.equal(st.letters[0], "S".charCodeAt(0));

  setText("\u00c9t\u00e9");
  assert.equal(read().palindrome, 1);
  setText("a\u00dfa");
  assert.equal(read().palindrome, 1);
  setText("ba\u00df");
  assert.equal(read().palindrome, 0);
  setText("A man, a plan");
  assert.equal(read().palindrome, 0);

  e.crab_reset();
  e.crab_cycle_note(0);
  st = read();
  assert.equal(st.pitches[0], 1);
  assert.equal(st.mirrors[7], 1);
  for (let step = 0; step < 6; step += 1) e.crab_cycle_note(0);
  st = read();
  assert.equal(st.pitches[0], 0);
  assert.deepEqual(st.mirrors, st.pitches.slice().reverse());

  let seed = 1;
  const next = () => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    return seed;
  };
  for (let trial = 0; trial < 40; trial += 1) {
    e.crab_clear();
    const codes = [];
    for (let i = 0; i < 11; i += 1) {
      const code = next() % 256;
      codes.push(code);
      e.crab_set_letter(i, code);
    }
    e.crab_cycle_note(next() % 8);
    st = read();
    assert.deepEqual(st.mirrors, st.pitches.slice().reverse());
    assert.deepEqual(st.mirrors.slice().reverse(), st.pitches);
  }

  e.crab_reset();
  assert.equal(read().stepMs, 340);
  assert.equal(read().beat, -1);
  e.crab_set_beat(2);
  st = read();
  assert.equal(st.beat, 2);
  assert.equal(st.upper, 2);
  assert.equal(st.lower, 2);
  assert.equal(st.mirrors[st.lower], st.pitches[7 - st.upper]);
  e.crab_set_beat(8);
  assert.equal(read().beat, 0);
  e.crab_set_beat(-1);
  assert.equal(read().beat, -1);
  assert.equal(read().upper, -1);
});
