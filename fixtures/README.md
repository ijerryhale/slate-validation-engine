# Slate Validation Public Fixtures

This is the public fixture set for the `slate-validation-engine` repository.
It includes one movie/package/chapter-image triplet for Slate.app adapter
smoke tests and a cross-format subtitle/caption corpus tied to that movie.

The set proves:

- Apple manifest XML input
- package JSON input
- canonical report generation
- readiness/analyze/report CLI commands
- warning and blocker exit codes
- chapter-image path handling with tiny generated images
- text-role package parsing with tiny SRT, SCC, ITT, and TTML sidecars
- a public chapter/crop movie triplet for UI inspection smoke tests
- valid and invalid SRT, SCC, ITT, and TTML subtitle/caption cases
- valid subtitle timing through the full reference movie duration

Most package fixtures deliberately omit movie or sound media. The single
public movie is the timing reference for `media_sub`; see
`media_sub/README.md` for its frame-based duration contract.

`valid` means the fixture is parseable and intentionally shaped. It does not
mean the current validation result exits `0`.

The machine-readable package and subtitle fixture inventory is `fixtures.json`.

Examples and normalized golden outputs live under `examples` and `golden`.
Golden output files replace the absolute checkout path with `<repo>` so the
same files can be reviewed and verified from any clone location.
