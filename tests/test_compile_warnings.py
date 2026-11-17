# -*- coding: utf-8 -*-
"""Regression for two native MetaEditor warnings, stable across version bumps.

Static checks only. Real MetaEditor F7 compilation is still required.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class MetaEditorWarningsTests(unittest.TestCase):
    def test_mql5_market_version_is_three_digit_fraction_at_most(self):
        source = (ROOT / "BTC_EMA_Pullback_v2.mq5").read_text(encoding="utf-8-sig")
        ver = re.search(r'(?m)^#define\s+BOT_VERSION\s+"(\d+)\.(\d+)\.(\d+)"', source)
        self.assertIsNotNone(ver)
        major, minor, patch = (int(x) for x in ver.groups())
        self.assertLessEqual(minor, 99)
        self.assertLessEqual(patch, 9)

        prop = re.search(r'(?m)^#property\s+version\s+"([^"]+)"', source)
        self.assertIsNotNone(prop)
        self.assertRegex(prop.group(1), r'^\d{1,3}\.\d{1,3}$')
        self.assertEqual(prop.group(1), f"{major}.{minor:02d}{patch}")

    def test_grid_cooldown_explicit_datetime_conversion(self):
        source = (ROOT / "TrendBot/Grid.mqh").read_text(encoding="utf-8-sig")
        self.assertIn(
            "g_gridOffUntil = (datetime)(TimeCurrent() + (long)MathMax(1, P_GridBars / 2) * PeriodSeconds(P_TF));",
            source,
        )


if __name__ == "__main__":
    unittest.main()
