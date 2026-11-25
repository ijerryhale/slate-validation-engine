# Subtitle Sidecar Fixtures

This directory contains the public subtitle and closed-caption corpus. Files
are grouped first by expected classification (`valid` or `invalid`) and then
by format (`itt`, `scc`, `srt`, or `ttml`, including `.dfxp`). Basenames use
lowercase kebab-case and describe the behavior or case exercised.

## Reference movie and timing

The [reference movie](../media_mov/valid/source-chapters-crop.mov) contains
3,147 video frames at exactly 30000/1001 fps (about 29.970 fps). Its non-drop
timecode starts at `00:00:00:00`. The last picture frame is `00:01:44:26`
and the exclusive out is `00:01:44:27`.

The video stream lasts 105.0049 seconds. The MOV duration is 105.005 seconds,
so the full-duration SRT, iTT, and TTML cases end their final cue at elapsed clock
time `00:01:45.005` (`00:01:45,005` in SRT). Valid SCC files start their final
caption event at `00:01:44:00` and hold it through the movie out. The packet
decoder case uses the drop-frame label `00:01:44;00`.

[subtitle-nested.dfxp](valid/ttml/subtitle-nested.dfxp) is a short regression
for nested timing offsets. On the reference movie, the first cue spans
3–7 s and includes the inline word `DFXP`. The second cue spans 9–13 s.

Invalid fixtures cover malformed input, cues that begin after the reference
movie ends, and files that contain cues beyond its duration. Their content is
intentionally left outside the valid timeline contract.

`valid/srt/identity-a/` and `identity-b/` intentionally contain the same
basename. They exercise path-based identity for same-named sidecars.

## TTML playback

Open the [reference movie](../media_mov/valid/source-chapters-crop.mov) and enable
one TTML sidecar at a time. The TTML guide includes
[writing-mode comparisons](valid/ttml/README.md#writing-mode-playback-checks)
and [color and background checks](valid/ttml/README.md#color-and-background-playback-checks)
for wrapped spans, alpha blending, and region visibility between cues.

The [fixture manifest](../fixtures.json) lists the sidecars and accompanying
layout payloads under `subtitleCorpus`.
