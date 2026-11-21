# Runtime

Intentionally public runtime deliverables.

Current contents:

- `manifest.json`, the public runtime artifact reference and policy record
- `slate`, the public command-line runtime

`manifest.json` describes version, platform, architecture, checksum, CLI
contract version, report schema version, and whether the binary is available.

Runtime deliverables expose the documented CLI and report contracts.
They do not expose private validation engine internals or validation engine
implementation source.

The public preview runs unlimited checks on observed movie tracks and chapter timing. Package metadata, declaration comparisons, and overall package readiness require the full build.
