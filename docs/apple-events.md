# Apple Events

The public Slate app automation surface uses Apple Event class `SLAT`.
`Slate.app` implements the full operator surface below. The public
`paneharness.app` proof target uses the same event class and the common event
IDs it needs for smoke and adapter checks.

These events are intended for local automation, smoke tests, and operator
inspection. They are not a replacement for the standalone `Runtime/slate` CLI
validation contract.

## Reply Envelope

Most successful replies return one JSON string in the direct object:

```json
{
  "schemaVersion": "operatorResult.v1",
  "ok": true,
  "eventClass": "SLAT",
  "eventID": "PING",
  "result": "pong"
}
```

Failures use the same envelope with `ok: false`, `result: null`, and an
`error` object:

```json
{
  "schemaVersion": "operatorResult.v1",
  "ok": false,
  "eventClass": "SLAT",
  "eventID": "FPTH",
  "result": null,
  "error": {
    "code": "pathNotFound",
    "message": "Path does not exist: /path/to/file.mov",
    "appleEventError": -43
  }
}
```

Command-style events place `runtimeCommandResult.v1` inside `result`.

## Common Events

These event IDs are shared by `Slate.app` and the public `paneharness.app`
target.

| Event | Direct object | Result |
| --- | --- | --- |
| `PING` | none | `"pong"` |
| `SWND` | `{x, y, width, height}` | Current window bounds as `[x, y, width, height]` |
| `SMOD` | `chapter`, `track`, `package`, `0`, `1`, or `2` | `runtimeCommandResult.v1` for the selected mode |
| `FPTH` | File path string | `runtimeCommandResult.v1` for the opened path |
| `TDET` | none | Track and movie inspector details for the loaded movie |
| `CDET` | none | Chapter and image inspector details for the loaded package |
| `SNAP` | `status` or `health` for `Slate.app`; optional for `paneharness.app` | Health/status snapshot |

## Slate.app Events

`Slate.app` also exposes the full operator surface below.

| Event | Direct object | Result |
| --- | --- | --- |
| `HELP` | none | Help text for the current public event surface |
| `GWND` | none | Current window bounds as `[x, y, width, height]` |
| `GMOD` | none | Current mode: `track`, `package`, or `chapter` |
| `GWWD` | none | Current workspace width |
| `GWCL` | none | Workspace width class code: `2` wide, `1` medium, `0` compact |
| `GSEC` | none | Current playback time in seconds |
| `SSEC` | Seconds number | `runtimeCommandResult.v1` for the requested playback time |
| `GRAT` | none | Current playback rate |
| `TPLY` | none | Playback rate after toggling play/pause |
| `RRPT` | none | Full readiness report for the loaded movie/package context |
| `RSUM` | none | Readiness summary for the loaded movie/package context |

## Examples

Set the Slate.app window bounds:

```sh
osascript -e 'tell application id "com.tmt.slate" to «event SLATSWND» {80, 80, 1280, 880}'
```

Load a movie or package path:

```sh
osascript -e 'tell application id "com.tmt.slate" to «event SLATFPTH» "/path/to/source.mov"'
```

Ask the app for its live event help:

```sh
osascript -e 'tell application id "com.tmt.slate" to «event SLATHELP»'
```
