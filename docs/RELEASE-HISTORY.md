# Release history

## v0.3.2

The bill, the wing, and a full frame.

- The beak is a curved upper mandible and a smaller lower one, with a thin mouth line. It joins the head, with a darker orange edge and a little shading, so it reads on a dark bird and on a pale one. The eye sits just behind the bill.
- The wing is three pointed feathers.
- The birds and fish meet across the frame. The ground is the fish layer’s own ink, so the mat is not a separate tan field.
- Ada still owns the layer, the inks, the taps and undo. Two swaps restore every ink. `miu.wasm` and `steps.wasm` are unchanged.

## v0.3.1

Figure and ground, drawn as animals.

- The block grid is gone. Each bird is one smooth outline, with a wing, tail, beak and eye. Each fish shares that belly as its back, and has a forked tail, a dorsal fin, a pectoral fin and an eye.
- Finding a gap animal lights a soft glow that follows that animal’s outline.
- Ada still owns the layer, the inks, the taps and undo. Two swaps restore every ink. `miu.wasm` and `steps.wasm` are unchanged.

## v0.3

Figure and ground.

- Original birds and fish share one picture. The pale gaps are animals too.
- A tap swaps which layer is ink. The shapes that just became the picture wiggle.
- A slider fades between the two views. “Tap a hidden one” is a find-the-gap game.
- The tile layout and the inks are Ada in `figure.wasm`.
- Undo, reset, and the same saved sound switch. F9 shows which animals are in front and the tap count.
- The gallery tile is open. The MIU puzzle and the endless steps are unchanged.

## v0.2

Endless steps.

- A runner and an original tortoise. Each step closes half the remaining gap, so the gap is 1/2ⁿ and never zero.
- The same steps are coloured blocks in one bar. Their sizes add up and stay below the whole bar.
- The fractions are Ada in `steps.wasm`. The page only draws and plays a rising tone.
- Auto, undo and reset. Sound still uses the saved preference. F9 shows the step count and the gap.
- The gallery tile is open. The MIU puzzle is unchanged.

## v0.1

First public page.

- Splash with a drawn triangular loop, gallery of eight chapters, MIU blocks playable.
- Rules, the I-count, history, undo and the tap-to-spot choice are Ada in `miu.wasm`.
- en-GB, de, es and fr. Sound and language are remembered. F9 debug overlay.
- Chapters 2–8 are marked soon and open a resting page.
- The native search checks every reachable string up to length 12.

The stamp on the pages is the line in `version.txt`.
