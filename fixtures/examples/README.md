# Slate Validation Examples

These examples use the public fixture set and the standalone `slate` CLI.

Install the CLI runtime from this repository after the public runtime package
lands:

```sh
test -x Runtime/slate
```

Then run:

```sh
./Runtime/slate report --observed-state fixtures/observed/movie.json
./Runtime/slate analyze --observed-state fixtures/observed/movie-issues.json
./Runtime/slate readiness --observed-state fixtures/observed/movie-issues.json
```

Expected stdout lives under `golden`. JSON examples are intentionally
pretty-printed so they can be read directly. Golden files use `<repo>` in
places where live validation output contains the absolute checkout path.

Run `fixtures/verify_golden.sh` to compare the
current CLI against the committed golden outputs.
