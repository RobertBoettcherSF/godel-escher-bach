# Strange loops

A browser companion to the themes of *Gödel, Escher, Bach*, one chapter at a time. The words and pictures here are original.

**[Open the gallery](gallery.html)** when this repository is served from GitHub Pages on `main` (`https://robertboettchersf.github.io/godel-escher-bach/`). The stamp on every page matches [`version.txt`](version.txt).

v0.1 opens the MIU blocks. M, I and U are coloured blocks. Four picture-buttons apply the rules. The count of I blocks is never a multiple of 3, so MU stays out of reach. The rules are Ada, compiled to `miu.wasm`.

v0.2 opens the endless steps. A runner closes half the remaining gap on every tap, and the steps are coloured blocks in one bar. That arithmetic is Ada, compiled to `steps.wasm`.

v0.4 turns figure and ground into a field of triangles that grow into birds. The curves, the morph and the taps live in Ada, compiled to `figure.wasm`. JavaScript only draws.

v0.5 opens recursion. Frames nest, a tree branches, and rabbit dots follow the counts. That state is Ada, compiled to `recursion.wasm`.

English (UK), German, Spanish and French. Four further chapters are drawn as closed tiles.

## Run locally

```sh
python3 -m http.server 8000
```

Open http://localhost:8000. F9 shows the version, whether `miu.wasm` loaded, the current blocks, the path length and the last status.

## Checks

```sh
gprbuild -P tests/smoke.gpr && ./obj/native/smoke && ./obj/native/steps_smoke && ./obj/native/figure_smoke && ./obj/native/recursion_smoke
npm test
```

The MIU test searches every string reachable from MI up to length 12. The steps test checks that after n steps the gap is 1/2ⁿ and the sum stays below 1. The figure test checks that every cell belongs to one layer and that two swaps restore the picture. See [docs/BUILD.md](docs/BUILD.md) to rebuild the wasm, and [docs/WORKFLOW.md](docs/WORKFLOW.md) for the stamp.
