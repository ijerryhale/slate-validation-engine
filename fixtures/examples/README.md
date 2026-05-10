# Slate Validation Examples

These examples use the public fixture set and the standalone `slate` CLI.

Install the CLI runtime from this repository after the public runtime package
lands:

```sh
test -x Runtime/slate
```

Then run:

```sh
./Runtime/slate report --package fixtures/media_pkg/valid/source-basic.itmsp/metadata.xml
./Runtime/slate analyze fixtures/media_json/valid/source-basic.json
./Runtime/slate readiness -p fixtures/media_pkg/invalid/source-missing-path.itmsp/metadata.xml
```

Expected stdout lives under `golden`. JSON examples are intentionally
pretty-printed so they can be read directly. Golden files use `<repo>` in
places where live validation output contains the absolute checkout path.

Run `fixtures/verify_golden.sh` to compare the
current CLI against the committed golden outputs.
