"""Regression coverage for the shipped widget slice, including editorial order."""

import json
import unittest
from collections import defaultdict
from tempfile import TemporaryDirectory
from pathlib import Path
from unittest.mock import patch

import generate_widget_events as generator
import validate_runtime_contracts as contracts


class WidgetSliceTests(unittest.TestCase):
    def test_every_day_preserves_its_lead_and_has_three_attributed_highlights(self):
        corpus = json.loads(generator.EVENTS_PATH.read_text())
        grouped = defaultdict(list)
        for event in corpus:
            if generator.is_decodable(event) and generator.normalized_status(event) not in generator.NON_PUBLISHABLE_STATUSES:
                grouped[(event["month"], event["day"])].append(event)
        output = json.loads(generator.build_slice())
        highlights = defaultdict(list)
        for event in output:
            highlights[(event["month"], event["day"])].append(event)
            self.assertTrue(event["one_liner"])
            self.assertNotEqual(event["source"], "Unattributed")
        self.assertEqual(len(highlights), 366)
        self.assertEqual(len({event["id"] for event in output}), len(output))
        for date, events in grouped.items():
            self.assertEqual(len(highlights[date]), 3, date)
            self.assertEqual(highlights[date][0]["id"], generator.pick_for_day(events)["id"], date)
            self.assertTrue(all(event["id"] in {e["id"] for e in events} for event in highlights[date]))

    def test_thin_dates_do_not_repeat_the_lead(self):
        corpus = json.loads(generator.EVENTS_PATH.read_text())
        for size in (1, 2):
            events = [event for event in corpus if event["month"] == 7 and event["day"] == 4][:size]
            highlights = generator.highlights_for_day(events)
            self.assertLessEqual(len(highlights), size)
            self.assertEqual(len({event["id"] for event in highlights}), len(highlights))

    def test_an_empty_embed_phase_is_rejected_even_with_a_widget_target(self):
        project = contracts.PROJECT_PATH.read_text()
        # Reproduce the shipping failure: target and file reference exist,
        # but the app's copy phase contains no extension.
        project = project.replace(
            "\t\t\t\t6D7E8F9A0B1C2D3E4F507182 /* TodayWidgetExtension.appex in Embed Foundation Extensions */,\n", ""
        )
        with TemporaryDirectory() as directory:
            path = Path(directory) / "project.pbxproj"
            path.write_text(project)
            with patch.object(contracts, "PROJECT_PATH", path):
                self.assertTrue(any("must embed" in error for error in contracts.validate_widget_bundle_contract()))


if __name__ == "__main__":
    unittest.main()
