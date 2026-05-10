# Slate Validation Engine

`slate-validation-engine` is the public-facing runtime and adapter package for
Slate. It is meant to stand alone as a small, inspectable command-line
distribution, AppKit adapter surface, fixture set, and contract package for
validating Apple movie package metadata.

This repository skeleton is intentionally narrow:

- documented public runtime and CLI behavior
- documented public Slate.app Apple Events
- public `Slate.app` adapter source that calls sibling runtimes
- public `paneharness` proof target
- machine-readable report contracts
- tiny public fixtures
- examples and golden outputs

It does not include private validation engine internals, package normalization
logic, track classification logic, chapter/timecode reasoning, review
intelligence, private media, or private Git history.

## Current Status

This directory is the reviewed public package prepared inside the private Slate
worktree. It carries only the public runtime surface: docs, schemas, fixtures,
examples, public adapter source, proof harness source, and intentional runtime deliverables.

## Quick Start

```sh
tools/verify_public_package.sh
tools/verify_runtime_manifest.sh
./Runtime/slate report --package fixtures/media_pkg/valid/source-basic.itmsp/metadata.xml
./Runtime/slate analyze fixtures/media_json/valid/source-basic.json
./Runtime/slate readiness -p fixtures/media_pkg/invalid/source-missing-path.itmsp/metadata.xml
fixtures/verify_golden.sh
cd slate-application && ./build_public_apps.sh
```

See `docs/apple-events.md` for the public `Slate.app` and `paneharness.app`
Apple Event surface.

The golden outputs normalize the absolute checkout path to `<repo>` so results
can be reviewed from any clone location.

The public application build writes local products to
`slate-application/build/Release`. That build directory is ignored and is not
part of the public package history. Runtime executables live in
`slate-application/Runtime`; the Xcode targets copy them beside `Slate.app` and
`paneharness.app` during local builds.

## Public Preview Usage Cap

The public preview `Runtime/slate` binary is limited to 60 validation runs:
20 `analyze`, 20 `report`, and 20 `readiness` calls. Help and usage failures do
not consume the preview ledger.

When the preview limit is reached, `analyze` and `report` return a parseable
`slate.validationUsageError.v1` JSON object and exit `68`. `readiness` returns a
plain operator message and exits `68`. A corrupt or tampered preview ledger also
fails closed with exit `68`.

## License Posture

Public visibility is not an open-source license. See `LICENSE.md`. Commercial
use, redistribution, reverse engineering, and incorporation into another
product require a separate written license from the copyright holder.
