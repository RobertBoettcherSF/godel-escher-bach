import {readFile} from "node:fs/promises";
import test from "node:test";
import assert from "node:assert/strict";
import {STRINGS} from "../i18n.js";

const pages = [
  "index.html",
  "gallery.html",
  "mu.html",
  "endless-steps.html",
  "figure-ground.html",
  "recursion.html",
  "nesting.html",
  "crab-canon.html",
  "ant-fugue.html",
  "bloop-floop.html",
  "self-ref.html"
];

test("four languages share every caption", () => {
  const keys = Object.keys(STRINGS.en).sort();
  assert.ok(keys.length > 40);
  for (const lang of ["de", "es", "fr"]) {
    assert.deepEqual(Object.keys(STRINGS[lang]).sort(), keys);
    for (const key of keys) assert.ok(STRINGS[lang][key].length > 0, `${lang}.${key}`);
  }
  assert.notEqual(STRINGS.de.splashLead, STRINGS.en.splashLead);
  assert.notEqual(STRINGS.es.goal, STRINGS.en.goal);
  assert.notEqual(STRINGS.fr.hint1, STRINGS.en.hint1);
});

test("visible copy and the version stamp match the pages", async () => {
  const version = (await readFile(new URL("../version.txt", import.meta.url), "utf8")).trim();
  assert.match(version, /^v0\.6\.3 b\d{8}-\d{4} [0-9a-f]{7}$/);
  const used = new Set();
  for (const name of pages) {
    const html = await readFile(new URL(`../${name}`, import.meta.url), "utf8");
    assert.equal(
      html.includes(`<span class="version">${version}</span>`),
      true,
      name
    );
    for (const match of html.matchAll(/data-i18n(?:-aria)?="([^"]+)"/g)) used.add(match[1]);
    for (const match of html.matchAll(/data-page-title="([^"]+)"/g)) used.add(match[1]);
  }
  for (const key of used) assert.ok(key in STRINGS.en, key);
  for (const key of ["err0", "err1", "err2", "err3", "err4", "err5", "wasmReady", "wasmLoading", "wasmFailed", "wasmNone"]) {
    assert.ok(key in STRINGS.en, key);
  }
});
