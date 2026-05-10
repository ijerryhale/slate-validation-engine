# Runtime Package

This repository packages only reviewed public runtime and adapter surface.
The public app is a thin adapter over a set of sibling runtime binaries.

Include:

- public README, license, docs, schemas, fixtures, examples, and goldens
- public Slate.app adapter source that calls sibling runtimes or renders
  documented report JSON
- public paneharness proof source
- the small reviewed universal `Runtime/slate` command-line runtime
- the reviewed universal Slate.app sibling runtimes under
  `slate-application/Runtime`
- small runtime manifests and checksums
- helper tools that verify examples and runtime artifacts

The current package is intentionally self-contained:

- `Runtime/slate` is present, universal `x86_64` + `arm64`, checksummed in
  `Runtime/manifest.json`, and usable by the golden-output verifier without
  extra setup.
- `slate-application/Runtime` contains the sibling runtimes used by the public
  Slate.app adapter and paneharness target.
- `slate-application/public-application.json` records runtime checksums,
  expected build products, and the private source commit used to generate the
  package.