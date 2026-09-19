# Slide deck generator

Generates [`docs/webplat-kubernetes-showcase.pptx`](../../docs/webplat-kubernetes-showcase.pptx)
from `build-deck.js` — a scripted `pptxgenjs` deck rather than a hand-edited
`.pptx`, so it's diffable and rebuildable when the underlying facts change
(a new incident, a new screenshot, updated stats).

## Regenerating

```bash
cd scripts/slide-deck
npm install pptxgenjs react-icons react react-dom sharp
node build-deck.js
```

Writes straight to `docs/webplat-kubernetes-showcase.pptx`. `node_modules`
is not committed — reinstall each time, or keep a local install around
between edits.

## Editing content

All content, layout, and the color palette ("Midnight Executive": navy
`1E2761` / ice blue `CADCFC` / accent teal `00D9C0`) live directly in
`build-deck.js` as plain JS — each slide is a clearly-commented block.
`icons.js` renders `react-icons` glyphs to PNG at build time (via
`react-dom/server` + `sharp`) since `pptxgenjs` has no native icon support.
