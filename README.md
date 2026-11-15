# Strange loops

A browser companion to the themes of *Gödel, Escher, Bach*, one chapter at a time. The words and pictures here are original.

**[Open the gallery](gallery.html)** when this repository is served from GitHub Pages on `main` (`https://robertboettchersf.github.io/godel-escher-bach/`). The stamp on every page matches [`version.txt`](version.txt).

v0.1 opens the MIU blocks. M, I and U are coloured blocks. Four picture-buttons apply the rules. The count of I blocks is never a multiple of 3, so MU stays out of reach. The rules are Ada, compiled to `miu.wasm`. JavaScript loads that file and draws.

English (UK), German, Spanish and French. Seven further chapters are drawn as closed tiles.

## Run locally

```sh
python3 -m http.server 8000
```

Open http://localhost:8000. F9 shows the version, whether `miu.wasm` loaded, the current blocks, the path length and the last status.

## Checks

```sh
gprbuild -P tests/smoke.gpr && ./obj/native/smoke
npm test
```

The Ada test searches every string reachable from MI up to length 12. See [docs/BUILD.md](docs/BUILD.md) to rebuild the wasm, and [docs/WORKFLOW.md](docs/WORKFLOW.md) for the stamp.
