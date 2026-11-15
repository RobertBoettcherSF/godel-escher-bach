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
    --export=figure_shape_layer --export=figure_shape_kind --export=figure_shape_ink \
    --export=figure_outline_count --export=figure_outline_xy --export=figure_outline_stride \
    --export=figure_reset --export=figure_blend --export=figure_grow \
    --export=figure_tap --export=figure_undo
fi
