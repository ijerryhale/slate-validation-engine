# Examples

The machine-readable example manifest is `examples/examples.json`. The fixture
root also carries a copy at `fixtures/examples/examples.json` for fixture-set
verification. The commands are written against the public repo layout.

After the public runtime package lands:

```sh
./Runtime/slate report --observed-state fixtures/observed/movie.json
./Runtime/slate analyze --observed-state fixtures/observed/movie-issues.json
./Runtime/slate readiness --observed-state fixtures/observed/movie-issues.json
fixtures/verify_golden.sh
```

Expected stdout is committed under `fixtures/golden`.
