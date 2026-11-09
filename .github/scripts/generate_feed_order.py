#!/usr/bin/env python3
"""Generate sample-data/feed-order.json, the editorial order of each day's feed.

The app used to sort a day's events by year, so the first card was always the
oldest record rather than the best story. This script ranks every publishable
record for each calendar day once, at build time, and the app sorts by that
rank. The lead is the same pick the widget shows, so the feed, the widget and
the Morning Edition notification agree on the day's headline.

Order within a day:
  1. the widget lead (marquee override or best notable, positive landmark);
  2. the remaining records by `feed_score`, interleaved so the same category
     does not run back to back when an alternative of similar quality exists;
  3. formulaic filler (for example bare "Nobel Prize in X awarded" rows),
     oldest first, at the end.

The order is tone-neutral apart from the lead: the app applies the reader's
tone filter afterwards and keeps the relative order of what remains.

Usage:
    python3 .github/scripts/generate_feed_order.py          # (re)write file
    python3 .github/scripts/generate_feed_order.py --check  # verify freshness
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from typing import Any

import generate_widget_events as widget

ORDER_PATH = widget.ROOT / "sample-data" / "feed-order.json"

FILLER_TITLE = re.compile(r"^\d{4} Nobel (Memorial )?Prize in .+ awarded\.?$", re.IGNORECASE)
FILLER_SUMMARY = re.compile(r"^On \w+ \d{1,2}, \d{4}, .{0,60} records the ", re.IGNORECASE)

# How far below the best remaining candidate a different-category record may
# score and still be pulled forward for variety.
VARIETY_TOLERANCE = 3.0


def is_filler(event: dict[str, Any]) -> bool:
    title = str(event.get("title") or "").strip()
    return bool(FILLER_TITLE.match(title) or FILLER_SUMMARY.match(widget.summary_text(event)))


def has_image(event: dict[str, Any]) -> bool:
    value = event.get("image_url")
    return isinstance(value, str) and bool(value.strip())


def feed_score(event: dict[str, Any]) -> float:
    """Tone-neutral story quality: curated, illustrated, widely known."""
    score = 0.0
    if str(event.get("id") or "").startswith("otd-"):
        score += 3  # curated On This Day landmark
    if has_image(event):
        score += 2  # an illustrated card carries the top of the feed better
    score += min(widget.notability(event), 300) / 30  # 0...10, topic fame
    if widget.has_source_url(event):
        score += 1
    category = widget.normalized_category(event)
    if category in widget.DOMAIN_BONUS:
        score += 1
    if category == "birth":
        score -= 1  # a birthday is a fine card, rarely the day's second story
    if widget.normalized_tone(event) == "somber":
        score -= 2  # present for readers who want it, not stacked up top
    return score


def sort_key(event: dict[str, Any]) -> tuple[float, int, int, str]:
    return (
        -feed_score(event),
        -widget.prominence(event),
        event.get("year") if isinstance(event.get("year"), int) else 0,
        str(event.get("title") or ""),
    )


def interleave(events: list[dict[str, Any]], previous_category: str | None) -> list[dict[str, Any]]:
    remaining = sorted(events, key=sort_key)
    ordered: list[dict[str, Any]] = []
    last = previous_category
    while remaining:
        best = remaining[0]
        choice = best
        if widget.normalized_category(best) == last:
            floor = feed_score(best) - VARIETY_TOLERANCE
            for candidate in remaining[1:]:
                if feed_score(candidate) < floor:
                    break
                if widget.normalized_category(candidate) != last:
                    choice = candidate
                    break
        remaining.remove(choice)
        ordered.append(choice)
        last = widget.normalized_category(choice)
    return ordered


def order_for_day(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    lead = widget.pick_for_day(events)
    rest = [event for event in events if event["id"] != lead["id"]]
    stories = [event for event in rest if not is_filler(event)]
    filler = sorted(
        (event for event in rest if is_filler(event)),
        key=lambda e: (e.get("year") if isinstance(e.get("year"), int) else 0, str(e.get("title") or "")),
    )
    return [lead, *interleave(stories, widget.normalized_category(lead)), *filler]


def grouped_publishable() -> dict[tuple[int, int], list[dict[str, Any]]]:
    data = json.loads(widget.EVENTS_PATH.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise SystemExit("events.json must be a top-level array")
    grouped: dict[tuple[int, int], list[dict[str, Any]]] = defaultdict(list)
    for event in data:
        if not isinstance(event, dict):
            continue
        if widget.normalized_status(event) in widget.NON_PUBLISHABLE_STATUSES:
            continue
        if not widget.is_decodable(event):
            continue
        grouped[(event["month"], event["day"])].append(event)
    return grouped


def build_order() -> str:
    grouped = grouped_publishable()
    lines = []
    for month, day in sorted(grouped):
        ids = [str(event["id"]).strip() for event in order_for_day(grouped[(month, day)])]
        lines.append(f'    "{month:02d}-{day:02d}": {json.dumps(ids, ensure_ascii=False)}')
    return '{\n  "version": 1,\n  "days": {\n' + ",\n".join(lines) + "\n  }\n}\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify the committed order is fresh")
    args = parser.parse_args()

    fresh = build_order()
    count = sum(len(ids) for ids in json.loads(fresh)["days"].values())

    if args.check:
        if not ORDER_PATH.exists() or ORDER_PATH.read_text(encoding="utf-8") != fresh:
            print("feed order check failed: feed-order.json is missing or stale vs events.json")
            print("run: python3 .github/scripts/generate_feed_order.py")
            return 1
        print(f"feed order check passed: {count} ranked records are up to date")
        return 0

    ORDER_PATH.write_text(fresh, encoding="utf-8")
    print(f"wrote {ORDER_PATH.relative_to(widget.ROOT)}: {count} ranked records")
    return 0


if __name__ == "__main__":
    sys.exit(main())
