# Tools

Tools to help a reader validate the public repo surface. The package verifier
also derives the public Slate.app source/header allowlist from
`slate-application/Slate.xcodeproj` Sources build phases, so public app source
files cannot drift beyond the project source graph.

Current tools:

- `verify_public_package.sh`
- `verify_runtime_manifest.sh`
