# TTML playback and region inventory fixtures

## Region inventory

The `regions-multizone` and `regions-sparse` documents cover multiple regions,
alternate namespace prefixes, optional layout attributes, explicit cue region
references, and cues without a paragraph-level region.

Each `.payload.json` file shows the relevant `displayItems` and
`ttmlLayoutInventory` fields expected in the imported synthetic sidecar
descriptor. The JSON files are compact inspection examples; they omit unrelated
track descriptor fields. Times are milliseconds.

`region-inheritance.ttml` covers region references inherited from `<body>`
and `<div>`, a `<p>` override, and unresolved inherited and paragraph
references. `regions-duplicate-inventory.payload.json` covers repeated IDs in
an already serialized layout inventory; runtime lookup selects the first one.

`style-cascade-nested-runs.ttml` preserves chained style declarations, a
region style reference, namespace-independent styling attributes, cell
resolution, and nested timed span boundaries for TTML presentation-payload
inspection. Its final cue reaches the public reference movie's end.

## Writing-mode playback checks

Open `source-chapters-crop.mov` and enable one writing-mode sidecar at a time.
Both files use the same four positions. The upper pair shows horizontal LTR
and RTL paragraphs. In the lower left, columns advance leftward. In the lower
right, they advance rightward. Times below are elapsed movie time.

| Sidecar | Pause at | What to check |
| --- | --- | --- |
| [writing-modes-playback.ttml](writing-modes-playback.ttml) | 5 s | The upper-left first line starts with `F` at the left edge. The upper-right first line is right-aligned, with the Hebrew group to the left of `F東京`. Below, read `F東京` down the first column, then `L大阪` down its neighbor. The two samples advance in opposite directions. |
| [writing-modes-playback.ttml](writing-modes-playback.ttml) | 15 s | The upper paragraphs align to their end edges and show `ABC` in visual order `CBA`. Below, read the three columns in their advance direction. The first has a sideways F and a horizontal 一 stroke. The second has an upright F and a horizontal stroke. The third has a sideways F and a vertical stroke. |
| [writing-modes-overflow.ttml](writing-modes-overflow.ttml) | 5 s | Each box shows `A東` and `B京` on separate rows or columns. The third group, `C山`, is fully clipped. |
| [writing-modes-overflow.ttml](writing-modes-overflow.ttml) | 15 s | The continuous text wraps after `四` and again after `八`. The first two groups are visible. `九十` falls beyond the box. |

At each checkpoint, keep playback paused, resize to minimum window width,
then enlarge it. Check the same glyph order, column advance and clipped
markers in both sizes. At 20 s all four regions clear. The final `END` cue
starts at 104 s and plays through the movie out. Its authored end is 105.005 s.

## Color and background playback checks

Open the [reference movie](../../../media_mov/valid/source-chapters-crop.mov) with one of these sidecars enabled. The times
are elapsed movie time. Pause and resize to check the painted edges.

| Sidecar | Pause at | What to check |
| --- | --- | --- |
| [colors-wrapped-spans.ttml](colors-wrapped-spans.ttml) | 5 s | Inside the navy padding, a translucent green paragraph band spans the content width. The red highlight follows the yellow H groups across the wrap. The blue patch marks four transparent letters inside that highlight. The white AA and half-opacity Z sit outside the highlight. |
| [colors-wrapped-spans.ttml](colors-wrapped-spans.ttml) | 15 s | In the right-hand region, the teal highlight covers 東京 in the first vertical column. F and the second column keep the paragraph background. At 20 s the picture clears. |
| [region-background-lifetime.ttml](region-background-lifetime.ttml) | 1 s | An empty teal rectangle appears on the left and a navy rectangle on the right. The center shows the movie. |
| [region-background-lifetime.ttml](region-background-lifetime.ttml) | 5 s, 7 s, 9 s | At 5 s, ONE and TWO share one translucent red region. At 7 s, TWO remains at the same background opacity. At 9 s the center clears and the right-hand silver paragraph disappears, revealing navy. |
| [region-background-lifetime.ttml](region-background-lifetime.ttml) | 13 s, 15 s | BACK restores the center rectangle. It clears at 15 s. The empty teal and navy regions remain. |
