# Examples

The machine-readable example manifest is `examples/examples.json`. The fixture
root also carries a copy at `fixtures/examples/examples.json` for fixture-set
verification. The commands are written against the public repo layout.

After the public runtime package lands:

```sh
./Runtime/slate report --package fixtures/media_pkg/valid/source-basic.itmsp/metadata.xml
./Runtime/slate analyze fixtures/media_json/valid/source-basic.json
./Runtime/slate readiness -p fixtures/media_pkg/invalid/source-missing-path.itmsp/metadata.xml
fixtures/verify_golden.sh
```

Expected stdout is committed under `fixtures/golden`.
