# Hero image width fix, 2026-11-09

Validation receipt for an approved data batch on `sample-data/events.json`.
James approved the P0 fix on 2026-11-09; the change was executed from the
`editorial/dupe-titles-widget-fix` branch on top of the build 7 snapshot.

## What broke

Wikimedia now serves only a fixed set of thumbnail widths and answers any
other width with HTTP 400 and the message "Use thumbnail sizes listed on
https://w.wiki/GHai". 1,461 of the 1,740 `image_url` values in the corpus
requested `640px-` thumbnails from `upload.wikimedia.org`, so every
illustrated card showed the tone placeholder and the widget's best-effort
image download failed silently.

Probed on 2026-11-09 with the app's user agent against one corpus image:

| Width | Result |
| --- | --- |
| 250px, 330px, 960px, 1280px | HTTP 200 |
| 480px, 640px, 800px, 1024px | HTTP 400 |

A random sample of 80 corpus `image_url` values returned 67 x 400 and
13 x 200. The successes were direct-original URLs, which do not request a
width. The remaining 279 image URLs in the corpus are such originals or
pre-rendered 330px TIFF thumbnails and were left unchanged.

## Change

- Rewrote `/640px-` to `/960px-` in the 1,461 affected `image_url` values.
  Line-scoped textual replacement; the git diff is 1,461 insertions and
  1,461 deletions, every one an `image_url` line. No other field changed.
- Regenerated `sample-data/widget-events.json`: 1,098 records, same order,
  849 image URL lines updated.
- `.github/scripts/validate_events.py` now rejects any Wikimedia thumbnail
  width outside 250, 330, 960 and 1280 and reports `image_urls` in its
  summary. Negative test: validating the pre-fix backup yields 1,461
  errors; the fixed corpus yields 0.
- `HistoricalEvent.imageURL` maps retired widths (480, 640, 800, 1024) to
  960 at read time, so older data or a future upstream change cannot blank
  the feed again. Two unit tests cover the mapping.
- `sample-data/README.md` documents the width rule.
- Build number bumped from 7 to 8 in all six configurations; marketing
  version stays 1.1.0.

## Backup

`sample-data/events.json.bak-image-width-fix-20261109T183800Z`
(10,302,255 bytes, gitignored under `sample-data/*.bak*`).

## Verification

```text
python3 .github/scripts/validate_events.py            -> events validation passed (3,826 records, 1,740 image_urls)
python3 .github/scripts/generate_widget_events.py --check -> widget slice check passed: 1098 per-day records
python3 -B .github/scripts/test_widget_slice.py       -> OK (3 tests)
python3 .github/scripts/validate_runtime_contracts.py -> runtime contract validation passed: records=3826 publishable=3826
git diff --check                                      -> clean
```

Throttled live check of 12 random rewritten URLs, 1.5 seconds apart:
12 x HTTP 200, payloads 92 KB to 334 KB.

Wikimedia rate-limits aggressive probing. Roughly 200 requests within a few
minutes from one address produced HTTP 429 for a period, so any future
image backfill must throttle to about one request per second.

The width mapping was executed through a `swiftc` harness compiled from the
real `DataModels.swift` and `DataLoader.swift` sources against both the fixed
corpus and the backup; results are recorded in the section below. Unit tests
were not run on a simulator in this pass at James's request; the app, widget
and test bundle were compiled with `xcodebuild build-for-testing` for a
generic iOS Simulator destination.

## Build evidence

- `xcodebuild build-for-testing` for `generic/platform=iOS Simulator`
  (Debug, signing disabled): TEST BUILD SUCCEEDED for the app, the widget
  extension and the test bundle. The built app reports CFBundleVersion 8
  and bundles an `events.json` byte-identical to the fixed corpus.
- `swiftc` harness over the real model sources: 7 mapping cases pass. Fixed
  corpus: 3,826 events, 1,740 image URLs resolved, 0 at 640px, 1,461 at
  960px. Pre-fix backup read through the fallback: 1,740 resolved, 0 at
  640px, 1,461 at 960px.

## Release

James approved executing the P0 items on 2026-11-09, which included cutting
build 8.

- Archived Release from commit `5e8e584` with automatic signing (team
  JGAJMMTQVS), exported with method `app-store-connect`.
- Archive checks: app and widget both 1.1.0 (8), minimum iOS 17.0, bundled
  `events.json` and `widget-events.json` byte-identical to the repository,
  no 640px references, dSYMs for app and extension present, no development
  host strings in either binary.
- Exported IPA signed Apple Distribution, `get-task-allow` false on app and
  extension, `codesign --verify --deep --strict` clean.
- IPA SHA-256:
  `577950aa0d41f1315afa454da98ab2ae490be84314f9517e74535ec482b08ff6`
  (3,278,133 bytes).
- Uploaded with `altool` at 13:44 Eastern on 2026-11-09; delivery UUID
  `d32e721f-a46e-4e3e-87fb-f3a69d7bb254`. Apple processing was pending at
  the time of writing.
- The 1.1.0 review submission from 2026-11-07 (build 7, WAITING_FOR_REVIEW)
  was not modified. Swapping build 8 into it is a separate decision for
  James.

Evidence: `/Volumes/Unreal/TodayWidgetRelease-2026-11-09/` (archive, export,
`archive.log`, `export.log`, `upload.log`, `archive-validation.txt`,
`Today.ipa.sha256`, `source-commit.txt`).
