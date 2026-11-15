# Building the MIU engine

The blocks follow rules written in Ada (`src/miu.ads`, `src/miu.adb`). `build.sh` compiles that package to `miu.wasm` with AdaWebPack 24, which is GNAT-LLVM targeting wasm32. JavaScript only loads the module and draws. The compiled `miu.wasm` is committed so GitHub Pages does not need a compiler.

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
gprbuild -P tests/smoke.gpr && ./obj/native/smoke
npm test
```

`make test` runs the native search, rebuilds `miu.wasm`, then the Node smokes. `build.sh` treats Ada warnings as errors (`-gnatwa -gnatwe`). The native project does too, and it enables assertions (`-gnata`).

`llvm-gcc` is invoked as:

```text
llvm-gcc -c --target=wasm32 -O2 -gnat2012 -gnatp -gnatwa -gnatwe \
  --RTS=toolchain/usr/lib/rts-native
```

`wasm-ld` links with `--no-entry --export-memory`, a 1 MiB stack and 16 MiB of memory. `memcpy`, `memmove` and `memset` come from the AdaWebPack runtime archive. There is no binder and no `adainit`; the page calls `miu_reset` before it reads memory.

## What the page calls

Integers are 32-bit. Character arrays are bytes. `miu_reset`, `miu_apply(rule, position)` and `miu_undo` update the arrays. Rules are 1 add U, 2 double the tail, 3 replace III, 4 delete UU. Whole-string rules take position 0. A spot is a 1-based index. `miu_resolve(rule, tap)` returns the match to use, or 0.

`miu_meta` is eight integers: length, I-count, history length, status, last rule, last position, previous length, unused. Status is 0 ok, 1 bad rule, 2 cannot, 3 bad spot, 4 too long, 5 no undo. History is capped at 64 steps; the oldest step is dropped after that. Strings are capped at 64 blocks. Doubling needs a non-empty tail, so a lone M does not glow.

## Licences

AdaWebPack and the GNAT runtime are GPL-3.0. The three memory routines linked into `miu.wasm` come from that runtime. The Ada and the pages in this repository are original.
