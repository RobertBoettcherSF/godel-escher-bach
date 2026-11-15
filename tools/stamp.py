#!/usr/bin/env python3
"""Write version.txt's stamp into every root HTML page."""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[1]
stamp = (root / "version.txt").read_text(encoding="utf-8").strip()
if not re.fullmatch(r"v0\.3\.1 b\d{8}-\d{4} [0-9a-f]{7}", stamp):
    sys.exit(f"bad stamp {stamp!r}")
changed = 0
for path in sorted(root.glob("*.html")):
    text = path.read_text(encoding="utf-8")
    new, count = re.subn(
        r'(<span class="version">)[^<]*(</span>)',
        rf"\1{stamp}\2",
        text,
        count=1,
    )
    if count != 1:
        sys.exit(f"{path.name}: expected 1 version span, found {count}")
    path.write_text(new, encoding="utf-8")
    changed += 1
print(f"{stamp} in {changed} pages")
