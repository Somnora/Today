# App Store Submission Pack

Date: 2026-05-03

This is a non-deploying release-candidate pass. No archive, upload, submission, deployment, or signing credential change was performed. `sample-data/events.json` was validated read-only and was not edited.

## V1 Blocker Cleanup Update

Cleanup completed on 2026-05-03:

- Deferred the widget from v1 by removing `TodayWidgetExtension` from the `Today` scheme build action and removing the widget app-extension file from the app embed phase.
- The widget target and files remain in the project for a later wiring pass, but the v1 `Today` app build no longer embeds `PlugIns/TodayWidgetExtension.appex`.
- Made timestamped backups before project-file changes:
  - `Today.xcodeproj/project.pbxproj.bak-v1-blocker-cleanup-20260503-124756`
  - `Today.xcodeproj/xcshareddata/xcschemes/Today.xcscheme.bak-v1-blocker-cleanup-20260503-124756`
- Polished Event Detail tags app-side. Examples now render as `United Kingdom`, `Elections`, and `Margaret Thatcher` instead of raw underscored corpus tags.
- Filtered obvious non-release/status-like tags from the Event Detail tag rail.
- Improved dark-mode `TextSecondary` and `TextTertiary` contrast while keeping the warm, soft visual tone.

## Bundle ID Update

Bundle ID update completed on 2026-05-03:

- Set the v1 app bundle ID to `app.somnora.today`.
- Set the deferred widget target bundle ID to `app.somnora.today.widget`.
- Kept the widget deferred from v1. The widget target still exists for later, but the v1 `Today` scheme builds only the app and the v1 app does not embed `PlugIns/TodayWidgetExtension.appex`.
- Made a timestamped project-file backup before editing:
  - `Today.xcodeproj/project.pbxproj.bak-bundle-id-change-20260503-221112`
  - `Today.xcodeproj/project.pbxproj.bak-bundle-id-somnora-20260503-223056`

## Final Validation Results

### Data Validation

Commands:

```sh
jq empty sample-data/events.json
jq -r '"total_records=\(length)" , "unique_ids=\([.[].id] | unique | length)" , "unique_dates=\([.[] | "\(.month)-\(.day)"] | unique | length)" , "missing_required=\([.[] | select((.id // "") == "" or (.title // "") == "" or (.month|type)!="number" or (.day|type)!="number")] | length)" , "invalid_month_day=\([.[] | select((.month < 1 or .month > 12 or .day < 1 or .day > 31))] | length)" , "ready_records=\([.[] | select((.editorial_status // "ready") == "ready")] | length)' sample-data/events.json
jq -r '[group_by(.month)[] | {month: .[0].month, records: length, days: ([.[].day] | unique | length)}] | ("month,records,days"), (.[] | [.month,.records,.days] | @csv)' sample-data/events.json
jq -r '[group_by(.editorial_status // "ready")[] | {status: (.[0].editorial_status // "ready"), count: length}] | ("status,count"), (.[] | [.status,.count] | @csv)' sample-data/events.json
```

Results:

- JSON is valid.
- Total records: `1508`
- Unique IDs: `1508`
- Unique month/day dates: `365`
- Earliest/latest calendar date: `1-1` through `12-31`
- Missing required fields: `0`
- Invalid month/day values: `0`
- Status counts: `ready = 1498`, `defer = 9`, `needs_source_check = 1`
- In-app publishable count by current `HistoricalEvent.isPublishable` logic: `1499` because `defer` records are filtered out and `needs_source_check` records are not.
- Month coverage:

| Month | Records | Days |
|---:|---:|---:|
| 1 | 130 | 31 |
| 2 | 119 | 28 |
| 3 | 133 | 31 |
| 4 | 123 | 30 |
| 5 | 131 | 31 |
| 6 | 124 | 30 |
| 7 | 123 | 31 |
| 8 | 133 | 31 |
| 9 | 124 | 30 |
| 10 | 117 | 31 |
| 11 | 124 | 30 |
| 12 | 127 | 31 |

### Project Settings

From `xcodebuild -project Today.xcodeproj -scheme Today -showBuildSettings` and built plist inspection:

| Target | Bundle ID | Version | Build | Min iOS | Device Family | Install |
|---|---|---:|---:|---:|---|---|
| Today | `app.somnora.today` | `0.1` | `1` | `17.0` | iPhone only, `[1]` | `SKIP_INSTALL = NO` |
| TodayWidgetExtension | `app.somnora.today.widget` | `0.1` | `1` | `17.0` | iPhone only, `[1]` | Target remains, deferred from v1 app scheme/embed |

Current v1 `Today` scheme build graph:

- `1 target`
- `Target 'Today' in project 'Today' (no dependencies)`
- Built simulator app contains `Today.app/PrivacyInfo.xcprivacy`
- Built simulator app does not contain `PlugIns/TodayWidgetExtension.appex`

App display name: `Today`

Widget display name: `Today Widget`

App icon:

- `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`
- `app/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` is `1024x1024`
- Asset catalog build did not report icon warnings in the final build pass.

### Privacy Manifests

Commands:

```sh
plutil -lint app/PrivacyInfo.xcprivacy widget/PrivacyInfo.xcprivacy widget/Info.plist
find ~/Library/Developer/Xcode/DerivedData/Today-cgpxagterpgvyuchlucdicvsxvnm/Build/Products/Debug-iphonesimulator/Today.app -maxdepth 3 -name PrivacyInfo.xcprivacy -print
```

Results:

- `app/PrivacyInfo.xcprivacy`: valid
- `widget/PrivacyInfo.xcprivacy`: valid
- `widget/Info.plist`: valid
- Built app includes `Today.app/PrivacyInfo.xcprivacy`
- Built v1 app does not include the widget extension after the cleanup pass.
- Manifest declares:
  - No tracking
  - No tracking domains
  - No collected data types
  - UserDefaults required-reason API: `NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1`

### Build

Command:

```sh
xcodebuild -project Today.xcodeproj -scheme Today -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' CODE_SIGNING_ALLOWED=NO build | tee /tmp/today-bundle-id-build.log
```

Result: `BUILD SUCCEEDED`

Warnings:

- `appintentsmetadataprocessor`: `Metadata extraction skipped. No AppIntents.framework dependency found.`
- Assessment: not a submission blocker by itself; the app does not define App Intents.

No archive/export/upload/signing command was run.

## Screenshot Inventory

Final handoff screenshots are saved under `docs/app-store-screenshots/v1-cleanup/`.

Available simulators at capture time:

- `iPhone 17 Pro`, iOS 26.2, available and used.
- `Somnora Review iPad Air 11 M3`, iOS 26.2, available but not used because the app is iPhone-only.

No alternate App Store Connect screenshot simulator sizes were available locally. Final v1 cleanup screenshots are `1206x2622`; use App Store Connect to confirm whether this size is accepted for the chosen iPhone display slot.

| File | Surface | Mode | Size |
|---|---|---|---|
| `v1-cleanup/01-today-feed-light.png` | Today feed | Light | `1206x2622` |
| `v1-cleanup/02-event-detail-light.png` | Event detail, polished tags | Light | `1206x2622` |
| `v1-cleanup/03-explore-light.png` | Explore | Light | `1206x2622` |
| `v1-cleanup/04-preferences-light.png` | Preferences | Light | `1206x2622` |
| `v1-cleanup/05-preferences-dark.png` | Preferences | Dark | `1206x2622` |
| `v1-cleanup/06-today-feed-dark.png` | Today feed | Dark | `1206x2622` |
| `v1-cleanup/07-event-detail-dark.png` | Event detail, polished tags | Dark | `1206x2622` |
| `v1-cleanup/08-explore-dark.png` | Explore | Dark | `1206x2622` |

Fallback/missing-data screenshot was not forced. Doing that cleanly would require mutating the installed app bundle or a separate diagnostic build. The practical empty state captured here is an Explore category filter with no matching results.

These screenshots are useful for QA, but App Store Connect may require a final screenshot set at Apple’s accepted device sizes for the target submission devices.

## Visual And Readiness QA

Passes:

- No visible handoff, data-source, or repair wording found in captured app surfaces.
- App privacy manifest is included in v1 build output.
- Widget target remains plutil-valid, but is no longer embedded in the v1 app.
- Icon-only bookmark/share actions expose accessibility labels in the detail toolbar.
- Main card buttons expose useful combined accessibility descriptions.
- Light mode is generally legible and polished.
- Dark mode loads and renders without inverted colors or broken assets.
- Detail tags now render as polished display text, not raw underscored corpus labels.
- Dark-mode secondary/tertiary text contrast is improved across Today, Detail, Explore, and Preferences.

Blockers / sharp edges:

- **Widget first-submission risk:** resolved for v1 by deferring the widget from the `Today` scheme and app embed phase. The widget target still exists and should be wired to real bundled events before re-enabling.
- **Raw tags are user-visible:** resolved for Event Detail.
- **Dark mode contrast:** improved. Still visually soft by design; final brand/design review should approve the tone before using screenshots publicly.
- **Current screenshots are QA captures, not guaranteed App Store final assets:** verify accepted resolutions in App Store Connect and export the required final sizes.
- **Editorial QA remains a human blocker:** one record is `needs_source_check`; nine are `defer` and filtered. The app build is fine, but content release requires owner approval.

## Suggested App Store Metadata

Name:

`Today in Time`

Subtitle:

`Daily Almanac`

Fallback name if unavailable:

`Daily Almanac`

Primary category:

`Reference`

Secondary category:

`Education`

Keywords:

`history,today,on this day,events,calendar,learning,culture,science,archive,daily`

## Draft App Store Description

Today is a quiet daily history app for iPhone.

Open it to see a small set of moments from this date: discoveries, political turns, cultural scenes, inventions, curiosities, and lives worth remembering. Each card is written for a slower read, with context that helps the event feel connected to the present.

Explore any date of the year, narrow the collection by category, and choose a reading tone that keeps the day lighter or gives you a broader view. Reactions and preferences stay on your device.

Today is built for a simple ritual: one date, a few well-kept stories, and a better reason to look twice at the calendar.

## Draft App Review Notes

Today is an iPhone-only SwiftUI app with a bundled local historical-event collection. It does not require login, account creation, network access, subscriptions, purchases, or user-generated content.

Preferences, saved card IDs, and thumbs up/down reactions are stored locally with UserDefaults/AppStorage. The app does not track users and does not send personal data to external services.

The widget target exists in the Xcode project but is deferred from the v1 app scheme and is not embedded in the current v1 app build. The submitted v1 app should be reviewed as an iPhone app without a widget extension.

## Privacy Nutrition Label Answers

Based on current code behavior:

- Data collected: none.
- Tracking: no.
- Data linked to the user: none.
- Data used to track the user: none.
- Contact info: not collected.
- Health and fitness: not collected.
- Financial info: not collected.
- Location: not collected.
- Sensitive info: not collected.
- Contacts: not collected.
- User content: not collected.
- Browsing history: not collected.
- Search history: not collected.
- Identifiers: not collected.
- Usage data: not collected externally.
- Diagnostics: not collected externally.
- Other data: not collected.

Local-only data:

- Tone preference.
- Thumbs up/down reactions by event ID.
- Saved event IDs.

These appear to stay on device via `@AppStorage` and are not transmitted by current app code.

## Export Compliance Recommendation

Recommended App Store Connect answer: the app does not use non-exempt custom encryption. It uses standard Apple platform capabilities only and has no network/auth/payment stack in the current code.

Human must confirm this during App Store Connect submission, especially if any networking, analytics, or third-party SDK is added later.

## Remaining Human-Only Decisions

- Confirm public bundle ID before App Store Connect creation: `app.somnora.today`.
- Keep `app.somnora.today.widget` reserved only if the widget is re-enabled in a future release.
- Confirm whether `0.1 (1)` is the intended release version/build.
- Confirm final signing team, provisioning, capabilities, and App Store Connect ownership.
- Widget is deferred from v1; decide when to wire/re-enable it after it can read real bundled app data.
- Approve final AppIcon art.
- Approve final App Store screenshots and required device sizes.
- Complete editorial/source QA for the bundled collection.
- Decide whether source/editorial notes should be visible in the release UI.
- Approve the updated dark-mode contrast and polished tag presentation before using screenshots for review.
