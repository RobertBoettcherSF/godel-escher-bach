#!/bin/sh
# Compile the Ada packages to WebAssembly with AdaWebPack 24 (GNAT-LLVM wasm32).
# Run tools/get-toolchain.sh once first. The pages load the committed .wasm files.
set -eu
cd "$(dirname "$0")"
T=$PWD/toolchain/usr
if [ ! -x "$T/bin/llvm-gcc" ]; then
  echo "Run tools/get-toolchain.sh first" >&2
  exit 1
fi
export LD_LIBRARY_PATH="$PWD/toolchain/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
LD=$(command -v wasm-ld || true)
if [ -z "$LD" ]; then
  LD=$(ls /usr/bin/wasm-ld-* | tail -1)
fi

compile_module() {
  name=$1
  source=$2
  shift 2
  rm -rf "obj/wasm-$name"
  mkdir -p "obj/wasm-$name"
  (
    cd "obj/wasm-$name"
    "$T/bin/llvm-gcc" -c --target=wasm32 -O2 -gnat2012 -gnatp -gnatwa -gnatwe \
      --RTS="$T/lib/rts-native" -I../../src "../../$source"
    ar x "$T/lib/rts-native/adalib/libgnat.a" s-memcop.o s-memmov.o s-memset.o
    # shellcheck disable=SC2086
    "$LD" --no-entry --strip-all --export-memory \
      -z stack-size=1048576 --initial-memory=16777216 \
      -o "$name.wasm" ./*.o "$@"
  )
  cp "obj/wasm-$name/$name.wasm" "$name.wasm"
  echo "Built $name.wasm ($(wc -c < "$name.wasm") bytes)"
}

want=${1:-all}

if [ "$want" = "all" ] || [ "$want" = "miu" ]; then
  compile_module miu src/miu.adb \
    --export=miu_max_length --export=miu_max_history \
    --export=miu_chars --export=miu_meta --export=miu_ready \
    --export=miu_pos_count --export=miu_positions \
    --export=miu_hist_len --export=miu_hist_chars \
    --export=miu_reset --export=miu_apply --export=miu_undo --export=miu_resolve
fi

if [ "$want" = "all" ] || [ "$want" = "steps" ]; then
  compile_module steps src/steps.adb \
    --export=steps_max --export=steps_scale \
    --export=steps_meta --export=steps_widths \
    --export=steps_reset --export=steps_step --export=steps_undo
fi

if [ "$want" = "all" ] || [ "$want" = "figure" ]; then
  compile_module figure src/figure.adb \
    --export=figure_shapes --export=figure_meta \
    --export=figure_kind --export=figure_outline_xy \
    --export=figure_eye_xy --export=figure_eye_kind \
    --export=figure_reset --export=figure_uniform --export=figure_tap --export=figure_undo
fi

if [ "$want" = "all" ] || [ "$want" = "crab" ]; then
  compile_module crab src/crab.adb \
    --export=crab_meta --export=crab_letters --export=crab_notes --export=crab_mirrors \
    --export=crab_reset --export=crab_clear --export=crab_set_letter \
    --export=crab_cycle_letter --export=crab_cycle_note --export=crab_select_melody
fi

if [ "$want" = "all" ] || [ "$want" = "recursion" ]; then
  compile_module recursion src/recursion.adb \
    --export=recursion_meta --export=recursion_segments --export=recursion_dots \
    --export=recursion_digits \
    --export=recursion_reset --export=recursion_deeper --export=recursion_back \
    --export=recursion_tree --export=recursion_next --export=recursion_rabbits_reset
fi
