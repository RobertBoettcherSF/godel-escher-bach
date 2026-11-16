import {readFile} from "node:fs/promises";
import test from "node:test";
import assert from "node:assert/strict";

const file = await readFile(new URL("../crab.wasm", import.meta.url));
const {instance} = await WebAssembly.instantiate(file);
const e = instance.exports;

function read() {
  const memory = e.memory.buffer;
  const meta = new Int32Array(memory, e.crab_meta() >>> 0, 4);
  return {
    tiles: meta[0],
    palindrome: meta[1],
    notes: meta[2],
    pitchMax: meta[3],
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
  assert.equal(st.tiles, 11);
  assert.equal(st.notes, 8);
  assert.equal(st.pitchMax, 6);
  assert.equal(st.palindrome, 1);
  assert.deepEqual(st.pitches, [0, 2, 4, 5, 4, 2, 1, 0]);
  assert.deepEqual(st.mirrors, [0, 1, 2, 4, 5, 4, 2, 0]);

  setText("RADAR");
  st = read();
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
});
