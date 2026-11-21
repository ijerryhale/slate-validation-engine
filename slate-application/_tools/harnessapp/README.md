# paneharness

Standalone macOS harness app target that loads the production `Slate.app` adapter classes from a sibling app bundle and hosts the bottom-pane C/T/P controllers in a simple segmented-control test shell.

The harness target depends on `Slate.app`, so building or running `paneharness` from the Xcode project builds the sibling app first. At launch, the harness checks for `Slate.app` and all six Slate runtime executables beside `paneharness.app`; it alerts and exits if any are missing. It does not need to locate a repository checkout. Package/chapter fixture data comes from sibling Slate runtime executables instead of app-owned package-session classes. `SLATSNAP` reports adapter and runtime health/status.

## What it includes

- Production `ChapterViewController`, `TrackViewController`, and `PackageViewController` adapter classes loaded from `Slate.app`.
- Package and chapter fixture projection via sibling `SlatePackageRuntime` and `SlateChapterRuntime` executables.
- A fixed toolbar plus a single pane host view for mode switching and health probes.
- Fixture load buttons (`Load Daily`, `Load Big`, `Load Package…`) and an `Open Movie…` button for Track + Movie inspection.
- Starts blank by default (no fixture autoload); use fixture buttons or `SLATFPTH`.
- Apple Event hooks:
  - `SLATPING` (ping)
  - `SLATSMOD` (set mode)
  - `SLATSWND` (set window bounds)
  - `SLATFPTH` (load fixture path)
  - `SLATTDET` (Track + Movie inspector details for the loaded movie)
  - `SLATCDET` (Chapter + Image inspector details for the loaded package)
  - `SLATSNAP` (operator envelope with `paneharnessStatus.v1` health/status result). `SLATSNAP "probe"` also includes the active controller's `layoutProbe`.

## File pickers and fixtures

Load Daily opens `ui-small.itmsp` and Load Big opens `ui-large.itmsp`, both under `fixtures/media_pkg/valid`. The harness uses the fixtures beside the app bundles when present. In a checkout build, it uses the repository’s fixtures. The file pickers use the same fixture root.

Sweep scripts also support:

- `PANE_HARNESS_APP`
- `HARNESS_FIXTURE_SMALL`
- `HARNESS_FIXTURE_BIG`
- `HARNESS_SYNC_FROM_BUILD`

## Sweep script

`_tools/harness_ae_sweep.sh`
