# Validation Report Schema

The `report` command writes one JSON object to stdout.

## Report Object

| Key | Type | Notes |
| --- | --- | --- |
| `schemaVersion` | string | Current value is `"1"`. |
| `status` | string | `pass`, `warning`, or `blocker`. |
| `summary` | object | Counts for blockers, warnings, and total findings. |
| `nextFinding` | object or null | Highest-priority finding for operator focus. |
| `findings` | array | Canonical finding dictionaries. |
| `operatorText` | string | Human-readable readiness text. |
| `validationResultPayload` | object | Compact machine-readable payload. |

## Summary Object

| Key | Type |
| --- | --- |
| `blockers` | integer |
| `warnings` | integer |
| `total` | integer |

## Finding Object

| Key | Type | Notes |
| --- | --- | --- |
| `code` | string | Stable rule identity, such as `package.movie_comparison_unavailable`. |
| `severity` | string | `warning` or `blocker`. |
| `category` | string | `package`, `metadata`, `roles`, `tracks`, or `chapters`. |
| `scope` | string | Stable area within the package/session. |
| `title` | string | Short operator-facing title. |
| `evidence` | string | Specific reason or observed value. |
| `fallbackUsed` | boolean | True when fallback identity text was required. |
| `identitySource` | string | Source of the rule identity. |

The committed examples under `fixtures/golden/report` are the practical contract
fixtures. Schema files under `schemas` are intentionally conservative and allow
new keys so the public CLI can add fields without breaking readers that consume
the stable core.
