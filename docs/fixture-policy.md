# Fixture Policy

The public fixture set is deliberately small and boring. One small public movie
fixture is allowed when it forms a complete movie/package/chapter-image triplet
for app adapter smoke tests.

It may include:

- tiny Apple manifest XML fixtures
- tiny package JSON fixtures
- generated chapter or poster images
- tiny SRT, SCC, ITT, and TTML subtitle/caption sidecars
- golden stdout files for CLI examples
- one public movie fixture for Slate.app UI smoke tests

`valid` means the fixture is parseable and intentionally shaped. It does not
mean the validation result exits `0`; several public fixtures intentionally
produce warnings or blockers because large media is omitted.
