#!/bin/sh
# Stamp version.txt and every HTML page.
# The short commit is HEAD, so run this after the source commit and
# commit the stamp next. Times are Europe/Berlin.
set -eu
cd "$(dirname "$0")/.."
SHA=$(git rev-parse --short=7 HEAD)
WHEN=$(TZ=Europe/Berlin date +%Y%m%d-%H%M)
printf 'v0.5.1 b%s %s\n' "$WHEN" "$SHA" > version.txt
python3 tools/stamp.py
