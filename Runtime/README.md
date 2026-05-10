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

The public preview `slate` binary is intentionally usage-capped: 60 validation
runs total, with 20 runs available for each validation endpoint (`analyze`,
`report`, and `readiness`). Exhausted or invalid preview ledgers fail closed
with exit `68`; `analyze`/`report` emit JSON and `readiness` emits a plain
operator message.
