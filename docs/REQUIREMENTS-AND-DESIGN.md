# Requirements and design

Item 1 of the companion: a shell, an Ada-to-WebAssembly toolchain, and the MIU blocks. Later chapters stay locked.

## Requirements

- The four rules live in Ada and ship as WebAssembly. JavaScript loads `miu.wasm` and draws.
- `build.sh` rebuilds it. `docs/BUILD.md` says how. The wasm file is committed.
- Pages follow the Syllabus Repo shape: a splash, a gallery in book order, one page per chapter, one version line on every screen and in `version.txt`, Pages from `main` at the repository root.
- M, I and U are big coloured blocks. Each rule is a picture button and glows only when Ada says it can apply. If III or UU occurs in more than one place, the child taps a glowing block. Ada chooses which match that tap means. The blocks then move.
- The path under the blocks is the derivation Ada stored.
- Captions are short and exist in en-GB, de, es and fr. Flag buttons switch them.
- A counter shows how many I blocks there are. A secret button reveals that the count is never 3, 6, 9… and that MU has none.
- Undo, Reset, and sound on/off. Sound is remembered. Motion follows `prefers-reduced-motion`. Targets stay large on a phone and on a wide screen.
- The native test searches every string the rules can reach from MI up to length 12 and asserts that MU never appears and that the I-count is never divisible by 3. The compiler is warning-free. A Node smoke loads `miu.wasm`.
- F9 shows version, wasm status, current string, history length and last status.
- No chapter text, music, book quotations, book images, or a book PDF.

## Design

The system starts at MI. The rules are the usual four, with two limits that keep the picture honest:

- Doubling applies only when the tail after M is not empty, so a lone M does not pretend to change.
- A result longer than 64 blocks is refused, and that rule does not glow.

Adding U and deleting UU keep the I-count. Replacing III with U subtracts 3. Doubling the tail doubles the count. From one I, the count modulo 3 is therefore 1 or 2, never 0. MU has zero I blocks.

When a rule has one match, the button applies it. When it has several, the button only marks the blocks; `miu_resolve` maps the tap. Escape clears the marks.

The picture of a change is a prefix/suffix comparison of the string Ada returned and the string it had before. That comparison does not decide the next string.

History includes the starting MI. Undo stops there. After 64 steps the oldest step is forgotten.

The splash draws an original triangular ribbon in the three block colours. It is not a reproduction of a print. Locked chapters link to a short “still drawing” page so each item has a page, and the gallery shows them as closed.
