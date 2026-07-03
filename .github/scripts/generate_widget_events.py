#!/usr/bin/env python3
"""Generate sample-data/widget-events.json, the compact per-day widget slice.

The widget extension only ever renders one event per calendar day, so instead
of bundling (and decoding) the full events.json corpus inside the extension,
this script precomputes that one record per day using the same selection the
widget previously performed at runtime: publishable records for the date,
balanced-tone policy, then the earliest year (title as tiebreaker).

Records are trimmed to the fields the widget actually renders. Output is
deterministic; CI runs `--check` to fail if the committed slice is stale.

Usage:
    python3 .github/scripts/generate_widget_events.py          # (re)write slice
    python3 .github/scripts/generate_widget_events.py --check  # verify freshness
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
EVENTS_PATH = ROOT / "sample-data" / "events.json"
SLICE_PATH = ROOT / "sample-data" / "widget-events.json"

NON_PUBLISHABLE_STATUSES = {"duplicate", "weak_event", "defer"}
SUMMARY_KEYS = ("one_liner", "description", "short_summary", "summary")

CATEGORY_ALIASES = {
    "art": "arts",
    "artculture": "arts",
    "culturearts": "arts",
    "artsandculture": "arts",
    "artandculture": "arts",
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


def normalized_status(event: dict[str, Any]) -> str:
    raw = str(event.get("editorial_status") or "").strip().lower()
    return raw.replace(" ", "_").replace("-", "_")


def normalized_tone(event: dict[str, Any]) -> str:
    raw = str(event.get("tone") or "").strip().lower()
    if raw in {"uplifting", "hopeful", "light"}:
        return "uplifting"
    if raw in {"somber", "hard", "difficult", "heavy"}:
        return "somber"
    return "balanced"


def normalized_category(event: dict[str, Any]) -> str:
    raw = (
        str(event.get("category") or "")
        .strip()
        .lower()
        .replace(" ", "")
        .replace("_", "")
        .replace("-", "")
        .replace("/", "")
    )
    return CATEGORY_ALIASES.get(raw, raw)


def summary_text(event: dict[str, Any]) -> str:
    for key in SUMMARY_KEYS:
        value = event.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def first_source(event: dict[str, Any]) -> str:
    source = event.get("source")
    if isinstance(source, str) and source.strip():
        return source.strip()
    sources = event.get("sources")
    if isinstance(sources, list):
        for candidate in sources:
            if isinstance(candidate, str) and candidate.strip():
                return candidate.strip()
    return "Unattributed"


def is_decodable(event: dict[str, Any]) -> bool:
    month, day = event.get("month"), event.get("day")
    if not isinstance(month, int) or not isinstance(day, int):
        return False
    if not (1 <= month <= 12 and 1 <= day <= 31):
        return False
    title = event.get("title")
    if not isinstance(title, str) or not title.strip():
        return False
    return bool(summary_text(event))


def balanced_pool(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    kept = [
        event
        for event in events
        if normalized_tone(event) != "somber"
        or normalized_category(event) in {"history", "politics"}
    ]
    return kept or events


def pick_for_day(events: list[dict[str, Any]]) -> dict[str, Any]:
    pool = balanced_pool(events)
    return min(pool, key=lambda e: (e.get("year") or 0, str(e.get("title") or "")))


def slice_record(event: dict[str, Any]) -> dict[str, Any]:
    record = {
        "id": str(event["id"]).strip(),
        "month": event["month"],
        "day": event["day"],
        "title": str(event["title"]).strip(),
        "one_liner": summary_text(event),
        "category": str(event.get("category") or "history").strip(),
        "tone": normalized_tone(event),
        "source": first_source(event),
    }
    year = event.get("year")
    if isinstance(year, int):
        record["year"] = year
    return record


def build_slice() -> str:
    data = json.loads(EVENTS_PATH.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise SystemExit("events.json must be a top-level array")

    grouped: dict[tuple[int, int], list[dict[str, Any]]] = defaultdict(list)
    for event in data:
        if not isinstance(event, dict):
            continue
        if normalized_status(event) in NON_PUBLISHABLE_STATUSES:
            continue
        if not is_decodable(event):
            continue
        grouped[(event["month"], event["day"])].append(event)

    records = [slice_record(pick_for_day(grouped[key])) for key in sorted(grouped)]
    return json.dumps(records, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the committed slice matches a fresh regeneration",
    )
    args = parser.parse_args()

    fresh = build_slice()
    count = fresh.count('"id":')

    if args.check:
        if not SLICE_PATH.exists():
            print("widget slice check failed: sample-data/widget-events.json is missing")
            print("run: python3 .github/scripts/generate_widget_events.py")
            return 1
        if SLICE_PATH.read_text(encoding="utf-8") != fresh:
            print("widget slice check failed: widget-events.json is stale vs events.json")
            print("run: python3 .github/scripts/generate_widget_events.py")
            return 1
        print(f"widget slice check passed: {count} per-day records are up to date")
        return 0

    SLICE_PATH.write_text(fresh, encoding="utf-8")
    print(f"wrote {SLICE_PATH.relative_to(ROOT)}: {count} per-day records")
    return 0


if __name__ == "__main__":
    sys.exit(main())
