# Slate Validation Public Fixtures

This is the intentionally small fixture set for the public
`slate-validation-engine` repo track. It includes one movie/package/chapter image triplet for public Slate.app adapter smoke tests.

The set proves:

- Apple manifest XML input
- package JSON input
- canonical report generation
- readiness/analyze/report CLI commands
- warning and blocker exit codes
- chapter-image path handling with tiny generated images
- text-role package parsing with tiny SRT, SCC, ITT, and TTML sidecars
- a public chapter/crop movie triplet for UI inspection smoke tests

Most fixtures deliberately omit movie or sound media. Some fixtures therefore
report missing-media findings; that is expected and keeps the public clone
lightweight.

`valid` means the fixture is parseable and intentionally shaped. It does not
mean the current validation result exits `0`.

The machine-readable fixture list is `fixtures.json`.

Examples and normalized golden outputs live under `examples` and `golden`.
Golden output files replace the absolute checkout path with `<repo>` so the
same files can be reviewed and verified from any clone location.
