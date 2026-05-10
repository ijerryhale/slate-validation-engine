# paneharness

Standalone macOS harness app target that loads the production `Slate.app` adapter classes from a sibling app bundle and hosts the bottom-pane C/T/P controllers in a simple segmented-control test shell.

The public harness target depends on `Slate.app`, so building or running `paneharness` from the public Xcode project builds the sibling app first. When run outside that project, keep a built `Slate.app` in the same directory as `paneharness.app`; the harness alerts and exits if the sibling app is missing. Package/chapter fixture data comes from sibling Slate runtime executables instead of app-owned package-session classes. `SLATSNAP` reports both adapter and runtime health/status without requiring runtime binaries to be embedded.

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
  - `SLATSNAP` (operator envelope with `paneharnessStatus.v1` health/status result)

## Optional env overrides

- `SLATE_HARNESS_REPO_ROOT`

Sweep scripts also support:

- `PANE_HARNESS_APP`
- `HARNESS_FIXTURE_SMALL`
- `HARNESS_FIXTURE_BIG`
- `HARNESS_SYNC_FROM_BUILD`

## Sweep script

`_tools/harness_ae_sweep.sh`
