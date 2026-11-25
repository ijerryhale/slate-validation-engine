# CLI Contract

The standalone validation tool is `slate`.

```sh
slate <analyze|readiness|report> [--package <path> | <package-path>] [--observed-state <path|->]
```

Provide a package, observed state, or both. Use `--package <path>`, its alias
`-p <path>`, or a positional path to supply one package JSON or Apple manifest
XML file. Use `--observed-state <path>` to read movie observations from a JSON
file or `--observed-state -` to read them from stdin.

## Inputs

| Supplied input | Public preview checks | Report `validationScope` |
| --- | --- | --- |
| Package only | Package type, vendor ID, primary locale name, rating system and value, theatrical release date, declared chapter timing, and missing chapter image paths or files. | `packageScalarMetadata` |
| Movie observations only | The supplied movie tracks and chapter timing. | `movieTracksAndChapterTiming` |
| Package and movie observations | Both sets of checks, plus comparisons of declared and observed chapter timing when chapter counts match and the observations supply chapter and image times with a positive movie time scale. | `packageScalarMetadataAndMovieTracksAndChapterTiming` |

Use the report title and `validationScope` to interpret a pass within the
preview checks above. Overall package readiness requires the full build. For an
example with both track and chapter observations, see `fixtures/observed/movie.json`.

Invoking a command without either input is a usage error (exit `64`). If no
package is supplied and the observed state contains neither movie track nor
chapter observations, the preview returns `preview.movie_observations_required`
as a blocker (exit `2`).

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
./Runtime/slate report --package fixtures/media_json/valid/source-basic.json
./Runtime/slate report --observed-state fixtures/observed/movie.json
./Runtime/slate analyze --observed-state fixtures/observed/movie-issues.json
./Runtime/slate readiness --observed-state fixtures/observed/movie-issues.json
```

Expected stdout lives in `fixtures/golden`.
