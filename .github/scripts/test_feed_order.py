"""Regression coverage for the editorial feed order."""

import json
import unittest

import generate_feed_order as feed
import generate_widget_events as widget


class FeedOrderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.grouped = feed.grouped_publishable()
        cls.days = json.loads(feed.build_order())["days"]

    def test_every_publishable_record_is_ranked_exactly_once_on_its_own_day(self):
        self.assertEqual(len(self.days), 366)
        for (month, day), events in self.grouped.items():
            ranked = self.days[f"{month:02d}-{day:02d}"]
            self.assertEqual(sorted(ranked), sorted(event["id"] for event in events))
            self.assertEqual(len(set(ranked)), len(ranked))

    def test_feed_lead_is_the_widget_lead(self):
        for (month, day), events in self.grouped.items():
            self.assertEqual(self.days[f"{month:02d}-{day:02d}"][0], widget.pick_for_day(events)["id"])

    def test_filler_never_outranks_a_real_story(self):
        for (month, day), events in self.grouped.items():
            by_id = {event["id"]: event for event in events}
            flags = [feed.is_filler(by_id[i]) for i in self.days[f"{month:02d}-{day:02d}"][1:]]
            self.assertEqual(flags, sorted(flags), (month, day))

    def test_famous_days_lead_with_the_expected_story(self):
        by_id = {event["id"]: event for events in self.grouped.values() for event in events}
        for key, needle in {"11-09": "Berlin Wall", "07-20": "Moon", "07-04": "Declaration of Independence"}.items():
            self.assertIn(needle, by_id[self.days[key][0]]["title"])

    def test_filler_detection_is_narrow(self):
        self.assertTrue(feed.is_filler({"title": "1905 Nobel Prize in Literature awarded", "one_liner": "x"}))
        self.assertFalse(feed.is_filler({"title": "Marie Curie wins the Nobel Prize in Chemistry", "one_liner": "x"}))


if __name__ == "__main__":
    unittest.main()
