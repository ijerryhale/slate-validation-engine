# Slate Application

Public-facing Slate.app adapter package.

This package contains the Xcode project, public adapter source, paneharness
target, and sibling runtime artifacts needed to build and run the public
Slate.app surface.

`paneharness.app` loads adapter classes from the sibling `Slate.app`. The public
`paneharness` target depends on `Slate`, so building or running the harness from
Xcode also builds `Slate.app` into the same build directory.

## Build

From this directory:

```sh
./build_public_apps.sh
```

The script builds the public `Slate.app` adapter and `paneharness.app` in
Release configuration and writes both products to `build/Release`. It uses
`generic/platform=macOS` so it does not depend on Xcode's selected toolbar
destination.

`build/Release` is local build output and is not part of the public repository.
The runtime binaries live in `Runtime/`; the Xcode targets copy those binaries
next to `Slate.app` and `paneharness.app` during each local build.

## Xcode Destination

If Xcode shows `Please select an available device or choose a simulated device
as the destination` when you click Run, choose a concrete macOS destination:

`Product > Destination > My Mac`

or use the destination picker next to the scheme selector and choose `My Mac`.
This project builds macOS apps; it does not need an iOS simulator. Xcode stores
the selected run destination as local user interface state, so the public project
does not check that setting into source control.

## paneharness Run Configuration

`paneharness.app` loads adapter classes from a sibling `Slate.app`. In this
public package the useful build products live together under `build/Release`.
The shared harness target builds `Slate.app` first and lets the `Slate` target
copy the sibling runtime tools.

If paneharness opens an alert saying `Slate.app must be in the same directory as
paneharness.app` and the expected path contains `build/Debug/Slate.app`, Xcode is
running the harness with a Debug Run configuration. Change it with:

`Product > Scheme > Edit Scheme... > Run > Info > Build Configuration > Release`

The shared `paneharness` scheme is set this way, but Xcode may keep local scheme
state if the project was already open.
