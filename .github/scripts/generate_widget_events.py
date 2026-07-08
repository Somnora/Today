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
import re
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


TONE_WEIGHT = {"uplifting": 10, "balanced": 6, "somber": 0}
DOMAIN_BONUS = {"science", "technology", "exploration", "arts", "world", "history", "culture"}


def has_source_url(event: dict[str, Any]) -> bool:
    sources = event.get("sources")
    if isinstance(sources, list) and any(
        isinstance(s, str) and s.strip().lower().startswith("http") for s in sources
    ):
        return True
    source = event.get("source")
    return isinstance(source, str) and source.strip().lower().startswith("http")


def prominence(event: dict[str, Any]) -> int:
    # Longer linked-article text is a rough proxy for how well-known the topic is.
    for key in ("detail", "deep_dive", "description", "summary"):
        value = event.get(key)
        if isinstance(value, str) and value.strip():
            return len(value)
    return 0


def notability(event: dict[str, Any]) -> int:
    # Wikidata sitelink count of the event's linked topic (how many language
    # Wikipedias cover it) — a strong proxy for how iconic the event is.
    value = event.get("notability")
    return value if isinstance(value, int) else 0


def widget_score(event: dict[str, Any]) -> int:
    """Rank the day's candidates for the single widget slot: notable + positive."""
    score = TONE_WEIGHT[normalized_tone(event)]
    category = normalized_category(event)
    if str(event.get("id") or "").startswith("otd-"):
        score += 3  # curated On This Day landmark (notability-gated)
    if has_source_url(event):
        score += 1  # concrete, verifiable source
    if category in DOMAIN_BONUS:
        score += 1
    # famous "Born Today" figures make a fine headline, but shouldn't crowd out
    # historical events, so their fame only breaks near-ties (via notability).
    return score


# On a handful of famous days the algorithmic pick can favor a delightful
# secondary landmark over the event people expect. These overrides pin the
# canonical event (matched by year + keyword so they survive corpus rebuilds).
MARQUEE_OVERRIDES: dict[tuple[int, int], tuple[int, str]] = {
    (2, 12): (1809, r"lincoln"),
    (2, 20): (1962, r"glenn|friendship 7"),
    (3, 14): (1879, r"einstein"),
    (4, 12): (1961, r"gagarin"),
    (5, 20): (1927, r"lindbergh"),
    (5, 29): (1953, r"everest"),
    (6, 19): (1865, r"juneteenth|galveston|emancipation"),
    (7, 4): (1776, r"declaration of independence"),
    (7, 14): (1789, r"bastille"),
    (7, 20): (1969, r"moon|apollo"),
    (8, 15): (1947, r"independence|nehru"),
    (8, 28): (1963, r"i have a dream|luther king"),
    (9, 17): (1787, r"constitution"),
    (10, 12): (1492, r"columbus"),
    (11, 11): (1918, r"armistice"),
    (11, 19): (1863, r"gettysburg"),
    (12, 1): (1955, r"rosa parks"),
    (12, 17): (1903, r"wright"),
    (12, 25): (1642, r"newton"),
}


def marquee_pick(events: list[dict[str, Any]]) -> dict[str, Any] | None:
    if not events:
        return None
    key = (events[0].get("month"), events[0].get("day"))
    override = MARQUEE_OVERRIDES.get(key)
    if not override:
        return None
    year, pattern = override
    regex = re.compile(pattern, re.IGNORECASE)

    def text(event: dict[str, Any]) -> str:
        return f"{event.get('title', '')} {summary_text(event)}"

    exact = [e for e in events if e.get("year") == year and regex.search(text(e))]
    loose = exact or [e for e in events if regex.search(text(e))]
    if not loose:
        return None
    # among matches, prefer non-somber, then the most iconic (topic sitelinks)
    loose.sort(key=lambda e: (normalized_tone(e) != "somber", notability(e), prominence(e)), reverse=True)
    return loose[0]


def pick_for_day(events: list[dict[str, Any]]) -> dict[str, Any]:
    # Canonical event on marquee days; otherwise the best notable, positive landmark.
    forced = marquee_pick(events)
    if forced is not None:
        return forced
    pool = balanced_pool(events)
    return max(
        pool,
        key=lambda e: (widget_score(e), notability(e), prominence(e), str(e.get("title") or "")),
    )


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
    image_url = event.get("image_url")
    if isinstance(image_url, str) and image_url.strip():
        record["image_url"] = image_url.strip()
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
