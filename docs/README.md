# Today, first-pass notes

## Build

```bash
xcodebuild -project Today.xcodeproj -scheme Today -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' CODE_SIGNING_ALLOWED=NO build
```

## What exists
- SwiftUI iPhone app shell
- Today feed with collectible editorial cards
- Detail screen with save/share and provenance
- Explore screen with date jump and category browse
- Preferences for Uplifting and Balanced
- Widget shell
- Fixture JSON loader
- Local thumbs up/down storage hook

## Data posture
- Current bundled source: `sample-data/events.json`, see [`sample-data/README.md`](../sample-data/README.md) for the public data contract, validation command, and backup policy.
- Xcode copies that file into the app bundle as `events.json`; `DataLoader` reads it with `Bundle.main.url(forResource: "events", withExtension: "json")`.
- Top-level shape is a JSON array of event records. The loader also supports the older wrapped form `{ "events": [...], "robBundles": [...] }`.
- `DataLoader` maps each record into `HistoricalEvent`. Views consume only `HistoricalEvent` and stay decoupled from corpus internals.
- Invalid records are skipped; if the file is missing or has no valid records, the app falls back to a single local placeholder event.
- Records with `editorial_status` of `duplicate`, `weak_event`, or `defer` are hidden.
- As of 2026-06-09, `sample-data/events.json` carries **1638 records**, all app-publishable with no bundled deferred records. Statuses: `ready` 1599, `app_ready_merged` 31, `app_ready_merged_append` 8. Tones: balanced 743, uplifting 629, somber 266. The 8 deferred rows were quarantined under `docs/editorial-source-scout/deferred-quarantine-20260610T010630Z/`.
- Older local exports are not copied into the app bundle and are ignored from public source control.
- Upstream source-access details live in the private editorial workspace, not in this public app repo.

## Rebuilding the app data package

The single repeatable command (validate the current `sample-data/events.json`, then re-bundle into the app) lives in [`sample-data/README.md`](../sample-data/README.md). For a quick visibility check:

```bash
jq '{
  count:  length,
  hidden: ([.[] | select(.editorial_status == "duplicate" or .editorial_status == "weak_event" or .editorial_status == "defer")] | length),
  ready:  ([.[] | select(.editorial_status == "ready")] | length)
}' sample-data/events.json
```

## Editorial handoff schema

Preferred file name: `events.json`.

Simple MVP shape:

```json
[
  {
    "id": "evt-0502-1952-comet",
    "month": 5,
    "day": 2,
    "year": 1952,
    "title": "The jet age begins for passenger travel",
    "description": "The de Havilland Comet entered scheduled service.",
    "detail": "Optional longer narrative paragraph.",
    "category": "technology",
    "tone": "balanced",
    "sources": ["Science Museum Group", "British Airways heritage collection"]
  }
]
```

Richer preferred shape:

```json
[
  {
    "id": "evt-0502-1933-loch-ness",
    "month": 5,
    "day": 2,
    "year": 1933,
    "title": "The modern Loch Ness monster story surfaces",
    "one_liner": "A newspaper report helped turn a local sighting into one of the twentieth century's most durable mysteries.",
    "description": "Short fallback card copy if one_liner is absent.",
    "short_summary": "Another accepted short-copy fallback.",
    "summary": "A longer paragraph that can support the detail screen.",
    "detail": "The main detail-screen narrative.",
    "deep_dive": "Optional deeper background for readers who keep scrolling.",
    "why_it_matters": "Optional concise editorial note about relevance or emotional resonance.",
    "category": "strange",
    "tags": ["folklore", "media", "mystery"],
    "tone": "uplifting",
    "sources": ["The Inverness Courier archive", "National Library of Scotland"],
    "provenance": "Optional note about synthesis, review state, or source confidence.",
    "editorial_status": "ready"
  }
]
```

Required fields:
- `id`: stable unique string
- `month`: integer `1...12`
- `day`: integer `1...31`
- `title`: non-empty string
- At least one card-copy field: `one_liner`, `description`, `short_summary`, or `summary`
- `category`: one of `history`, `science`, `culture`, `arts`, `world`, `politics`, `sports`, `birth`, `death`, `strange`, `nature`, `technology`, `exploration`

Optional fields:
- `year`: integer. If absent, the UI shows `Undated`.
- `detail`: main longer story for the detail screen.
- `deep_dive`: additional detail shown as a tasteful `Deeper Story` section.
- `why_it_matters`: short editorial note shown below the main detail.
- `tone`: `uplifting`, `balanced`, or `somber`. Unknown values default to `balanced`.
- `tags`: array of small topical labels.
- `sources`: array of source URLs or citations. A single string is also accepted.
- `source`: single legacy source string.
- `provenance`: short source/review note shown above source links.
- `editorial_status`: `ready`, `app_ready_merged`, `app_ready_merged_append`, `duplicate`, `weak_event`, or `defer`.
- `contextLine`: editorial aside. If absent, the app generates one from category and tone.

Copy selection rules:
- Card copy prefers `one_liner`, then `description`, then `short_summary`, then `summary`.
- Detail body prefers `detail`, then `summary`, then `description`.
- `deep_dive` and `why_it_matters` are shown only when present.
- `duplicate`, `weak_event`, and `defer` records are hidden.
- `ready`, `app_ready_merged`, `app_ready_merged_append`, and records with no status are shown.

Accepted category aliases:
- `art`, `art/culture`, and `arts and culture` map to `arts`
- `births` and `born` map to `birth`
- `deaths` and `died` map to `death`
- `sport` and `athletics` map to `sports`
- `interesting`, `oddity`, and `curiosity` map to `strange`

## Visual intent
- Warm, tactile, storied, calm, quietly adventurous
- Editorial card rhythm with blockquote-style context lines
- Serif typography for narrative, rounded for UI chrome
- Warm terracotta accent, soft off-white backgrounds, generous spacing
