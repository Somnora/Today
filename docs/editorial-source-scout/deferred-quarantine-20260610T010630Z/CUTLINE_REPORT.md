# Deferred quarantine cutline

## Scope

Removed all `editorial_status=defer` records from `sample-data/events.json` so the active app bundle contains only publishable rows. The deferred rows are retained in this artifact folder for future source repair.

## Counts

- Before: 1646 records, 1638 publishable, 8 app-filtered.
- After: 1638 records, 1638 publishable, 0 app-filtered.
- Before SHA: `f0b00ba8896f58f94b7ba7ceb7ea83b4fdea9897664f4c7f9f332b383b6c8acd`
- After SHA: `bd803167249432df6f0e9c15bafd635e595ef7c9a0241dcb233bfd5b68f42927`

## Quarantined records

- `june-15-1410-26bdc49bca8cfd59` - 06-15, 1410: Onon River Battle Date Needs Review
- `march-03-1924-7b4f5ceff0ad11d7` - 03-03, 1924: Fiume Annexation Date Needs Review
- `february-14-1947-0784c6b75731930e` - 02-14, 1947: Hungary Noble-Ranks Date Needs Review
- `january-06-1947-05a9592ef608f5cc` - 01-06, 1947: Pan Am Round-the-World Ticket Date Needs Review
- `july-11-1941-8941cd809075e011` - 07-11, 1941: Northern Rhodesian Labour Congress Needs Review
- `august-07-1985-9227d6db9e45a43c` - 08-07, 1985: Japan Astronaut Selection Exact-Date Claim Deferred
- `november-04-1924-3e91bc013fcff467` - 11-04, 1924: Nellie Tayloe Ross Election Exact-Date Claim Deferred
- `december-31-1983-905a79487fb500d2` - 12-31, 1983: Benjamin Ward Appointment Date Needs Review

## Verification

Passed.

- `python3 .github/scripts/validate_events.py`: passed, 1638 records, 1638 publishable.
- `python3 .github/scripts/validate_runtime_contracts.py`: passed, 1638 records, 1638 publishable.
- Today app simulator build: passed.
- TodayWidgetExtension simulator build: passed.
- Source/app/widget bundled `events.json` SHA: `bd803167249432df6f0e9c15bafd635e595ef7c9a0241dcb233bfd5b68f42927`.
- App bundle match: true.
- Widget bundle match: true.
- App-filtered records remaining in active bundle: 0.
- DerivedData receipt: `/tmp/today-ios-deferred-quarantine-20260610T010704Z`.

## Additional cutline checks

- Active `editorial_status=defer` records: 0.
- Active app-filtered records: 0.
- Affected date publishable counts were unchanged after quarantine: 01-06=3, 02-14=4, 03-03=4, 06-15=4, 07-11=4, 08-07=4, 11-04=4, 12-31=3.
- Quarantined-record em dash count: 0.
- Quarantined-record emoji count: 0.
- `git diff --check`: passed.
- Private QA scanner: not run, not present in this checkout per repo docs/private-workspace note.
