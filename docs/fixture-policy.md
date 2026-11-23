# Fixture Policy

The public fixture set stays compact and synthetic. One public movie fixture
is allowed as a complete movie/package/chapter-image triplet for app adapter
smoke tests and as the timing reference for the subtitle corpus.

It may include:

- tiny Apple manifest XML fixtures
- tiny package JSON fixtures
- generated chapter or poster images
- SRT, SCC, ITT, and TTML subtitle/caption sidecars with valid and invalid
  cases
- golden stdout files for CLI examples
- one public movie fixture for Slate.app UI smoke tests

`valid` means the fixture is parseable and intentionally shaped. It does not
mean the validation result exits `0`; several public fixtures intentionally
produce warnings or blockers because large media is omitted.

For `fixtures/media_sub`, valid timed sidecars include a cue through the
reference movie’s 105.005-second out. Its 3,147 video frames at 30000/1001 fps
give an exclusive non-drop timecode out of `00:01:44:27`. Invalid cases include
malformed files and cues outside the reference movie timeline. The fixture
manifest records the movie and timing contract.
