#!/usr/bin/env python3
"""Validate the Today iOS bundled events collection.

This check mirrors the app's current data-loading contract without trying to
perform editorial/source review. It is intended to prevent a public commit from
shipping malformed fixture data, duplicate IDs, or records the app cannot decode.
"""

from __future__ import annotations

import calendar
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
EVENTS_PATH = ROOT / "sample-data" / "events.json"

ALLOWED_CATEGORIES = {
    "history",
    "science",
    "culture",
    "arts",
    "world",
    "politics",
    "nature",
    "technology",
    "exploration",
    "sports",
    "birth",
    "death",
    "strange",
}

ALLOWED_TONES = {
    "uplifting",
    "hopeful",
    "light",
    "balanced",
    "somber",
    "hard",
    "difficult",
    "heavy",
}

ALLOWED_STATUSES = {
    None,
    "ready",
    "app_ready_merged",
    "app_ready_merged_append",
    "duplicate",
    "weak_event",
    "defer",
}

NON_PUBLISHABLE_STATUSES = {"duplicate", "weak_event", "defer"}
SUMMARY_KEYS = ("one_liner", "description", "short_summary", "summary")


def is_non_empty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def source_count(record: dict[str, Any]) -> int:
    count = 0
    if is_non_empty_string(record.get("source")):
        count += 1
    sources = record.get("sources")
    if isinstance(sources, list):
        count += sum(1 for source in sources if is_non_empty_string(source))
    return count


def load_events() -> list[dict[str, Any]]:
    with EVENTS_PATH.open("r", encoding="utf-8") as handle:
        data = json.load(handle)

    if isinstance(data, list):
        events = data
    elif isinstance(data, dict) and isinstance(data.get("events"), list):
        events = data["events"]
    else:
        raise ValueError("events.json must be a top-level array or an object with an events array")

    if not events:
        raise ValueError("events.json contains no events")
    if not all(isinstance(event, dict) for event in events):
        raise ValueError("every events.json entry must be an object")
    return events


def validate(events: list[dict[str, Any]]) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    ids: list[str] = []

    for index, event in enumerate(events):
        label = f"record[{index}]"
        event_id = event.get("id")
        if not is_non_empty_string(event_id):
            errors.append(f"{label}: missing non-empty id")
        else:
            event_id_text = str(event_id).strip()
            ids.append(event_id_text)
            label = event_id_text

        month = event.get("month")
        day = event.get("day")
        if not isinstance(month, int) or not 1 <= month <= 12:
            errors.append(f"{label}: month must be an integer from 1 to 12")
        elif not isinstance(day, int):
            errors.append(f"{label}: day must be an integer")
        else:
            max_day = calendar.monthrange(2024 if month == 2 else 2025, month)[1]
            if not 1 <= day <= max_day:
                errors.append(f"{label}: invalid day {day} for month {month}")

        year = event.get("year")
        if year is not None and not isinstance(year, int):
            errors.append(f"{label}: year must be an integer when present")

        if not is_non_empty_string(event.get("title")):
            errors.append(f"{label}: missing non-empty title")
        if not any(is_non_empty_string(event.get(key)) for key in SUMMARY_KEYS):
            errors.append(f"{label}: missing summary text in one of {SUMMARY_KEYS}")

        category = event.get("category")
        if not is_non_empty_string(category):
            errors.append(f"{label}: missing category")
        elif str(category).strip().lower() not in ALLOWED_CATEGORIES:
            errors.append(f"{label}: unsupported category {category!r}")

        tone = event.get("tone")
        if tone is not None:
            if not is_non_empty_string(tone):
                errors.append(f"{label}: tone must be a non-empty string when present")
            elif str(tone).strip().lower() not in ALLOWED_TONES:
                errors.append(f"{label}: unsupported tone {tone!r}")

        status = event.get("editorial_status")
        if status not in ALLOWED_STATUSES:
            errors.append(f"{label}: unsupported editorial_status {status!r}")
        elif status in NON_PUBLISHABLE_STATUSES:
            warnings.append(f"{label}: bundled but app-filtered status {status!r}")

        if source_count(event) == 0:
            errors.append(f"{label}: missing source or sources")

        tags = event.get("tags")
        if tags is not None and not isinstance(tags, list):
            errors.append(f"{label}: tags must be an array when present")
        elif isinstance(tags, list) and not all(is_non_empty_string(tag) for tag in tags):
            errors.append(f"{label}: tags must contain only non-empty strings")

        sources = event.get("sources")
        if sources is not None and not isinstance(sources, list):
            errors.append(f"{label}: sources must be an array when present")
        elif isinstance(sources, list) and not all(is_non_empty_string(source) for source in sources):
            errors.append(f"{label}: sources must contain only non-empty strings")

    duplicate_ids = sorted(identifier for identifier, count in Counter(ids).items() if count > 1)
    for identifier in duplicate_ids:
        errors.append(f"duplicate id: {identifier}")

    publishable = [
        event for event in events
        if event.get("editorial_status") not in NON_PUBLISHABLE_STATUSES
    ]
    if not publishable:
        errors.append("events.json has no app-publishable records after status filtering")

    return errors, warnings


def main() -> int:
    try:
        events = load_events()
        errors, warnings = validate(events)
    except Exception as exc:  # noqa: BLE001 - this is a CLI gate, print concise failure.
        print(f"events validation failed: {exc}", file=sys.stderr)
        return 1

    statuses = Counter(event.get("editorial_status") for event in events)
    categories = Counter(event.get("category") for event in events)
    tones = Counter(event.get("tone") for event in events)
    publishable_count = sum(
        1 for event in events
        if event.get("editorial_status") not in NON_PUBLISHABLE_STATUSES
    )

    if warnings:
        print("warnings:")
        for warning in warnings[:20]:
            print(f"  - {warning}")
        if len(warnings) > 20:
            print(f"  - ... {len(warnings) - 20} more warnings")

    print(
        json.dumps(
            {
                "records": len(events),
                "publishable_records": publishable_count,
                "statuses": dict(statuses),
                "categories": dict(categories),
                "tones": dict(tones),
            },
            indent=2,
            sort_keys=True,
        )
    )

    if errors:
        print("errors:", file=sys.stderr)
        for error in errors[:50]:
            print(f"  - {error}", file=sys.stderr)
        if len(errors) > 50:
            print(f"  - ... {len(errors) - 50} more errors", file=sys.stderr)
        return 1

    print("events validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
