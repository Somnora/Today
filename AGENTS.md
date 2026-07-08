# AGENTS.md

## Today iOS - 21-Day Proof Build

### Purpose
This is a first-pass iPhone-only SwiftUI proof app for "Today" — a historical moments app showing what happened on this day in history. This is a 21-day proof build focused on core functionality with fixture data, not a full production platform.

### Scope Constraints
**In Scope:**
- iPhone-only (no iPad, no macOS, no watchOS)
- SwiftUI native implementation
- Local fixture/sample data
- Basic widget shell
- Core screens: Today feed, Detail, Explore, Preferences
- Local storage for preferences and thumbs up/down
- Uplifting/Balanced tone filtering

**Out of Scope:**
- User accounts or authentication
- Social features or comments
- Backend infrastructure or API invention
- Android version
- Overbuilt animations
- Platform expansion
- Production data pipelines

### Architecture Summary

**Data Flow:**
```
sample-data/events.json → DataLoader → DataStore → Views (app target)
sample-data/widget-events.json → DataLoader → TodayWidget (widget target)
                                     ↓
                          UserPreferences (AppStorage)
                          ThumbsStore (AppStorage)
                          SavedStore (AppStorage)
```

`sample-data/events.json` is the only corpus bundled into the iOS app; the
widget extension bundles `sample-data/widget-events.json`, a generated
one-record-per-day slice (regenerate with
`python3 .github/scripts/generate_widget_events.py`; CI checks freshness).
For the active data contract, validation command, and backup policy, see
[`sample-data/README.md`](sample-data/README.md). Historical local exports
and upstream pipeline workspaces are intentionally kept outside public
source control.

**Key Components:**

1. **Data Models** (`app/Models/DataModels.swift`)
   - `HistoricalEvent`: Core event structure with date, title, description, category, tone
   - `EventCategory`: Categories like history, science, culture, arts, etc.
   - `EventTone`: Uplifting, balanced, or somber

2. **Data Layer** (`app/Data/`)
   - `DataLoader`: Loads events from bundled JSON
   - `DataStore`: Observable store with date indexing and filtering

3. **Storage** (`app/Storage/`)
   - `UserPreferences`: Tone preference (Uplifting vs Balanced)
   - `ThumbsStore`: Thumbs up/down reactions per event

4. **Views** (`app/Views/`)
   - `TodayFeedView`: Opens to today's date, shows filtered events
   - `EventDetailView`: Full event details with thumbs up/down
   - `ExploreView`: Date picker to jump to any date
   - `PreferencesView`: Tone preference toggle

5. **Widget** (`widget/`)
   - `TodayWidget`: Basic home screen widget showing one event
   - Timeline provider updates daily at midnight
   - Supports small and medium widget families

### Data Contract

**Current State:**
- Events loaded from `sample-data/events.json`
- Current bundled data is a top-level JSON array of historical event records.
- The app can also decode an object with an `events` array, but the active app data surface is the top-level array.
- Required record fields for the current bundle: `id`, `month`, `day`, `title`, `category`, at least one summary field (`one_liner`, `description`, `short_summary`, or `summary`), and at least one source (`source` or `sources`).
- Common optional fields: `year`, `detail`, `deep_dive`, `why_it_matters`, `tags`, `tone`, `provenance`, `editorial_status`.
- App-filtered statuses are `duplicate`, `weak_event`, and `defer`; publishable records are everything else accepted by `HistoricalEvent.isPublishable`.
- CI runs `.github/scripts/validate_events.py` to catch malformed JSON, duplicate IDs, invalid dates, unsupported categories/tones/statuses, and missing source attribution.

**Future Migration Path:**
- App code is decoupled from raw source data
- `DataLoader` provides a clean interface to swap the fixture for future publish bundles
- Views consume `HistoricalEvent` structs — they never touch raw JSON or corpus internals
- When a future bundle format arrives, only `DataLoader` needs to change

### Design Tone
- Warm, tactile, curious, storied, intimate, intelligent, calm
- Slightly mysterious, quietly adventurous
- Elegant editorial cards with rich typography
- Warm neutrals with subtle paper/archival/field-note influence
- Restrained ornament, clean spacing, strong readability
- Modern Apple-quality polish with historical soul

**Color Palette:**
- AccentWarm: Warm terracotta/rust accent (#B38561)
- BackgroundWarm: Soft off-white (#F8F5F2)
- CardBackground: Clean white cards
- Text hierarchy: Primary (near-black), Secondary (warm gray), Tertiary (lighter gray)

**Typography:**
- Georgia font family for editorial feel
- Clear hierarchy with varied weights
- Generous line spacing for readability

### What's Stable
✅ Current source layout with app/, widget/, docs/, and active sample-data/ surfaces
✅ Project structure with app/ and widget/ separation
✅ Core data models and JSON contract
✅ Main app data gate script and GitHub Actions workflow
✅ All four main screens functioning
✅ Date-based navigation and filtering
✅ Tone preference system (Uplifting/Balanced/Unflinching)
✅ Thumbs up/down local storage
✅ Widget shell with timeline provider
✅ Color system and typography
✅ 3826-record app-publishable bundled event corpus; deferred records are quarantined outside the app bundle
✅ Widget extension embedded in the app target and fed by a compact generated per-day slice (`sample-data/widget-events.json`)

### Data / Editorial Work Still Needed
- Continued source-truth review and source-quality hardening of the bundled corpus
- Final content tone calibration across uplifting, balanced, and somber records
- Update frequency and versioning strategy
- Image/media assets if desired (not yet in the data model)

### Build Notes

**Building the Project:**
1. Open `Today.xcodeproj` in Xcode 15+
2. Select iPhone simulator or device
3. Build and run the "Today" scheme
4. The widget extension will be built automatically

**Running Tests:**
- The `TodayTests` unit-test target (host: Today.app) covers `DataLoader`
  tone filtering, ambient `displayEvent` selection, `QuizEngine`
  determinism/structure, `QuizStore` streaks, `SavedStore` persistence, and
  share-card rendering.
- CLI: `xcodebuild -project Today.xcodeproj -scheme Today -destination 'platform=iOS Simulator,name=<sim>' test`
- Tests are part of the shared `Today` scheme, so they run in CI and from
  Xcode's Test action (⌘U).

**Known Build Considerations:**
- Requires iOS 17.0+ deployment target
- iPhone-only (not universal)
- Georgia font is a system font, should work on all iOS devices
- Widget requires device/simulator to install and test properly

**File Organization:**
```
today-ios/
├── app/
│   ├── TodayApp.swift           # App entry point
│   ├── ContentView.swift        # Tab navigation
│   ├── Models/                  # Data models
│   ├── Views/                   # Main screens
│   ├── Components/              # Reusable UI components
│   ├── Data/                    # Data loading and store
│   ├── Storage/                 # UserDefaults wrappers
│   └── Assets.xcassets/         # Colors and icons
├── widget/
│   ├── TodayWidget.swift        # Widget implementation
│   ├── Assets.xcassets/         # Widget assets
│   └── Info.plist               # Widget configuration
├── sample-data/
│   └── events.json              # Sample fixture data
├── tests/
│   └── TodayTests.swift         # Unit tests (TodayTests target)
├── docs/                        # Documentation directory
├── Today.xcodeproj/             # Xcode project
└── AGENTS.md                    # This file

```

### Next Steps for Production
1. Integrate future publish bundle system
2. Add real imagery and media loading
3. Expand event corpus to full dataset
4. Performance testing with large datasets
5. Widget data sharing via App Group
6. Polish animations and transitions
7. Accessibility audit (VoiceOver, Dynamic Type)
8. TestFlight beta testing

### Development Guidelines
- Keep fixture data easy to swap
- Don't couple to data source internals
- Maintain clean separation: app/ vs widget/
- Prefer clarity over clever engineering
- This is a proof build, not the final platform
- Focus on core experience, defer edge cases

---

**Last Updated:** 2026-04-19
**Build Type:** 21-day proof, iPhone-only
**Status:** Initial implementation complete, ready for sample data testing
