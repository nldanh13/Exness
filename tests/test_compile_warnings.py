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

    def test_no_mql5_reserved_word_used_as_identifier(self):
        # MetaEditor rejects e.g. `string final = ...` (error 149/228): `final`,
        # `override` and friends are reserved in MQL5 even as variable names.
        reserved = ("final|override|template|typename|interface|operator|namespace|"
                    "delete|new|this|sizeof|virtual|explicit|offsetof|dynamic_cast|"
                    "input|sinput|export|import|default|class|struct|enum|union|public|"
                    "private|protected|static|extern|const|void|group")
        decl = re.compile(
            r"\b(?:int|double|string|bool|long|ulong|uint|datetime|color|float|char|short)"
            r"\s+&?(" + reserved + r")\s*[=;,)\[]")
        files = [ROOT / "BTC_EMA_Pullback_v2.mq5", *sorted((ROOT / "TrendBot").glob("*.mqh"))]
        for path in files:
            for no, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
                code = line.split("//", 1)[0]
                m = decl.search(code)
                self.assertIsNone(m, f"{path.name}:{no} dung tu khoa MQL5 '{m and m.group(1)}' lam ten bien")


if __name__ == "__main__":
    unittest.main()
