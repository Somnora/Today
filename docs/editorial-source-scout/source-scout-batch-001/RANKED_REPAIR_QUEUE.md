# Today iOS Source Scout Batch 001 - Ranked Repair Queue

Generated UTC: 2026-06-08T07:51:03Z
Input SHA-256: 01e47335dab450749dff3bf2c41a79979dde3724ff801f4eb088fa8c5bfcfd2b
No app data was modified.

## Summary

- Targeted records checked: 10
- Source-only draft repairs ready: 5
- Draft repairs ready only with copy review: 4
- Deferred because exact source support is still missing: 1
- Mutation status: not allowed in this package

## Source-only repair queue

These are the safest first source replacements. They have accessible non-Wiki source support and only light copy changes.

1. august-07-1962-e78f730929733f00 - Frances Oldham Kelsey Awarded for Thalidomide Refusal
   - Replace Wiki sources with American Presidency Project and archived FDA Consumer source.
2. august-04-1892-fd89cb4fea529961 - Lizzie Borden's Parents Found Murdered
   - Replace Wiki sources with Smithsonian Magazine and Library of Congress guide.
3. september-20-1941-cc587e668a24d693 - The Holocaust in Lithuania: Mass Execution of Jews in Nemenčinė
   - Replace Wiki sources with Holocaust Atlas of Lithuania page and marker data. Keep attribution narrow.
4. october-16-1998-2016eb66331a26bb - Former Chilean dictator Augusto Pinochet arrested in London
   - Replace Wiki sources with Guardian and BBC reporting.
5. august-08-2022-37bd901849b7ea28 - FBI Searches Former President Trump's Residence
   - Replace Wiki sources with BBC and NBC reporting.

## Needs copy review before mutation

These have source support, but the current text should be narrowed before app data changes.

6. october-02-1919-0a3726e29078ed59 - Woodrow Wilson's Stroke at the White House
   - Exact date and stroke are supported. Current mental-incapacity wording is broader than the fetched source excerpts.
7. august-04-2018-1b084fcbccc384d0 - Venezuela Drone Attack During Maduro's Speech
   - Use attributed wording because sources say officials described the drones and also note disputed accounts.
8. september-16-1976-441b067e0c98a3e6 - Night of the Pencils
   - BBC supports abduction, imprisonment, torture, and deaths. Retain rape only with a more specific source.
9. september-23-1955-066299b2c0da7301 - Emmett Till Murder Trial
   - PBS and Britannica support the all-white jury and acquittal. Prefer murder wording over torture-murder unless a stronger source is added.

## Deferred

10. august-26-1942-80d95a14c483beb1 - Holocaust in Ukraine: Deportation of Jews to Belzec
    - The exact Chortkiv August 26, 1942 claim still lacks accessible non-Wiki source support in this pass. Do not mutate.

## Next approved mutation shape

If James approves a mutation pass, apply the nine draft repairs in PROPOSED_REPAIRS_DRAFT.json, then run the event validator, runtime contract validator, style gate, app build or targeted app tests, and a post-mutation SHA/diff review.
