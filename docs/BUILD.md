# Building the MIU engine

Two Ada packages are compiled to WebAssembly with AdaWebPack 24 (GNAT-LLVM, wasm32). JavaScript only loads a module and draws. The compiled files are committed so GitHub Pages does not need a compiler.

- `src/miu.ads`, `src/miu.adb` → `miu.wasm` (the block rules)
- `src/steps.ads`, `src/steps.adb` → `steps.wasm` (halving steps)
- `src/figure.ads`, `src/figure.adb` → `figure.wasm` (figure and ground)

`./build.sh figure` rebuilds only the third module, so the first two wasm files stay byte-for-byte as they were.

## Tools

On Ubuntu, once:

```sh
sudo apt install rpm2cpio cpio lld libedit2 curl unzip ca-certificates gnat gprbuild
./tools/get-toolchain.sh
```

`tools/get-toolchain.sh` downloads:

- AdaWebPack 24.0.0 (`adawebpack-24.0.0-git.fc40.x86_64.rpm` from [godunko/adawebpack](https://github.com/godunko/adawebpack/releases/tag/24.0.0))
- Fedora 40 `llvm16-libs` and `clang16-libs`, which that compiler links against
- the GNAT 14 runtime library via Alire (`gnat_native=14.2.1`), because `llvm-gcc` itself is an Ada program

The download lands in `toolchain/`, which is gitignored. The same steps are used by the holographic-principle and symmetry-visualizations repositories.

## Commands

```sh
./build.sh
gprbuild -P tests/smoke.gpr && ./obj/native/smoke && ./obj/native/steps_smoke
npm test
```

`make test` runs both native programs, rebuilds both wasm files, then the Node smokes. `build.sh` treats Ada warnings as errors (`-gnatwa -gnatwe`). The native project does too, and it enables assertions (`-gnata`).

`llvm-gcc` is invoked as:

```text
llvm-gcc -c --target=wasm32 -O2 -gnat2012 -gnatp -gnatwa -gnatwe \
  --RTS=toolchain/usr/lib/rts-native
```

`wasm-ld` links with `--no-entry --export-memory`, a 1 MiB stack and 16 MiB of memory. `memcpy`, `memmove` and `memset` come from the AdaWebPack runtime archive. There is no binder and no `adainit`; the page calls `miu_reset` before it reads memory.

## What the page calls

Integers are 32-bit. Character arrays are bytes. `miu_reset`, `miu_apply(rule, position)` and `miu_undo` update the arrays. Rules are 1 add U, 2 double the tail, 3 replace III, 4 delete UU. Whole-string rules take position 0. A spot is a 1-based index. `miu_resolve(rule, tap)` returns the match to use, or 0.

`miu_meta` is eight integers: length, I-count, history length, status, last rule, last position, previous length, unused. Status is 0 ok, 1 bad rule, 2 cannot, 3 bad spot, 4 too long, 5 no undo. History is capped at 64 steps; the oldest step is dropped after that. Strings are capped at 64 blocks. Doubling needs a non-empty tail, so a lone M does not glow.

`steps.wasm` exports `steps_reset`, `steps_step`, `steps_undo`, `steps_max`, `steps_scale`, and the addresses of `steps_meta` and `steps_widths`. After n steps the gap numerator is 1 and the denominator is 2ⁿ (1/1 at the start). The sum of the steps is one less than that denominator, so it stays below 1. Widths are integers in units of 1/2³⁰. The page stops at 30 steps because 2³⁰ still fits in a 32-bit signed integer.

`figure.wasm` exports the outlines, the eyes, the kind of each tile, and the morph, uniform stage, tap and undo. Dark tiles and cream tiles share every edge. The page draws the polygons Ada returns.

`recursion.wasm` exports the frame depth, the tree segments and the rabbit dots. Deeper and Back move a stack of at most six frames. The tree slider asks for a depth from 0 to 10. Next appends the next rabbit count and stops at 89. The page draws those numbers.

## Licences

AdaWebPack and the GNAT runtime are GPL-3.0. The three memory routines linked into `miu.wasm` come from that runtime. The Ada and the pages in this repository are original.
