# Workflow

GitHub Pages serves the root of `main`. There is no build on the server. `miu.wasm`, `steps.wasm`, `figure.wasm`, `recursion.wasm` and `crab.wasm` are already in the repository.

## Change a rule or a page

1. Edit `src/` for the rules, or the HTML, CSS and JS for the pictures and words.
2. `gprbuild -P tests/smoke.gpr && ./obj/native/smoke && ./obj/native/crab_smoke`
3. `./build.sh` if Ada changed, then `npm test`
4. Open the pages with `python3 -m http.server` and try a phone width and a wide window.
5. Commit the source, including a rebuilt wasm file when the Ada changed.
6. Stamp, then commit the stamp:

```sh
./tools/stamp.sh
```

The stamp is `v0.6.2 bYYYYMMDD-HHMM <shortcommit>`. The clock is Europe/Berlin. The short commit is HEAD at the moment of stamping, so it names the source commit and the stamp commit comes next. `version.txt` and every `<span class="version">` carry the same line.

After a strict visual check (desktop and a phone width, including the interacted states), merge straight to `main` and stamp so the live pages can be tested. Do not wait for a separate screenshot approval.

## Words

Visible copy is in `i18n.js` for en-GB (the `en` key), de, es and fr. The English text is also the fallback in the HTML. Do not paste sentences or pictures from the book. Draw new marks.

## F9

F9 opens a small overlay: version, WebAssembly status, current string, history length, last status. On the steps page it also shows the step count and the gap. On the figure page it shows which animals are in front and the tap count. It is for checking a page, not part of the game.

## Sound and language

`geb.sound` and `geb.lang` live in localStorage. Sound starts on until someone turns it off.
