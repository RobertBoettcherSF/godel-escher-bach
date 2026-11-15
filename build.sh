#!/bin/sh
# Compile src/*.adb to WebAssembly with AdaWebPack 24 (GNAT-LLVM wasm32).
# Run tools/get-toolchain.sh once first. The page loads miu.wasm as-is.
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
rm -rf obj/wasm
mkdir -p obj/wasm
(
  cd obj/wasm
  for FILE in ../../src/*.adb; do
    "$T/bin/llvm-gcc" -c --target=wasm32 -O2 -gnat2012 -gnatp -gnatwa -gnatwe \
      --RTS="$T/lib/rts-native" -I../../src "$FILE"
  done
  ar x "$T/lib/rts-native/adalib/libgnat.a" s-memcop.o s-memmov.o s-memset.o
  "$LD" --no-entry --strip-all --export-memory \
    --export=miu_max_length --export=miu_max_history \
    --export=miu_chars --export=miu_meta --export=miu_ready \
    --export=miu_pos_count --export=miu_positions \
    --export=miu_hist_len --export=miu_hist_chars \
    --export=miu_reset --export=miu_apply --export=miu_undo --export=miu_resolve \
    -z stack-size=1048576 --initial-memory=16777216 \
    -o miu.wasm ./*.o
)
cp obj/wasm/miu.wasm miu.wasm
echo "Built miu.wasm ($(wc -c < miu.wasm) bytes)"
