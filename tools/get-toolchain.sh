#!/bin/sh
# Downloads AdaWebPack 24 (GNAT-LLVM, wasm32) into ./toolchain.
# Same route as Robert's symmetry-visualizations and holographic-principle.
# Once, on Ubuntu: sudo apt install rpm2cpio cpio lld libedit2 curl unzip ca-certificates
set -eu
cd "$(dirname "$0")/.."
mkdir -p toolchain
cd toolchain

if [ ! -x usr/bin/llvm-gcc ]; then
  FEDORA=https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/40/Everything/x86_64/os/Packages
  for URL in \
    https://github.com/godunko/adawebpack/releases/download/24.0.0/adawebpack-24.0.0-git.fc40.x86_64.rpm \
    "$FEDORA/l/llvm16-libs-16.0.6-7.fc40.x86_64.rpm" \
    "$FEDORA/c/clang16-libs-16.0.6-5.fc40.x86_64.rpm"
  do
    echo "Downloading $URL"
    curl -fL --retry 3 --retry-delay 2 "$URL" | rpm2cpio | cpio -idm --quiet
  done
fi

mkdir -p lib
cp -a usr/lib64/llvm16/lib/libLLVM-16.so usr/lib64/llvm16/lib/libclang-cpp.so.16 lib/
if [ ! -e lib/libedit.so.0 ]; then
  if [ -e /usr/lib/x86_64-linux-gnu/libedit.so.2 ]; then
    ln -sf /usr/lib/x86_64-linux-gnu/libedit.so.2 lib/libedit.so.0
  elif [ -e /usr/lib/x86_64-linux-gnu/libedit.so.0 ]; then
    ln -sf /usr/lib/x86_64-linux-gnu/libedit.so.0 lib/libedit.so.0
  fi
fi

if [ ! -e lib/libgnat-14.so ]; then
  if ! command -v alr >/dev/null 2>&1; then
    if [ ! -x /tmp/alr-bin/bin/alr ]; then
      echo "Bootstrapping alr 2.1.1"
      curl -fL --retry 3 --retry-delay 2 \
        -o /tmp/alr.zip \
        https://github.com/alire-project/alire/releases/download/v2.1.1/alr-2.1.1-bin-x86_64-linux.zip
      rm -rf /tmp/alr-bin
      unzip -q -d /tmp/alr-bin /tmp/alr.zip
    fi
    ALR=$(find /tmp/alr-bin -type f -name alr -perm -111 | head -1)
  else
    ALR=$(command -v alr)
  fi
  echo "Fetching GNAT 14 runtime with $ALR"
  "$ALR" -n install --prefix="$PWD/gnat14" gnat_native=14.2.1
  cp "$(find gnat14 -name 'libgnat-14.so' | head -1)" lib/
fi

echo "Toolchain ready in $PWD"
