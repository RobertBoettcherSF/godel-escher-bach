# QA and release checklist

Run these before a stamp. Record the command output in the release notes you keep locally; the repository only needs a green run.

- [ ] `gprbuild -P tests/smoke.gpr` prints no warnings.
- [ ] `./obj/native/smoke` prints `reachable` and `OK`. The search found no MU, and no I-count divisible by 3, up to length 12.
- [ ] `./obj/native/steps_smoke` prints `OK`. After n steps the gap is 1/2ⁿ and the sum of the steps stays below 1.
- [ ] `./obj/native/figure_smoke` prints `OK`. Every cell belongs to one layer, and two swaps restore the inks.
- [ ] `./build.sh figure` prints no warnings and writes `figure.wasm` without touching `miu.wasm` or `steps.wasm`.
- [ ] `npm test` passes the wasm smokes and the i18n smoke.
- [ ] `version.txt` and every HTML version span are the same `v0.5 bYYYYMMDD-HHMM <7 hex digits>` line. The time is Europe/Berlin. The hex digits are the source commit, not a placeholder of zeros.
- [ ] Splash, gallery, MIU and one “soon” page load from a local static server.
- [ ] On a narrow window and a wide window: rule buttons glow only when they apply; a string with two III or UU matches asks for a tap; Undo, Reset and the path behave; the I counter matches the blue blocks.
- [ ] Flag buttons change every visible caption, including the secret.
- [ ] Sound survives a reload. `prefers-reduced-motion: reduce` stops the splash loop and the block animation.
- [ ] F9 shows version, wasm status, the current string, the history length and the last status.
- [ ] No sentence or picture was copied from the book. `toolchain/` is not committed. `miu.wasm` is.
