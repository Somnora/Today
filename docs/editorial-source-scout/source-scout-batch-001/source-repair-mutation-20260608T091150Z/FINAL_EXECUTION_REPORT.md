# Today iOS Source Repair Mutation Report

Completed UTC: 2026-06-08T09:26:26Z
Repo: /Users/jamesmcshane/Desktop/today-ios

## Scope

Executed the best-next source-repair queue from source-scout-batch-001.

- Changed records: 9
- Source-only repairs: 5
- Copy-reviewed repairs with narrowed wording: 4
- Deferred records left unmutated: 1

## App data

- Mutated file: sample-data/events.json
- Backup: sample-data/events.json.bak-source-scout-batch-001-20260608T091150Z
- Backup SHA-256: 01e47335dab450749dff3bf2c41a79979dde3724ff801f4eb088fa8c5bfcfd2b
- Post-mutation SHA-256: 1a7f9e1ee0a5772b61016260683d37924611ffae76d6d1719e6ba5d745ea9a5c

## Verification

- validate_events.py: passed
- validate_runtime_contracts.py: passed
- git diff --check: passed
- Changed-record style gate: passed
- Changed-record legacy-source-token gate: passed
- Independent diff review: PASS
- Today app build: passed
- TodayWidgetExtension build: passed
- Source, app bundle, and widget bundle events.json SHA-256 values match: true

## Bundle receipt

- Source events.json count: 1646
- Today.app events.json count: 1646
- TodayWidgetExtension.appex events.json count: 1646
- Bundle SHA-256: 1a7f9e1ee0a5772b61016260683d37924611ffae76d6d1719e6ba5d745ea9a5c
- Derived data path: /tmp/today-ios-dd-20260608T091150Z

## Notes

- No private QA scanner was present in this checkout. The available data-gate validators, changed-record style checks, source-token checks, independent review, app build, widget build, and bundle SHA checks were used instead.
- august-26-1942-80d95a14c483beb1 remains deferred because exact source support is still missing.
