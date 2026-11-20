# Subtitle Sidecar Fixtures

This directory contains the public subtitle and closed-caption corpus. Files
are grouped first by expected classification (`valid` or `invalid`) and then
by format (`itt`, `scc`, `srt`, or `ttml`). Basenames describe the behavior or
case exercised, using lowercase kebab-case.

## Reference movie and timing

Valid timed sidecars target
`../media_mov/valid/source-chapters-crop.mov`, whose timeline duration is
`01:45:27` at 29.970 fps (`MM:SS:FF`). Each valid subtitle file has a final cue
ending at `00:01:45.900`; valid SCC files add a final caption event at
`00:01:44:00`, which remains visible through the end of the movie. The packet
decoder case retains its drop-frame separator as `00:01:44;00`.

Invalid fixtures cover malformed input, cues that begin after the reference
movie ends, and files that contain cues beyond its duration. Their content is
intentionally left outside the valid timeline contract.

`valid/srt/identity-a/` and `identity-b/` intentionally contain the same
basename. They exercise path-based identity for same-named sidecars.

`valid/ttml/README.md` describes the accompanying TTML layout inventory
payloads. The complete machine-readable inventory lives in
`../fixtures.json` under `subtitleCorpus`.
