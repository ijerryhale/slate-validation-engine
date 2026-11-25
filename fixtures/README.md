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
- app-oriented package probes for mixed asset roles, reconciliation, and
  normal-to-dense package layouts
- a public chapter/crop movie triplet for UI inspection smoke tests
- valid and invalid SRT, SCC, ITT, and TTML subtitle/caption cases
- valid subtitle timing through the full reference movie duration

Most package fixtures deliberately omit movie or sound media. The single
public movie is the timing reference for the [subtitle corpus](media_sub/README.md).

For TTML color and background checks, open the reference movie and enable one
sidecar at a time. Use [colors-wrapped-spans.ttml](media_sub/valid/ttml/colors-wrapped-spans.ttml)
to inspect highlights across a line break and [region-background-lifetime.ttml](media_sub/valid/ttml/region-background-lifetime.ttml)
to see which backgrounds remain after a cue ends. The [TTML playback guide](media_sub/valid/ttml/README.md#color-and-background-playback-checks)
gives pause times and expected results.

`valid` means the fixture is parseable and intentionally shaped. It does not
mean the current validation result exits `0`.

The machine-readable package and subtitle fixture inventory is `fixtures.json`.

## Application package fixtures

`fixtures.json` lists six additional packages under `applicationFixtures`:

- `asset-role-mixed.itmsp` combines video, audio, text, and image role cues.
- `reconcile-mixed-role.itmsp` exercises declared asset roles that conflict
  with the referenced media.
- `reconcile-text-coverage.itmsp` exercises declared subtitle coverage when
  the movie has no observed text counterpart.
- `ui-small.itmsp` provides a daily-size, two-locale package for UI inspection.
- `ui-large.itmsp` provides a dense, eight-locale package with larger chapter,
  cast, crew, platform, and poster sections.
- `chapter-readiness-errors.itmsp` uses the public reference movie to exercise
  chapter timing, missing-image, and localized-title findings in the full
  Debug app. The Release preview checks chapter timing and image paths as
  described in the [CLI contract](../docs/cli-contract.md#inputs).

These inputs are not CLI golden-output cases. Their supplied subtitle and
image dependencies are listed in `supportFiles`; private movie and sound
assets remain outside the public fixture set. Generated chapter and poster
probes live under `media_img/valid`.

Examples and normalized golden outputs live under `examples` and `golden`.
Golden output files replace the absolute checkout path with `<repo>` so the
same files can be reviewed and verified from any clone location.
