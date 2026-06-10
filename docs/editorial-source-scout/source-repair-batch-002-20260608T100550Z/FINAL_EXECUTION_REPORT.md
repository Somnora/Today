# Today iOS Best Next Source Repair Pass 4

Completed UTC: 2026-06-08T10:14:30Z
Repo: /Users/jamesmcshane/Desktop/today-ios

## Scope

Executed a continuation of the best-next visible-feed source/posture queue after source-scout-batch-001 was already applied.

- Changed records: 6
- Source/posture repairs: 6
- Records intentionally not mutated in this pass: 3
- Publishable records: 1638
- Total records: 1646

## Changed records

1. april-04-1984-216fbcb2fb5052f9 - Reagan Proposes Worldwide Chemical Weapons Ban
   - Replaced legacy remote feed sources with Reagan Library and UPI.
   - Kept claim to announcement of a proposed comprehensive worldwide ban.
2. april-07-2018-457c29636958ac5b - Lula da Silva Taken into Custody in Brazil
   - Replaced legacy remote feed sources with AP, CNN, and BBC.
   - Narrowed wording to turn-over and custody language tied to Operation Car Wash.
3. april-10-1970-9fd084047a6bdec5 - Paul McCartney Makes the Beatles Split Public
   - Replaced legacy remote feed sources with HISTORY and The Guardian.
   - Narrowed wording to public split statement, not formal dissolution.
4. april-16-1943-e052a628ca341806 - Albert Hofmann Discovers LSD's Psychedelic Effects
   - Replaced legacy remote feed sources with Royal Society of Chemistry, Britannica, and SWI swissinfo.ch.
   - Repaired category from history to science and separated April 16 accidental exposure from April 19 deliberate test.
5. april-20-1968-30da991d9896e922 - Enoch Powell Gives the Rivers of Blood Speech
   - Replaced legacy remote feed sources with University of Warwick Modern Records Centre.
   - Repaired category from history to politics and tone from balanced to somber.
6. april-22-1864-773e5ddf2d87c1b1 - Congress Passes the 1864 Coinage Law
   - Replaced legacy remote feed sources with Library of Congress and GovInfo.
   - Narrowed unsupported all-coin motto wording to the two-cent coin pathway.

## Not mutated

- january-31-2007-25f29f1dce2198de: source-lead worker hit max-iteration; not repeated in parent loop this pass.
- april-04-1988-da02934ef4d082c8: source-lead worker hit max-iteration; not repeated in parent loop this pass.
- august-26-1942-80d95a14c483beb1: still deferred from source-scout-batch-001 because exact source support was missing.

## Verification

- validate_events.py: passed
- validate_runtime_contracts.py: passed
- git diff --check: passed
- Changed-record style and source-token gate: passed
- Generated-artifact style gate: passed
- Visible remote encyclopedia/feed source count: 276 before, 270 after
- Today app build: passed
- TodayWidgetExtension build: passed
- Source, app bundle, and widget bundle events.json SHA-256 values match: true
- Independent diff review: PASS

## App data

- Mutated file: sample-data/events.json
- Backup: sample-data/events.json.bak-best-next-pass4-20260608T100550Z
- Pre-mutation SHA-256: 1a7f9e1ee0a5772b61016260683d37924611ffae76d6d1719e6ba5d745ea9a5c
- Post-mutation SHA-256: f0b00ba8896f58f94b7ba7ceb7ea83b4fdea9897664f4c7f9f332b383b6c8acd

## Bundle receipt

- Source events.json count: 1646
- Today.app events.json count: 1646
- TodayWidgetExtension.appex events.json count: 1646
- Bundle SHA-256: f0b00ba8896f58f94b7ba7ceb7ea83b4fdea9897664f4c7f9f332b383b6c8acd
- Derived data path: /tmp/today-ios-dd-20260608T100550Z

## Artifact map

- SOURCE_CONFIRMATION_MANIFEST.json
- MUTATION_RECEIPT.json
- QA_RECEIPT.json
- CHANGED_RECORDS.json
- DIFF_REVIEW_INPUT.json
- FINAL_EXECUTION_REPORT.md

## Notes

The private QA scanner was not present in this checkout. The run used the available validators, scoped style and source-token gates, app and widget builds, bundle SHA comparison, and independent diff review instead.
