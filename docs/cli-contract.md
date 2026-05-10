# CLI Contract

The standalone validation tool is `slate`.

```sh
slate <analyze|readiness|report> [--package <path>] [package-path]
```

`--package <path>` and a positional `package-path` are equivalent. Provide
only one package path.

## Inputs

- package JSON files
- Apple manifest XML files, normally `metadata.xml`
- paths using `~`

Movie comparison is not part of the standalone public CLI contract. Package-only
findings remain valid without a loaded movie.

## Commands

`analyze`
: Writes a pretty-printed JSON array of canonical findings to stdout.

`readiness`
: Writes operator-readable readiness text to stdout.

`report`
: Writes the full canonical validation report dictionary to stdout as
  pretty-printed JSON.

## Streams

- Command payloads are written to stdout.
- Help requested with `-h` or `--help` is written to stdout.
- Errors and usage diagnostics are written to stderr.
- JSON payloads are not wrapped in progress text.

## Exit Status

| Code | Meaning |
| ---: | --- |
| 0 | Validation passed with no findings, or help was shown. |
| 1 | Validation completed with warnings. |
| 2 | Validation completed with blockers. |
| 64 | Command usage error. |
| 65 | Input could not be loaded or parsed. |
| 66 | Output could not be written. |
| 67 | Internal report contract validation failed. |
| 68 | Public preview usage cap exhausted or preview ledger invalid. |

## Examples

```sh
slate report --package fixtures/media_pkg/valid/source-basic.itmsp/metadata.xml
slate analyze fixtures/media_json/valid/source-basic.json
slate readiness -p fixtures/media_pkg/invalid/source-missing-path.itmsp/metadata.xml
```

Expected stdout lives in `fixtures/golden`.
