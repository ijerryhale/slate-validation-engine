# CLI Contract

The standalone validation tool is `slate`.

```sh
slate <analyze|readiness|report> --observed-state <path|-> [--package <path>]
```

`--package <path>` and a positional `package-path` are equivalent. Provide
only one package path. The preview ignores package declarations.

## Inputs

Supply observed movie state as JSON from a file or stdin (`-`). For a working
example with both tracks and chapters see `fixtures/observed/movie.json`.
The preview checks the supplied observations. Package-only input returns a
`preview.movie_observations_required` blocker. A pass applies to the observed
checks identified in the report title.

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

## Examples

```sh
./Runtime/slate report --observed-state fixtures/observed/movie.json
./Runtime/slate analyze --observed-state fixtures/observed/movie-issues.json
./Runtime/slate readiness --observed-state fixtures/observed/movie-issues.json
```

Expected stdout lives in `fixtures/golden`.
