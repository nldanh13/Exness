# -*- coding: utf-8 -*-
"""v5.48: vung dem bo qua gio tin, FVG M15, Key Volume 2 lop, theo doi sau khoi dong (tinh)."""
import unittest

from test_safety import function, source


class V548(unittest.TestCase):
    def test_news_situations_do_not_overwrite_structural_hysteresis(self):
        smart = function("SmartSignals", "TrendBot/Signals.mqh")
        self.assertIn("if(g_smartSit != 1 && g_smartSit != 2) { g_smartPrev = g_smartSit;", smart)
        self.assertNotIn("   g_smartPrev = g_smartSit; g_smartPrevDir = tideOk ? t.trend : 0;\n", smart)

    def test_smart_fvg_threshold_override_is_restored(self):
        smart = function("SmartSignals", "TrendBot/Signals.mqh")
        self.assertIn("if(P_SmartFvgBigATR > 0) P_FvgBigATR = P_SmartFvgBigATR;", smart)
        self.assertIn("P_FvgBigATR = kFvgBig;", smart)
        self.assertLess(smart.index("P_FvgBigATR = P_SmartFvgBigATR"), smart.index("P_FvgBigATR = kFvgBig;"))

    def test_key_volume_has_local_layer(self):
        kv = function("KeyVolSignal", "TrendBot/Signals.mqh")
        self.assertEqual(kv.count("KeyVolLayer("), 2)
        self.assertIn("P_KVLocalBars", kv)
        layer = function("KeyVolLayer", "TrendBot/Signals.mqh")
        self.assertIn("KVReactions(bot, top, L, atr)", layer)

    def test_watch_and_paper_lines_written_without_fresh_analysis(self):
        ws = function("WriteStatus", "TrendBot/Status.mqh")
        self.assertNotIn("P_Strategy == STRAT_SMART && g_wTime > 0", ws)
        self.assertIn("WatchLoad();", ws)
        self.assertIn('"giay=" + gs', ws)


if __name__ == "__main__":
    unittest.main()
