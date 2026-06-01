# `sample-data/` — Today iOS bundled data

This directory is the **active app data surface** for Today iOS.
Xcode copies one file out of here into the iOS app bundle on every build;
nothing else in the repo replaces it at build time.

## What gets shipped

| Output path | What it is |
| --- | --- |
| `sample-data/events.json` | Top-level JSON array of `HistoricalEvent` records (1646 records, 1644 app-publishable after status filtering, as of 2026-06-01). |
| `<App>.app/events.json` | Same file, copied verbatim by Xcode's `Resources` build phase. |

The Xcode file reference is the lone `events.json` row inside the
`sample-data` group in `Today.xcodeproj` — see the `PBXBuildFile`
entry tagged `events.json in Resources`. `app/Data/DataLoader.swift`
reads it via `Bundle.main.url(forResource: "events", withExtension: "json")`.

There is **no other resource path** that the running app reads for
historical events. Other local JSON exports are reference material, not bundle
input, and are ignored from public source control.

## Where `events.json` actually came from

`events.json` is the cumulative artifact of a multi-step editorial pipeline
that lives outside this public app repo. The chain that built the current
1646-record file:

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

There is **no master orchestrator**. The 1646-record current state is
not reproducible by a single command — it is the sum of all those
batches in chronological order.

## The one command to rebuild the app data package

Because the artifact above this line is itself the deterministic input,
"rebuild the app data package" means **validate the current
`sample-data/events.json` and re-bundle it into the app**:

```bash
cd path/to/today-ios

# 1. Smoke-test the JSON: parses, non-empty, unique IDs, valid app contract,
#    and at least one source per record. This mirrors the CI data gate.
python3 .github/scripts/validate_events.py

# 2. Re-bundle into the iOS app.
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
`editorial_status`.

`DataLoader` filters out records where `editorial_status` is
`duplicate`, `weak_event`, or `defer`. The current bundle contains 1644
app-publishable records and 2 deferred records that remain bundled but are
filtered out at runtime.
