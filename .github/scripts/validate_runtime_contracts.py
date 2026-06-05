#!/usr/bin/env python3
"""Validate Today runtime contracts that the app and widget rely on."""

from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EVENTS_PATH = ROOT / "sample-data" / "events.json"
PROJECT_PATH = ROOT / "Today.xcodeproj" / "project.pbxproj"
INFO_PLIST_PATH = ROOT / "app" / "Info.plist"
CONTENT_VIEW_PATH = ROOT / "app" / "ContentView.swift"
DATA_MODELS_PATH = ROOT / "app" / "Models" / "DataModels.swift"
EXPLORE_VIEW_PATH = ROOT / "app" / "Views" / "ExploreView.swift"
PREFERENCES_VIEW_PATH = ROOT / "app" / "Views" / "PreferencesView.swift"
THUMBS_STORE_PATH = ROOT / "app" / "Storage" / "ThumbsStore.swift"
WIDGET_PATH = ROOT / "widget" / "TodayWidget.swift"
FILTERED_STATUSES = {"duplicate", "weak_event", "defer"}


def load_events() -> list[dict]:
    try:
        data = json.loads(EVENTS_PATH.read_text())
    except Exception as exc:
        raise SystemExit(f"failed to read events.json: {exc}") from exc

    if not isinstance(data, list):
        raise SystemExit("events.json must be a top-level array")
    return data


def is_publishable(event: dict) -> bool:
    return normalized_status(event) not in FILTERED_STATUSES


def normalized_value(event: dict, key: str) -> str:
    return str(event.get(key) or "").strip().lower()


def normalized_status(event: dict) -> str:
    return normalized_value(event, "editorial_status").replace(" ", "_").replace("-", "_")


def normalized_category(event: dict) -> str:
    raw = (
        normalized_value(event, "category")
        .replace(" ", "")
        .replace("_", "")
        .replace("-", "")
        .replace("/", "")
    )
    aliases = {
        "art": "arts",
        "artculture": "arts",
        "artsandculture": "arts",
        "births": "birth",
        "born": "birth",
        "deaths": "death",
        "died": "death",
        "sport": "sports",
        "athletics": "sports",
        "interesting": "strange",
        "odd": "strange",
        "oddity": "strange",
        "oddities": "strange",
        "curiosity": "strange",
        "curiosities": "strange",
        "civilrights": "culture",
        "humanity": "culture",
    }
    return aliases.get(raw, raw)


def balanced(events: list[dict]) -> list[dict]:
    return [
        event
        for event in events
        if normalized_value(event, "tone") != "somber"
        or normalized_category(event) in {"history", "politics"}
    ]


def tone_filtered(events: list[dict], preference: str) -> list[dict]:
    if preference == "uplifting":
        uplifting = [event for event in events if normalized_value(event, "tone") == "uplifting"]
        return uplifting or balanced(events) or events
    if preference == "balanced":
        return balanced(events) or events
    if preference == "unflinching":
        somber = [event for event in events if normalized_value(event, "tone") == "somber"]
        non_uplifting = [event for event in events if normalized_value(event, "tone") != "uplifting"]
        return somber or non_uplifting or balanced(events) or events
    raise ValueError(preference)


def validate_data_contract(events: list[dict]) -> list[str]:
    errors: list[str] = []
    publishable = [event for event in events if is_publishable(event)]
    grouped: dict[tuple[int, int], list[dict]] = defaultdict(list)

    for event in publishable:
        grouped[(event.get("month"), event.get("day"))].append(event)

    if len(grouped) != 366:
        errors.append(f"publishable calendar coverage is {len(grouped)}, expected 366")

    for key, dated in sorted(grouped.items()):
        for preference in ("uplifting", "balanced", "unflinching"):
            if not tone_filtered(dated, preference):
                month, day = key
                errors.append(f"{preference} policy returned no events for {month:02d}-{day:02d}")

    return errors


def validate_app_code_contracts() -> list[str]:
    errors: list[str] = []
    content_view = CONTENT_VIEW_PATH.read_text()
    data_models = DATA_MODELS_PATH.read_text()
    explore_view = EXPLORE_VIEW_PATH.read_text()
    info_plist = INFO_PLIST_PATH.read_text()
    preferences_view = PREFERENCES_VIEW_PATH.read_text()
    project = PROJECT_PATH.read_text()
    thumbs_store = THUMBS_STORE_PATH.read_text()
    widget = WIDGET_PATH.read_text()

    if ".onOpenURL" not in content_view or "today://today" not in content_view:
        errors.append("ContentView must handle the today://today widget URL explicitly")
    if "INFOPLIST_FILE = app/Info.plist;" not in project:
        errors.append("Today target must use app/Info.plist so custom URL schemes are bundled")
    if "<string>today</string>" not in info_plist or "CFBundleURLTypes" not in info_plist:
        errors.append("app Info.plist must register the today URL scheme for widget and deep link routing")
    if "components.year = 2024" not in explore_view or "components.year = 2026" in explore_view:
        errors.append("Explore date picker and suggestion labels must use a leap year so Feb 29 records remain reachable")
    if "CFBundleShortVersionString" not in preferences_view or "v1.0" in preferences_view:
        errors.append("Preferences version label must be derived from the app bundle version")

    if "addingTimeInterval(86_400)" in widget:
        errors.append("widget timeline refresh must use Calendar date arithmetic instead of a fixed 86,400 second interval")

    if "boundedMonthName" not in data_models or "monthSymbols[max(0, month - 1)]" in data_models:
        errors.append("HistoricalEvent date labels must clamp invalid month values without indexing monthSymbols directly")

    if "@MainActor" not in thumbs_store:
        errors.append("ThumbsStore must stay on the main actor for AppStorage and ObservableObject updates")
    if "@Published private(set) var reactions" not in thumbs_store:
        errors.append("ThumbsStore reactions must be published with private write access")
    if "normalizedEventID" not in thumbs_store or "guard !trimmed.isEmpty" not in thumbs_store:
        errors.append("ThumbsStore must ignore blank event IDs before writing reactions")

    return errors


def validate_widget_bundle_contract() -> list[str]:
    errors: list[str] = []
    text = PROJECT_PATH.read_text()
    widget_target = _target_block(text, "TodayWidgetExtension")
    widget_sources_section = _phase_block(text, widget_target, "PBXSourcesBuildPhase")
    widget_resources_section = _phase_block(text, widget_target, "PBXResourcesBuildPhase")

    if not widget_target:
        errors.append("project must contain a TodayWidgetExtension target")
    if "DataLoader.swift in Sources" not in widget_sources_section:
        errors.append("widget target must compile DataLoader.swift so its timeline can load real events")
    if "events.json in Resources" not in widget_resources_section:
        errors.append("widget target must bundle events.json so WidgetKit is not limited to placeholder content")

    return errors


def _target_block(text: str, target_name: str) -> str:
    marker = f"/* {target_name} */ = {{"
    start = 0
    while True:
        start = text.find(marker, start)
        if start == -1:
            return ""
        line_start = text.rfind("\n", 0, start) + 1
        end = text.find("\n\t\t};", start)
        if end == -1:
            return ""
        block = text[line_start:end]
        if "isa = PBXNativeTarget;" in block and f"name = {target_name};" in block:
            return block
        start = end + 1


def _phase_block(text: str, target_block: str, expected_isa: str) -> str:
    for object_id in _target_build_phase_ids(target_block):
        block = _object_block(text, object_id)
        if f"isa = {expected_isa};" in block:
            return block
    return ""


def _target_build_phase_ids(target_block: str) -> list[str]:
    start = target_block.find("buildPhases = (")
    if start == -1:
        return []
    end = target_block.find(");", start)
    if end == -1:
        return []

    ids: list[str] = []
    for line in target_block[start:end].splitlines():
        token = line.strip().split(" ", 1)[0]
        if token:
            ids.append(token)
    return ids


def _object_block(text: str, object_id: str) -> str:
    marker = f"\t\t{object_id} /*"
    start = 0
    while True:
        start = text.find(marker, start)
        if start == -1:
            return ""
        line_end = text.find("\n", start)
        if line_end == -1:
            return ""
        if "= {" in text[start:line_end]:
            end = text.find("\n\t\t};", start)
            if end == -1:
                return ""
            return text[start:end]
        start = line_end + 1


def main() -> int:
    events = load_events()
    errors = []
    errors.extend(validate_data_contract(events))
    errors.extend(validate_widget_bundle_contract())
    errors.extend(validate_app_code_contracts())

    if errors:
        print("runtime contract validation failed:")
        for error in errors:
            print(f"  - {error}")
        return 1

    publishable = sum(1 for event in events if is_publishable(event))
    print(f"runtime contract validation passed: records={len(events)} publishable={publishable}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
