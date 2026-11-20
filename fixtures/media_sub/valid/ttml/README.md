# TTML region inventory fixtures

The `regions-multizone` and `regions-sparse` documents cover multiple regions,
alternate namespace prefixes, optional layout attributes, explicit cue region
references, and cues without a paragraph-level region.

Each `.payload.json` file shows the relevant `displayItems` and
`ttmlLayoutInventory` fields expected in the imported synthetic sidecar
descriptor. The JSON files are compact inspection examples; they omit unrelated
track descriptor fields. Times are milliseconds.

These fixtures cover metadata capture only. They do not assert positioned
subtitle rendering.

`region-inheritance.ttml` covers region references inherited from `<body>`
and `<div>`, a `<p>` override, and unresolved inherited and paragraph
references. `regions-duplicate-inventory.payload.json` covers repeated IDs in
an already serialized layout inventory; runtime lookup selects the first one.
