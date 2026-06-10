# Today iOS Source Scout Batch 001 - Run Report

Generated UTC: 2026-06-08T07:51:03Z
Repo: /Users/jamesmcshane/Desktop/today-ios
Input file: /Users/jamesmcshane/Desktop/today-ios/sample-data/events.json
Input SHA-256 before targeted confirmation: 01e47335dab450749dff3bf2c41a79979dde3724ff801f4eb088fa8c5bfcfd2b
Input SHA-256 after targeted confirmation: 01e47335dab450749dff3bf2c41a79979dde3724ff801f4eb088fa8c5bfcfd2b
No app data was modified. This is a read-only source-confirmation package.

## Commands and checks run

- Existing validator pass from initial scout: `python3 .github/scripts/validate_events.py` exit=0
- Existing runtime contract pass from initial scout: `python3 .github/scripts/validate_runtime_contracts.py` exit=0
- Targeted direct-source fetches for the top 10 risky/defer records using accessible institutional, museum, archive, and reputable press pages.
- App data SHA comparison: unchanged.

## Targeted confirmation results

- Records checked: 10
- Source-only draft repairs ready: 5
- Draft repairs ready only with copy review: 4
- Deferred because exact source support is still missing: 1

## Ready source replacements

1. Frances Oldham Kelsey: American Presidency Project and archived FDA Consumer.
2. Lizzie Borden: Smithsonian Magazine and Library of Congress.
3. Nemenčinė mass execution: Holocaust Atlas of Lithuania.
4. Pinochet arrest: Guardian and BBC.
5. Mar-a-Lago search: BBC and NBC.

## Copy-review repairs

1. Woodrow Wilson stroke: exact date supported; narrow mental-incapacity wording.
2. Venezuela drone attack: attribute drone details to officials and note dispute risk.
3. Night of the Pencils: remove rape wording unless a direct source is added.
4. Emmett Till trial: prefer murder or killing wording over torture-murder unless a direct source is added.

## Deferred

- Chortkiv deportation to Belzec remains unmutated. The exact on-this-day claim was found in Wiki-derived material only during this pass. It needs a direct historical source before repair.

## Artifact map

- SOURCE_CONFIRMATION_MANIFEST.json: source evidence and verdicts for all 10 targeted records.
- PROPOSED_REPAIRS_DRAFT.json: non-mutating repair draft for 9 records.
- RANKED_REPAIR_QUEUE.md: application order and risk tiers.
- DEFERRED_CANDIDATES.md: current deferred record and next source path.
- NO_WRITE_AND_STYLE_RECEIPT.json: no-write receipt and verification summary.
- SOURCE_LEADS_RAW.json: original generic scout raw leads retained for audit.

## Recommended next action

Do not mutate app data from this package without explicit approval. The strongest next move is a controlled source-repair mutation for the five source-only repairs first, then a copy-reviewed mutation for the four sensitive wording repairs, followed by validators and app/runtime checks.

## Verification results

Completed UTC: 2026-06-08T07:54:36Z

- `python3 .github/scripts/validate_events.py`: passed
- `python3 .github/scripts/validate_runtime_contracts.py`: passed
- JSON parse check for SOURCE_CONFIRMATION_MANIFEST.json, PROPOSED_REPAIRS_DRAFT.json, NO_WRITE_AND_STYLE_RECEIPT.json, and SOURCE_LEADS_RAW.json: passed
- Style gate for artifacts: passed, no em dash, emoji, or MEDIA tags found
- sample-data/events.json SHA-256 after verification: 01e47335dab450749dff3bf2c41a79979dde3724ff801f4eb088fa8c5bfcfd2b
- sample-data/events.json unchanged after verification: true
