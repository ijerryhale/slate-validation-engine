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

The public preview checks package type, vendor ID, primary locale name, primary locale rating system and value, and theatrical release date. It also checks observed movie tracks and chapter timing plus declared chapter image paths that point to missing files. It does not perform package declaration comparisons or overall package readiness checks.
