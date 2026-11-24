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
- compact public package, media, and subtitle fixtures
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
./Runtime/slate report --observed-state fixtures/observed/movie.json
./Runtime/slate analyze --observed-state fixtures/observed/movie-issues.json
./Runtime/slate readiness --observed-state fixtures/observed/movie-issues.json
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

## Public preview validation

The public preview checks package type, vendor ID, primary locale name, primary locale rating system and value, and theatrical release date. It also checks observed movie tracks and chapter timing plus declared chapter image paths that point to missing files. The package pane displays its scalar metadata, and the readiness rail reports findings from those limited scalar checks. Synopsis, poster, other locale metadata, cast/crew, platform, genre, asset, declaration-comparison, and overall package readiness checks require the full build.

## License Posture

Public visibility is not an open-source license. See `LICENSE.md`. Commercial
use, redistribution, reverse engineering, and incorporation into another
product require a separate written license from the copyright holder.
