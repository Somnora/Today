# `sample-data/` — Today iOS bundled data

This directory is the **active app data surface** for Today iOS.
Xcode copies two files out of here on every build — the full corpus into the
app bundle, and a compact per-day slice into the widget extension. Nothing
else in the repo replaces them at build time.

## What gets shipped

| Output path | What it is |
| --- | --- |
| `sample-data/events.json` | Top-level JSON array of `HistoricalEvent` records (4389 records, all app-publishable, no bundled deferred records, as of 2026-07-07). |
| `<App>.app/events.json` | Same file, copied verbatim by Xcode's `Resources` build phase (app target). |
| `sample-data/widget-events.json` | Generated slice: one record per calendar day (366 records), trimmed to the fields the widget renders. Regenerate with `python3 .github/scripts/generate_widget_events.py` whenever `events.json` changes; CI fails if it is stale. |
| `<App>.app/PlugIns/…appex/widget-events.json` | Same slice, copied by the widget target's `Resources` build phase. |

`app/Data/DataLoader.swift` reads whichever resource its bundle carries:
the app resolves `events.json`; the widget extension resolves
`widget-events.json` (falling back to `events.json` if a full corpus is
ever bundled there again).

There is **no other resource path** that the running app or widget reads for
historical events. Other local JSON exports are reference material, not bundle
input, and are ignored from public source control.

## Where `events.json` actually came from

`events.json` is the cumulative artifact of a multi-step editorial pipeline
that lives outside this public app repo. The chain that built the current
4389-record file:

1. **Upstream promoted bundles** — one JSON file per calendar date in the
   private editorial workspace. Remote hostnames and operator paths are not
   stored in this public source repo; use the internal project notes for
   source-access details.

2. **Polish step (initial seed, ~80 records)** — private editorial tooling
   generated the first polished ready set and seeded `sample-data/events.json`.

3. **Current-window pack** — private editorial tooling appended current-window
   records into `sample-data/events.json`, taking timestamped local backups
   before mutation. That is the origin of the ignored `events.json.backup-*`
   files that may exist in a working copy.

4. **Batch top-ups and repairs** — one-shot private editorial scripts appended
   or repaired records in `sample-data/events.json` and wrote local backup
   snapshots. Batches you can see in `provenance` strings include
   `future_queue_rescue_batch_*`, `source_warning_reduction_batch_*`,
   `future_source_rescue_batch_*`, `undercovered-category-date-rescue-batch-*`,
   and later `app*` source-repair passes.

5. **On This Day landmark batch (2026-07-03)** — appended 1,778 curated
   landmark records (`id` prefix `otd-`, `provenance` batch
   `onthisday-landmark-2026-07`) from the Wikimedia "On This Day" feed, tone-
   classified with a positive lean and a hard violence veto, with one fame-
   ranked "Born Today" figure per day (Wikidata sitelink count). Each record
   also carries a `notability` field (topic sitelink count) the widget picker
   uses. This is the batch that added the July 4 1776 Declaration.

There is **no master orchestrator**. The 4389-record current state is
not reproducible by a single command — it is the sum of all those
batches in chronological order (most recently the July 2026 On This Day
landmark merge of 1,778 curated records, including 5 hand-authored marquee
landmarks such as the Wright brothers' first flight and MLK's "I Have a Dream").

## The one command to rebuild the app data package

Because the artifact above this line is itself the deterministic input,
"rebuild the app data package" means **validate the current
`sample-data/events.json` and re-bundle it into the app**:

```bash
cd path/to/today-ios

# 1. Smoke-test the JSON: parses, non-empty, unique IDs, valid app contract,
#    and at least one source per record. This mirrors the CI data gate.
python3 .github/scripts/validate_events.py

# 2. Regenerate the widget slice from the (possibly changed) corpus.
python3 .github/scripts/generate_widget_events.py

# 3. Re-bundle into the iOS app.
xcodebuild \
  -project Today.xcodeproj \
  -scheme Today \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

If the first command exits non-zero, do **not** ship `events.json`; the
bundle would carry a regression. Investigate before rebuilding.

## Optional: deeper QA before rebuild

```bash
# Read-only QA scanner lives in the private editorial workspace.
# Run it there against this repo's sample-data/events.json when doing release QA.
```

```bash
# Quick distribution snapshot.
jq -r '
  { records: length,
    statuses: (group_by(.editorial_status) | map({(.[0].editorial_status): length}) | add),
    categories: (group_by(.category) | map({(.[0].category): length}) | add),
    tones: (group_by(.tone) | map({(.[0].tone): length}) | add)
  }
' sample-data/events.json
```

## Optional: re-seed (NOT a substitute for the current artifact)

These private editorial commands reproduce the May 2 seed only — they will
**not** recover the 1500+ records added by later batch scripts. Use them for
forensics, recovery from a destroyed `events.json`, or to bootstrap a smaller
test bundle. Exact command paths live in the private editorial workspace, not
in this public app repo.

After either of these, the batch-script lineage would need to be replayed in
chronological order from the private reviewed-batch workspace to recover the
current state. There is no single command for that today — the most practical
recovery is to restore from the most recent ignored local backup snapshot.

## Recovery from backup

```bash
# List the most recent batch-aligned snapshots, newest first.
ls -t sample-data/events.backup-before-*.json | head -5

# Restore (review the chosen file first; this overwrites events.json).
cp sample-data/events.backup-before-future-queue-rescue-batch04-20260508T053720Z.json \
   sample-data/events.json
```

## Schema (decoded by `DataLoader`)

Required: `id`, `month`, `day`, `title`, `summary`, `category`, `tone`.
Common optional: `year`, `one_liner`, `short_summary`, `description`,
`detail`, `deep_dive`, `why_it_matters`, `tags`, `provenance`, `sources`,
`editorial_status`, `image_url`, `image_attribution`, `image_credit_url`.

`image_url` is a remote lead image (currently a Wikimedia Commons thumbnail);
the app loads it via `AsyncImage` and falls back to a tone-aware placeholder
when absent. `image_attribution` / `image_credit_url` back the credit caption
on the detail screen.

`DataLoader` filters out records where `editorial_status` is
`duplicate`, `weak_event`, or `defer`. The current bundle contains 4389
app-publishable records and no bundled deferred records. Deferred rows are
retained only as audit/rework artifacts under `docs/editorial-source-scout/`.
